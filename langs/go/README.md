# tisshash (Go)

Calcula a "impressao digital" do trecho final de um documento TISS/ANS. Os
termos antes do codigo:

- **XML**: formato de arquivo de texto que organiza dados em etiquetas (tags)
  aninhadas, como caixas dentro de caixas. O Padrao TISS e o XML que operadoras
  de saude e consultorios usam no Brasil para trocar dados de atendimento.
- **Hash**: sequencia curta e fixa de caracteres calculada a partir de um
  texto, como uma impressao digital. Mude uma letra, o hash muda inteiro.
- **MD5**: a receita (algoritmo) que gera o hash; sempre 32 caracteres
  hexadecimais (`0-9` e `a-f`).
- **Epilogo**: a parte final do documento TISS, a etiqueta `<ans:hash>`, onde o
  hash precisa ser gravado.
- **Byte**: a menor unidade de dado do computador; um arquivo de texto e uma
  fila de bytes.

Em uma frase: voce passa os bytes de um XML TISS e recebe os 32 caracteres do
hash. Este e o port Go ("port" = a mesma lib reescrita em outra linguagem) da
biblioteca `tiss-hash`. Para entender o problema que a lib resolve, veja
[`docs/USAGE.md`](../../docs/USAGE.md) (guia de uso) e
[`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) (conceitos e visao geral).

Bate **byte-a-byte** com a implementacao de referencia Python (`conformance/reference.py`) e com os outros ports (C, C++, Rust, Python, PHP, Node.js, Java, C#) nos 20 vetores publicos (18 positivos + 2 negativos).

## Status

- Alpha (v0.1.0).
- Suite de conformidade: **20/20 PASS** (18 positivos + 2 negativos: multi-hash e UTF-16 sao rejeitados).
- Compatibilidade: Go 1.22+ (testado em Go 1.26).
- Licenca: MIT.

## Antes de comecar: instalar o Go

Go e a linguagem deste port. Ela ja traz o compilador, o gerenciador de modulos
e o runner de testes em um unico comando, `go`.

- Baixe e instale pelo site oficial: <https://go.dev/dl/> (precisa da versao
  1.22 ou mais nova). O site tem instrucoes para Windows, Linux e macOS.
- Confira a instalacao:

```bash
go version
```

## Instalacao

Uma **dependencia** (em Go, um "modulo") e uma biblioteca de terceiros que o seu
codigo usa. O comando abaixo baixa esta lib para o seu projeto:

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
5. `<ans:hash>` (namespace TISS) contribui string vazia. Documento sem `<ans:hash>` e valido; com multiplos `<ans:hash>` e rejeitado (erro).
6. MD5 dos bytes UTF-8 do concat. Hex lowercase 32 chars.

Ver `tisshash.go` para detalhes e justificativa das alternativas descartadas.

## Build / Test

A partir da raiz do repositorio (a pasta que voce baixou com `git clone`):

```bash
cd langs/go
go mod tidy       # resolve as dependencias
go test -v ./...  # roda os 20 vetores de conformidade
go vet ./...      # checa boas praticas (opcional)
gofmt -l .        # confere formatacao (opcional)
```

Cada **vetor** e um par "arquivo de entrada -> hash esperado": 18 positivos
(devem produzir um hash) e 2 negativos (devem ser rejeitados).

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

- Guia de uso (comece por aqui): [`docs/USAGE.md`](../../docs/USAGE.md)
- Conceitos e visao geral: [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md)
- Spec: [`docs/SPEC.md`](../../docs/SPEC.md)
- Algoritmo de referencia (o "oraculo" que define a resposta certa): [`conformance/reference.py`](../../conformance/reference.py)
- Vetores: [`conformance/vectors.json`](../../conformance/vectors.json)
- Ambiguidades fixadas: [`conformance/AMBIGUITY_NOTES.md`](../../conformance/AMBIGUITY_NOTES.md)
- Como portar para outra linguagem: [`docs/PORTING_GUIDE.md`](../../docs/PORTING_GUIDE.md)

## Dependencias e licencas

Dependencia de runtime (unica externa; parser e MD5 vem da stdlib):

| Dependencia | Licenca | Uso |
|---|---|---|
| golang.org/x/text | BSD-3-Clause | decode ISO-8859-1 (`charmap.ISO8859_1`) |

Atribuicao consolidada de todos os ports em
[`THIRD_PARTY_LICENSES.md`](../../THIRD_PARTY_LICENSES.md) na raiz do repo.

## Licenca

MIT; ver [LICENSE](LICENSE).
