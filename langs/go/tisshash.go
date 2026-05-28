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

// InvalidTissXMLError sinaliza que o XML eh mal-formado ou nao pode ser
// decodificado/parseado para calcular o hash. Preserva a causa raiz via
// Unwrap() para inspecao por errors.Is/As.
type InvalidTissXMLError struct {
	Err error
}

// Error implementa error.
func (e *InvalidTissXMLError) Error() string {
	if e == nil || e.Err == nil {
		return "tisshash: XML invalido"
	}
	return "tisshash: XML invalido: " + e.Err.Error()
}

// Unwrap permite errors.Is/As atravessar para a causa raiz do parser.
func (e *InvalidTissXMLError) Unwrap() error {
	if e == nil {
		return nil
	}
	return e.Err
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
		foundHash bool // ja zeramos o primeiro <ans:hash>? (politica: so o primeiro)
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
			es := &elemState{
				name: t.Name,
				isAnsHash: t.Name.Space == Namespace &&
					t.Name.Local == "hash" &&
					!foundHash,
			}
			if es.isAnsHash {
				foundHash = true
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
