// Testes de conformidade: roda os 20 vetores publicos em
// conformance/vectors.json. Vetores POSITIVOS (expect ausente ou "hash")
// comparam contra expected_md5; vetores NEGATIVOS (expect == "error") exigem
// que HashTiss retorne erro (multiplos <ans:hash>, BOM UTF-16/UTF-32).
//
// Resolucao do diretorio conformance/: subimos 2 niveis a partir da raiz do
// pacote (langs/go -> langs -> raiz_repo) e entramos em conformance/. O test
// runner do Go usa CWD = diretorio do pacote, entao caminhos relativos
// funcionam de forma estavel.

package tisshash

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// vector descreve um caso de teste em vectors.json.
//
// Expect: "" ou "hash" = positivo (compara ExpectedMD5); "error" = negativo
// (HashTiss DEVE retornar erro). ExpectedMD5 eh null no JSON para negativos,
// entao usamos *string para distinguir null de string vazia.
type vector struct {
	ID          string  `json:"id"`
	Input       string  `json:"input"`
	ExpectedMD5 *string `json:"expected_md5"`
	Expect      string  `json:"expect"`
	Source      string  `json:"source"`
	Desc        string  `json:"desc"`
}

// manifest eh o root do vectors.json (so usamos vectors[]).
type manifest struct {
	Vectors []vector `json:"vectors"`
}

// conformanceDir resolve o caminho absoluto pra .../conformance/ subindo 2
// niveis do diretorio do pacote (que eh CWD durante go test).
func conformanceDir(t *testing.T) string {
	t.Helper()
	cwd, err := os.Getwd()
	if err != nil {
		t.Fatalf("os.Getwd: %v", err)
	}
	// cwd = .../langs/go ; subir 2 niveis e entrar em conformance/
	return filepath.Join(cwd, "..", "..", "conformance")
}

// loadManifest le e desserializa vectors.json.
func loadManifest(t *testing.T) manifest {
	t.Helper()
	path := filepath.Join(conformanceDir(t), "vectors.json")
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("ler %s: %v", path, err)
	}
	var m manifest
	if err := json.Unmarshal(raw, &m); err != nil {
		t.Fatalf("parse %s: %v", path, err)
	}
	if len(m.Vectors) == 0 {
		t.Fatalf("vectors.json sem vetores")
	}
	return m
}

// TestConformanceVetores roda table-driven sobre todos os 20 vetores
// publicos. Falha individual nao aborta os outros (t.Run isola sub-tests).
//
// Ramifica por v.Expect:
//   - "error": exige err != nil E que o erro satisfaca errors.Is(err,
//     ErrInvalidTissXML) (contrato de rejeicao tipada).
//   - "" ou "hash": exige err == nil e hash == *v.ExpectedMD5.
func TestConformanceVetores(t *testing.T) {
	m := loadManifest(t)
	dir := conformanceDir(t)

	for _, v := range m.Vectors {
		v := v // shadow pra captura segura no closure (Go < 1.22 needed; OK pra 1.22+ tambem)
		t.Run(v.ID, func(t *testing.T) {
			inputPath := filepath.Join(dir, v.Input)
			raw, err := os.ReadFile(inputPath)
			if err != nil {
				t.Fatalf("ler input %s: %v", inputPath, err)
			}
			got, err := HashTiss(raw)

			if v.Expect == "error" {
				// Vetor NEGATIVO: deve rejeitar.
				if err == nil {
					t.Fatalf("vetor %s: esperava erro (negativo), recebi hash=%s\n  desc = %s",
						v.ID, got, v.Desc)
				}
				if !errors.Is(err, ErrInvalidTissXML) {
					t.Errorf("vetor %s: erro nao satisfaz errors.Is(ErrInvalidTissXML): %T %v",
						v.ID, err, err)
				}
				return
			}

			// Vetor POSITIVO.
			if err != nil {
				t.Fatalf("vetor %s: erro inesperado em vetor positivo: %v", v.ID, err)
			}
			if v.ExpectedMD5 == nil {
				t.Fatalf("vetor %s: positivo sem expected_md5 no manifesto", v.ID)
			}
			if got != *v.ExpectedMD5 {
				t.Errorf("vetor %s: hash divergente\n  got      = %s\n  expected = %s\n  desc     = %s",
					v.ID, got, *v.ExpectedMD5, v.Desc)
			}
		})
	}
}

// TestHashTissFileEquivalente: HashTissFile e HashTiss(ReadFile) devem
// produzir o mesmo hash byte-a-byte.
func TestHashTissFileEquivalente(t *testing.T) {
	dir := conformanceDir(t)
	path := filepath.Join(dir, "inputs/syn_acento.xml")

	h1, err := HashTissFile(path)
	if err != nil {
		t.Fatalf("HashTissFile: %v", err)
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("ReadFile: %v", err)
	}
	h2, err := HashTiss(raw)
	if err != nil {
		t.Fatalf("HashTiss: %v", err)
	}
	if h1 != h2 {
		t.Errorf("HashTissFile != HashTiss(ReadFile): %s vs %s", h1, h2)
	}
	const want = "a20afc9a89aadaa2179d03d225337662"
	if h1 != want {
		t.Errorf("hash syn_acento divergente: got=%s want=%s", h1, want)
	}
}

// TestHashTissFileNaoExiste: erro de I/O eh propagado e wrappable via
// errors.Is (os.ErrNotExist).
func TestHashTissFileNaoExiste(t *testing.T) {
	_, err := HashTissFile("/path/que/com/certeza/nao/existe/foo.xml")
	if err == nil {
		t.Fatal("esperava erro de I/O, recebi nil")
	}
	if !errors.Is(err, os.ErrNotExist) {
		t.Errorf("erro nao wrappa os.ErrNotExist: %v", err)
	}
}

// TestXMLInvalidoRetornaErroTipado: bytes nao-XML devem virar
// InvalidTissXMLError com causa preservada.
func TestXMLInvalidoRetornaErroTipado(t *testing.T) {
	_, err := HashTiss([]byte("isso nao eh xml <"))
	if err == nil {
		t.Fatal("esperava erro de parsing, recebi nil")
	}
	var invErr *InvalidTissXMLError
	if !errors.As(err, &invErr) {
		t.Errorf("erro nao eh *InvalidTissXMLError: %T %v", err, err)
	}
	if invErr != nil && invErr.Unwrap() == nil {
		t.Errorf("InvalidTissXMLError sem causa raiz")
	}
}

// TestEncodingNaoSuportado: encoding desconhecido na declaracao XML deve
// falhar explicitamente (melhor que produzir hash silenciosamente errado).
func TestEncodingNaoSuportado(t *testing.T) {
	xml := []byte(`<?xml version='1.0' encoding='shift_jis'?><a>x</a>`)
	_, err := HashTiss(xml)
	if err == nil {
		t.Fatal("esperava erro de encoding nao suportado, recebi nil")
	}
	if !strings.Contains(err.Error(), "encoding") {
		t.Errorf("mensagem nao menciona encoding: %v", err)
	}
}

// TestStripBOM: BOM UTF-8 no inicio nao deve afetar o hash (referencia
// aceita defensivamente). Comparado com vetor canonico syn_bom_utf8.xml.
func TestVetorBOM(t *testing.T) {
	dir := conformanceDir(t)
	path := filepath.Join(dir, "inputs/syn_bom_utf8.xml")
	got, err := HashTissFile(path)
	if err != nil {
		t.Fatalf("HashTissFile: %v", err)
	}
	const want = "47d20fe3f5bb21cba74e54e5292170ab"
	if got != want {
		t.Errorf("syn_bom_utf8: got=%s want=%s", got, want)
	}
}

// TestHashMinimoInline: sanidade. XML minimo, hash zerado, sem texto = MD5("").
func TestHashMinimoInline(t *testing.T) {
	xml := []byte(`<?xml version='1.0' encoding='utf-8'?>` +
		`<ans:mensagemTISS xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">` +
		`<ans:epilogo><ans:hash>QUALQUER</ans:hash></ans:epilogo>` +
		`</ans:mensagemTISS>`)
	got, err := HashTiss(xml)
	if err != nil {
		t.Fatalf("HashTiss: %v", err)
	}
	// MD5("") = d41d8cd98f00b204e9800998ecf8427e
	sum := md5.Sum([]byte(""))
	want := hex.EncodeToString(sum[:])
	if got != want {
		t.Errorf("hash minimo: got=%s want=%s", got, want)
	}
}

// TestMultiplosHashRejeitado: >1 <ans:hash> do namespace TISS deve virar
// InvalidTissXMLError (A-COV2), satisfazendo errors.Is(ErrInvalidTissXML).
func TestMultiplosHashRejeitado(t *testing.T) {
	xml := []byte(`<?xml version='1.0' encoding='utf-8'?>` +
		`<ans:m xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">` +
		`<ans:hash>A</ans:hash><ans:hash>B</ans:hash>` +
		`</ans:m>`)
	_, err := HashTiss(xml)
	if err == nil {
		t.Fatal("esperava rejeicao de multiplos <ans:hash>, recebi nil")
	}
	if !errors.Is(err, ErrInvalidTissXML) {
		t.Errorf("erro nao satisfaz errors.Is(ErrInvalidTissXML): %T %v", err, err)
	}
	if !strings.Contains(err.Error(), "hash") {
		t.Errorf("mensagem nao menciona hash: %v", err)
	}
}

// TestHashDefaultNamespaceCasaPorURI: <hash> com TISS como namespace default
// (sem prefixo ans:) deve ser reconhecido e contar no limite de 1 — provando
// que casamos por URI, nao por prefixo literal.
func TestHashDefaultNamespaceCasaPorURI(t *testing.T) {
	xml := []byte(`<?xml version='1.0' encoding='utf-8'?>` +
		`<m xmlns="http://www.ans.gov.br/padroes/tiss/schemas">` +
		`<hash>A</hash><hash>B</hash>` +
		`</m>`)
	_, err := HashTiss(xml)
	if err == nil {
		t.Fatal("esperava rejeicao com hash em namespace default, recebi nil")
	}
	if !errors.Is(err, ErrInvalidTissXML) {
		t.Errorf("erro nao satisfaz errors.Is(ErrInvalidTissXML): %T %v", err, err)
	}
}

// TestRejectBOMWide: cada BOM UTF-16/UTF-32 deve ser rejeitado ANTES de
// qualquer decodificacao, satisfazendo errors.Is(ErrInvalidTissXML).
func TestRejectBOMWide(t *testing.T) {
	cases := []struct {
		name string
		bom  []byte
	}{
		{"utf16-le", []byte{0xFF, 0xFE, 0x3C, 0x00}},
		{"utf16-be", []byte{0xFE, 0xFF, 0x00, 0x3C}},
		{"utf32-le", []byte{0xFF, 0xFE, 0x00, 0x00}},
		{"utf32-be", []byte{0x00, 0x00, 0xFE, 0xFF}},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			_, err := HashTiss(tc.bom)
			if err == nil {
				t.Fatalf("BOM %s: esperava rejeicao, recebi nil", tc.name)
			}
			if !errors.Is(err, ErrInvalidTissXML) {
				t.Errorf("BOM %s: erro nao satisfaz errors.Is(ErrInvalidTissXML): %T %v", tc.name, err, err)
			}
		})
	}
}

// BenchmarkHashTissPerfGrande: throughput em um documento ~600KB / ~1500 guias.
// Tornavel publica via go test -bench=. -benchmem ./...
func BenchmarkHashTissPerfGrande(b *testing.B) {
	cwd, err := os.Getwd()
	if err != nil {
		b.Fatalf("Getwd: %v", err)
	}
	path := filepath.Join(cwd, "..", "..", "conformance", "inputs", "syn_perf_grande.xml")
	raw, err := os.ReadFile(path)
	if err != nil {
		b.Fatalf("ReadFile: %v", err)
	}
	b.SetBytes(int64(len(raw)))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := HashTiss(raw); err != nil {
			b.Fatalf("HashTiss: %v", err)
		}
	}
}
