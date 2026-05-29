# tiss-hash (PHP)

Hash MD5 do epilogo XML TISS/ANS (Padrao TISS, Troca de Informacoes em
Saude Suplementar, regulamentado pela ANS). Implementacao PHP portavel,
com parsing endurecido contra XXE e billion-laughs.

Este e o port PHP da biblioteca `lib_hash_ans`. Outras linguagens
(Python, Rust, C, C++, Node.js, etc.) seguem o mesmo contrato e os mesmos
vetores de conformidade.

- Repositorio principal: <https://github.com/petrinhu/TISS_ANS_hash>
- Spec canonica: [`docs/SPEC.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md)
- Implementacao de referencia: `conformance/reference.py` (Python + lxml)
- Status: **alpha**, 20/20 vetores sinteticos PASS (18 positivos + 2 negativos)

## Requisitos

- PHP **8.1+** (testado em 8.5).
- Extensoes: `ext-dom`, `ext-libxml`, `ext-mbstring` (todas standard na maioria das builds).

## Instalacao

```bash
composer require petrinhu/tiss-hash
```

> **Nota:** ainda nao publicado no Packagist. Por enquanto, adicione o
> repositorio manualmente em `composer.json` ou instale a partir do
> checkout do monorepo:
>
> ```bash
> composer config repositories.tiss-hash path /caminho/para/lib_hash_ans/langs/php
> composer require petrinhu/tiss-hash:@dev
> ```

## Quickstart

```php
<?php
require 'vendor/autoload.php';

use TissHash\TissHash;

// A partir de bytes do arquivo
$hash = TissHash::hashTiss(file_get_contents('lote.xml'));
echo $hash; // ex.: "3aa0c578c95cdb861a125f480a8a4de5"

// Ou direto do caminho
$hash = TissHash::hashTissFile('lote.xml');
```

Tratamento de erro:

```php
use TissHash\InvalidTissXmlException;
use TissHash\TissHash;

try {
    $hash = TissHash::hashTiss('<isto-nao-eh-xml-valido');
} catch (InvalidTissXmlException $e) {
    error_log('falha ao parsear: ' . $e->getMessage());
}
```

## API publica

| Simbolo | Tipo | Descricao |
| --- | --- | --- |
| `TissHash\TissHash::hashTiss(string $xmlBytes): string` | metodo estatico | Hash MD5 (hex, 32 chars) a partir dos bytes do XML. |
| `TissHash\TissHash::hashTissFile(string $path): string` | metodo estatico | Atalho que le o arquivo e delega para `hashTiss`. |
| `TissHash\TissHash::TISS_NAMESPACE` | constante | URI do namespace TISS (`http://www.ans.gov.br/padroes/tiss/schemas`). |
| `TissHash\InvalidTissXmlException` | classe | Excecao (subclasse de `\RuntimeException`) para XML malformado, vazio ou rejeitado por politica de seguranca. |

## Algoritmo

Resumo do que `TissHash::hashTiss` faz:

1. Parseia o XML com `DOMDocument`, endurecido contra XXE
   (`libxml_set_external_entity_loader` + flag `LIBXML_NONET`).
2. Zera o conteudo de `<ans:hash>` (namespace
   `http://www.ans.gov.br/padroes/tiss/schemas`).
3. Concatena o texto de cada no-folha (Element ou Comment sem filhos
   Element/Comment/PI) em ordem de documento.
4. Calcula MD5 sobre os bytes **UTF-8** da string resultante.
5. Devolve o `md5()` minusculo (32 caracteres).

**Atencao:** o encoding dos bytes alimentados ao MD5 e **UTF-8**, NAO
ISO-8859-1. O manual TISS afirma o contrario, mas o valor validado contra
goldens reais (privados, fora do repo) e os vetores sinteticos publicos e
UTF-8.

Especificacao canonica completa: [`docs/SPEC.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md).

Catalogo de 15 ambiguidades canonicas que cada port deve reproduzir:
[`conformance/AMBIGUITY_NOTES.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/conformance/AMBIGUITY_NOTES.md).

## Conformidade

20/20 vetores sinteticos do manifesto publico (`conformance/vectors.json`):
18 positivos + 2 negativos. A lista canonica vive em
`conformance/vectors.json`.

| Vetor | Cobre |
| --- | --- |
| `syn_minimal.xml` | cabecalho + epilogo, hash zerado sobrescrito |
| `syn_acento.xml` | discriminador UTF-8 vs ISO-8859-1 |
| `syn_empty.xml` | `<x></x>` e `<x/>` equivalentes |
| `syn_crlf_value.xml` | CR/LF preservado dentro de valor |
| `syn_multi_guia.xml` | ordem de documento |
| `syn_entidades_xml.xml` | `&amp;`, `&lt;` etc. decodificadas |
| `syn_entidade_numerica.xml` | entidades numericas (`&#nn;`) decodificadas |
| `syn_cdata.xml` | CDATA = texto literal |
| `syn_comentario.xml` | comentario XML ENTRA no concat |
| `syn_atributo_folha.xml` | atributos NAO entram |
| `syn_namespace_xsi.xml` | prefixo de namespace irrelevante |
| `syn_default_ns.xml` | namespace default (sem prefixo) |
| `syn_sem_hash.xml` | documento sem `<ans:hash>` (valido) |
| `syn_whitespace_puro.xml` | espacos puros preservados |
| `syn_leading_zero.xml` | zeros a esquerda mantidos |
| `syn_iso8859_simbolos.xml` | `grau`, `paragrafo`, `meio`, `micro` validos em ISO-8859-1 |
| `syn_perf_grande.xml` | ~600KB, ~1500 guias |
| `syn_bom_utf8.xml` | BOM UTF-8 aceito |

Mais 2 vetores **negativos** (esperam erro): `syn_multi_hash.xml`
(multiplos `<ans:hash>` -> rejeitado) e `syn_utf16.xml` (UTF-16 fora de
escopo -> rejeitado). Encodings suportados: ISO-8859-1 e UTF-8.

Rodar os testes localmente:

```bash
cd langs/php
composer install
composer test
```

Saida esperada: `OK (... tests)`: 20 vetores de conformidade (data
provider) mais testes auxiliares de API.

## Seguranca

- **XXE**: `libxml_set_external_entity_loader(fn() => null)` antes do
  parse; `LIBXML_NONET` proibe acesso a rede.
- **PHP 8.4 compat**: `libxml_disable_entity_loader()` foi removida
  nessa versao; este port usa a API moderna.
- **PII em mensagens de erro**: a `InvalidTissXmlException` nunca
  contem o XML original, apenas o erro tecnico do parser
  (linha/coluna/sintaxe). Logs de chamadores devem manter o mesmo cuidado.

## Licenca

[MIT](LICENSE).
