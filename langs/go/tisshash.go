// Package tisshash: implementacao Go do hash MD5 do epilogo TISS/ANS.
//
// Ver doc.go para a descricao geral do package e o algoritmo canonico.
package tisshash

import (
	"bytes"
	"crypto/md5"
	"encoding/hex"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"

	"golang.org/x/text/encoding/charmap"
)

// Namespace XML do Padrao TISS/ANS. Usado para localizar <ans:hash>
// independente do prefixo escolhido pelo emissor (o que importa eh o URI).
const Namespace = "http://www.ans.gov.br/padroes/tiss/schemas"

// Version desta implementacao.
const Version = "0.1.0"

// ErrInvalidTissXML eh o erro sentinel base de todas as rejeicoes de
// conformidade (XML mal-formado, encoding fora de escopo, multiplos
// <ans:hash>). Permite ao chamador testar `errors.Is(err, ErrInvalidTissXML)`
// sem depender do tipo concreto nem da causa raiz especifica.
var ErrInvalidTissXML = errors.New("tisshash: XML invalido")

// InvalidTissXMLError sinaliza que o XML eh mal-formado ou nao pode ser
// decodificado/parseado para calcular o hash. Preserva a causa raiz via
// Unwrap() para inspecao por errors.Is/As.
//
// Sempre satisfaz errors.Is(err, ErrInvalidTissXML).
type InvalidTissXMLError struct {
	Err error
}

// Error implementa error.
func (e *InvalidTissXMLError) Error() string {
	if e == nil || e.Err == nil {
		return ErrInvalidTissXML.Error()
	}
	return ErrInvalidTissXML.Error() + ": " + e.Err.Error()
}

// Unwrap permite errors.Is/As atravessar para a causa raiz do parser.
func (e *InvalidTissXMLError) Unwrap() error {
	if e == nil {
		return nil
	}
	return e.Err
}

// Is faz qualquer InvalidTissXMLError satisfazer errors.Is(err,
// ErrInvalidTissXML), independente de ter ou nao causa raiz envelopada.
func (e *InvalidTissXMLError) Is(target error) bool {
	return target == ErrInvalidTissXML
}

// HashTiss calcula o hash MD5 canonico do epilogo TISS/ANS a partir dos bytes
// do XML completo. Retorna 32 chars hex lowercase.
//
// Decisoes / alternativas avaliadas:
//
//   - Parser: encoding/xml da stdlib em modo streaming (Decoder.Token()).
//     Zero dependencia externa. Tokens emitidos cobrem todos os tipos de no
//     necessarios pra reproduzir a semantica da referencia Python: StartElement,
//     EndElement, CharData (texto + CDATA), Comment, ProcInst, Directive.
//     Alternativas descartadas:
//
//   - github.com/beevik/etree: DOM 3rd-party, ergonomico mas dep externa
//     desnecessaria pra este escopo.
//
//   - github.com/antchfx/xmlquery: focado em XPath, overkill.
//
//   - golang.org/x/net/html: parser HTML, nao XML.
//
//   - MD5: crypto/md5 da stdlib (zero dep).
//
//   - Encoding ISO-8859-1: a stdlib so aceita UTF-8 por default; instalamos
//     um Decoder.CharsetReader que delega pra charmap.ISO8859_1 do
//     golang.org/x/text. Esta eh a forma idiomatica em Go.
//
// Ver conformance/AMBIGUITY_NOTES.md no repositorio para o catalogo das 15
// decisoes canonicas (comentario entra, atributo nao entra, CDATA literal,
// prefixo de namespace irrelevante, bytes UTF-8 nao ISO-8859-1, etc.).
func HashTiss(xmlBytes []byte) (string, error) {
	// Rejeicao de escopo de encoding ANTES de qualquer tentativa de decodificar:
	// o escopo canonico do hash TISS eh ISO-8859-1 + UTF-8. Um BOM UTF-16/UTF-32
	// no inicio dos bytes denuncia um documento fora de escopo. Detectamos pelo
	// BOM (nao pela declaracao encoding=) porque o BOM eh autoridade de fato e a
	// deteccao manual de charset roda depois — entao falhamos cedo aqui.
	//
	// Ordem importa: UTF-32 LE (FF FE 00 00) compartilha o prefixo com UTF-16 LE
	// (FF FE), entao a checagem de 4 bytes precisa vir ANTES da de 2 bytes.
	if err := rejectUTFWideBOM(xmlBytes); err != nil {
		return "", err
	}

	// Strip BOM UTF-8 (TISS proibe, mas a referencia aceita).
	raw := stripBOM(xmlBytes)

	dec := xml.NewDecoder(bytes.NewReader(raw))
	dec.CharsetReader = charsetReader
	// Politica de seguranca: nao expandir entidades externas / DTDs externos.
	// encoding/xml ja eh restrito por design (nao busca DTDs remotos), mas
	// reforcamos desativando autoclose e mantendo entidades padrao apenas.
	dec.Strict = true

	// Estado de parse: pilha de elementos abertos. Cada elemState acumula
	// texto e marca se viu filho estruturado (Element/Comment/PI/Directive),
	// que eh o criterio pra desclassificar como "folha".
	//
	// Invariante: o topo da pilha eh sempre o elemento corrente em cujo
	// escopo os proximos tokens devem ser processados. Pop ocorre em
	// EndElement.
	type elemState struct {
		name           xml.Name
		isAnsHash      bool
		hasStructChild bool
		text           strings.Builder
	}

	var (
		stack     []*elemState
		concat    strings.Builder
		hashCount int // quantos <ans:hash> do namespace TISS ja vimos
	)

	// markParentStructured: quando ha um filho do tipo Element/Comment/PI/
	// Directive, o pai deixa de ser folha. Replica o filtro `len(el) == 0`
	// do lxml, onde len() conta children Element/Comment/PI.
	markParentStructured := func() {
		if n := len(stack); n > 0 {
			stack[n-1].hasStructChild = true
		}
	}

	for {
		tok, err := dec.Token()
		if err == io.EOF {
			break
		}
		if err != nil {
			return "", &InvalidTissXMLError{Err: err}
		}

		switch t := tok.(type) {
		case xml.StartElement:
			// Antes de empilhar o novo elemento, marca pai como estruturado.
			markParentStructured()
			// Casamos <ans:hash> por URI do namespace + local name, NUNCA pelo
			// prefixo literal (encoding/xml ja resolve xml.Name.Space para a URI).
			isHash := t.Name.Space == Namespace && t.Name.Local == "hash"
			if isHash {
				hashCount++
				// Conformidade TISS: o epilogo tem EXATAMENTE 1 <ans:hash>.
				// >1 eh documento mal-formado por contrato -> rejeitar (A-COV2).
				if hashCount > 1 {
					return "", &InvalidTissXMLError{
						Err: errors.New("multiplos <ans:hash> do namespace TISS (esperado no maximo 1)"),
					}
				}
			}
			es := &elemState{
				name:      t.Name,
				isAnsHash: isHash,
			}
			stack = append(stack, es)

		case xml.EndElement:
			n := len(stack)
			if n == 0 {
				// Robustez: nao deveria acontecer com XML bem-formado, mas
				// o parser ja teria errado antes de chegar aqui.
				return "", &InvalidTissXMLError{
					Err: fmt.Errorf("EndElement sem StartElement correspondente: %s", t.Name.Local),
				}
			}
			top := stack[n-1]
			stack = stack[:n-1]

			// Eh folha se nao teve nenhum filho estruturado.
			if !top.hasStructChild {
				if top.isAnsHash {
					// Zerar conteudo do <ans:hash>: contribui "" (no-op
					// efetivo, mas explicito pra leitura do algoritmo).
					concat.WriteString("")
				} else {
					concat.WriteString(top.text.String())
				}
			}

		case xml.CharData:
			// Texto e CDATA chegam ambos como CharData. Acumula no topo da
			// pilha SOMENTE; sera contribuido pro concat global apenas se o
			// elemento terminar sendo classificado como folha (caso contrario
			// eh whitespace de indentacao entre tags filhas, que NAO entra).
			if n := len(stack); n > 0 {
				stack[n-1].text.Write(t)
			}
			// Se estiver fora de qualquer elemento (entre prologo e root, ou
			// pos-root), ignoramos: eh whitespace estrutural.

		case xml.Comment:
			// Comentario eh "folha de comentario": contribui seu texto direto
			// ao concat global E marca o pai como estruturado (desclassifica
			// o pai como folha, replicando lxml onde Comment conta em len()).
			//
			// Esta eh a ambiguidade #2 fixada pela referencia: comentarios
			// XML ENTRAM no concat. Ver AMBIGUITY_NOTES.md.
			markParentStructured()
			concat.Write(t)

		case xml.ProcInst:
			// Processing instruction (ex.: <?php ... ?>). Marca o pai como
			// estruturado (desclassifica como folha). Nao contribuimos texto
			// (seguindo o port Rust, que trata so Element/Comment como
			// nos-folha que contribuem). Nenhum vetor de teste cobre PI no
			// corpo, entao este eh comportamento defensivo conservador.
			markParentStructured()

		case xml.Directive:
			// Diretiva DOCTYPE/etc. Marca pai como estruturado, nao
			// contribui. Tambem nao coberto por vetores.
			markParentStructured()
		}
	}

	// MD5 dos bytes UTF-8 da string concatenada.
	sum := md5.Sum([]byte(concat.String()))
	return hex.EncodeToString(sum[:]), nil
}

// HashTissFile eh atalho: le arquivo do disco e chama HashTiss.
//
// Retorna InvalidTissXMLError se o conteudo for invalido, ou erro de I/O
// (envelopado em fmt.Errorf com contexto do path) se a leitura falhar.
func HashTissFile(path string) (string, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("tisshash: ler %q: %w", path, err)
	}
	return HashTiss(raw)
}

// -- Internos -------------------------------------------------------------

// rejectUTFWideBOM rejeita documentos cujo inicio carrega um BOM UTF-16 ou
// UTF-32, que estao FORA do escopo do hash TISS (ISO-8859-1 + UTF-8).
//
// Invariante de ordem: UTF-32 LE (FF FE 00 00) tem como prefixo o BOM UTF-16
// LE (FF FE). Por isso testamos as marcas de 4 bytes ANTES das de 2 bytes,
// senao um UTF-32 LE seria classificado erroneamente como UTF-16 LE (o erro
// final seria o mesmo, mas a mensagem ficaria imprecisa).
func rejectUTFWideBOM(b []byte) error {
	// UTF-32 (4 bytes) primeiro.
	if len(b) >= 4 {
		if b[0] == 0xFF && b[1] == 0xFE && b[2] == 0x00 && b[3] == 0x00 {
			return &InvalidTissXMLError{Err: errors.New("BOM UTF-32 LE detectado: encoding fora de escopo (ISO-8859-1/UTF-8)")}
		}
		if b[0] == 0x00 && b[1] == 0x00 && b[2] == 0xFE && b[3] == 0xFF {
			return &InvalidTissXMLError{Err: errors.New("BOM UTF-32 BE detectado: encoding fora de escopo (ISO-8859-1/UTF-8)")}
		}
	}
	// UTF-16 (2 bytes).
	if len(b) >= 2 {
		if b[0] == 0xFF && b[1] == 0xFE {
			return &InvalidTissXMLError{Err: errors.New("BOM UTF-16 LE detectado: encoding fora de escopo (ISO-8859-1/UTF-8)")}
		}
		if b[0] == 0xFE && b[1] == 0xFF {
			return &InvalidTissXMLError{Err: errors.New("BOM UTF-16 BE detectado: encoding fora de escopo (ISO-8859-1/UTF-8)")}
		}
	}
	return nil
}

// stripBOM remove o BOM UTF-8 (EF BB BF) se presente no inicio dos bytes.
//
// TISS proibe BOM (encoding declarado eh ISO-8859-1, que nao tem BOM), mas
// a referencia aceita defensivamente.
func stripBOM(b []byte) []byte {
	if len(b) >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF {
		return b[3:]
	}
	return b
}

// charsetReader eh o hook que encoding/xml usa quando ve uma declaracao
// encoding="..." diferente de UTF-8 no prologo.
//
// Suportamos:
//   - iso-8859-1 / latin1 (TISS canonico)
//   - utf-8 / us-ascii (passa direto)
//
// Outros encodings retornam erro explicito: melhor falhar cedo do que
// produzir hash silenciosamente errado.
func charsetReader(charset string, input io.Reader) (io.Reader, error) {
	cs := strings.ToLower(strings.TrimSpace(charset))
	switch cs {
	case "iso-8859-1", "latin1", "iso_8859-1", "iso-ir-100":
		return charmap.ISO8859_1.NewDecoder().Reader(input), nil
	case "utf-8", "utf8", "us-ascii", "ascii", "":
		return input, nil
	default:
		return nil, errors.New("tisshash: encoding nao suportado: " + charset)
	}
}
