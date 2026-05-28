# tisshash (Go)

Port Go da biblioteca `tiss-hash`: hash MD5 do epilogo `<ans:hash>` de mensagens XML do Padrao TISS/ANS (saude suplementar Brasil).

Bate **byte-a-byte** com a implementacao de referencia Python (`conformance/reference.py`) e com os outros 6 ports (C, C++, Rust, Python, PHP, Node.js) nos 15 vetores publicos.

## Status

- Alpha (v0.1.0).
- Suite de conformidade: **15/15 PASS**.
- Compatibilidade: Go 1.22+ (testado em Go 1.26).
- Licenca: MIT.

## Instalacao

```bash
go get github.com/petrinhu/TISS_ANS_hash/langs/go
```

(O modulo ainda nao tem tag publicada; em desenvolvimento.)

## Uso

```go
package main

import (
    "fmt"
    "os"

    tisshash "github.com/petrinhu/TISS_ANS_hash/langs/go"
)

func main() {
    // A partir de bytes
    data, err := os.ReadFile("lote.xml")
    if err != nil {
        panic(err)
    }
    hash, err := tisshash.HashTiss(data)
    if err != nil {
        panic(err)
    }
    fmt.Println(hash) // 32 chars hex lowercase

    // Ou direto do arquivo
    hash, err = tisshash.HashTissFile("lote.xml")
    if err != nil {
        panic(err)
    }
    fmt.Println(hash)
}
```

## Tratamento de erro

```go
hash, err := tisshash.HashTiss(rawXML)
if err != nil {
    var invErr *tisshash.InvalidTissXMLError
    switch {
    case errors.As(err, &invErr):
        // XML mal-formado ou encoding nao suportado
        log.Printf("XML invalido: %v", invErr.Unwrap())
    default:
        // Erro de I/O ou outro
        log.Printf("falha: %v", err)
    }
    return
}
```

## Constantes publicas

- `tisshash.Namespace` (string): URI do namespace TISS, usado pra identificar `<ans:hash>` independente de prefixo. Valor: `http://www.ans.gov.br/padroes/tiss/schemas`.
- `tisshash.Version` (string): versao desta implementacao.

## Decisoes de implementacao

**Parser**: `encoding/xml` da stdlib em modo streaming (`Decoder.Token()`). Zero dep externa. Os tipos de token `StartElement`, `EndElement`, `CharData` (texto + CDATA), `Comment`, `ProcInst`, `Directive` cobrem tudo que a referencia precisa reproduzir.

**Encoding ISO-8859-1**: `Decoder.CharsetReader` hookado em `golang.org/x/text/encoding/charmap.ISO8859_1` (unica dep externa).

**MD5**: `crypto/md5` stdlib.

**Algoritmo**:
1. Strip BOM UTF-8 se presente.
2. Parse streaming: pilha de elementos, cada um acumulando texto e flag de "tem filho estruturado".
3. Em `EndElement`, se o elemento que fecha NAO teve filho Element/Comment/PI/Directive, eh folha; contribui texto pro concat global.
4. Comentarios entram no concat (ambiguidade #2 da referencia; ver `conformance/AMBIGUITY_NOTES.md`).
5. `<ans:hash>` (primeira ocorrencia, namespace TISS) contribui string vazia.
6. MD5 dos bytes UTF-8 do concat. Hex lowercase 32 chars.

Ver `tisshash.go` para detalhes e justificativa das alternativas descartadas.

## Build / Test

```bash
cd langs/go
go mod tidy
go test -v ./...
go vet ./...
gofmt -l .
```

Benchmark:

```bash
go test -bench=. -benchmem ./...
```

## Garantias

- Algoritmo idempotente (sem estado global mutavel).
- Sem `panic` em caminho de entrada controlada; erros tipados via `InvalidTissXMLError` (com `Unwrap()` pra preservar causa).
- Sem `unsafe`.
- Validacao em borda: encoding rejeitado se nao for utf-8/ascii/iso-8859-1 (melhor falhar do que produzir hash errado).
- Sem rede, sem I/O alem de leitura local opcional (`HashTissFile`).
- Sem expansao de entidades externas / DTDs externos (`encoding/xml` ja eh seguro por design).

## Referencia canonica

- Spec: [`docs/SPEC.md`](../../docs/SPEC.md)
- Algoritmo de referencia: [`conformance/reference.py`](../../conformance/reference.py)
- Vetores: [`conformance/vectors.json`](../../conformance/vectors.json)
- Ambiguidades fixadas: [`conformance/AMBIGUITY_NOTES.md`](../../conformance/AMBIGUITY_NOTES.md)

## Licenca

MIT; ver [LICENSE](LICENSE).
