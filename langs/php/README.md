# tiss-hash (PHP)

Calcula a "impressao digital" do trecho final de um documento TISS/ANS. Os
termos antes do codigo:

- **XML**: formato de arquivo de texto que organiza dados em etiquetas (tags)
  aninhadas, como caixas dentro de caixas. O Padrao TISS e o XML que operadoras
  de saude e consultorios usam no Brasil para trocar dados de atendimento
  (regulamentado pela ANS, a Agencia Nacional de Saude Suplementar).
- **Hash**: sequencia curta e fixa de caracteres calculada a partir de um
  texto, como uma impressao digital. Mude uma letra, o hash muda inteiro.
- **MD5**: a receita (algoritmo) que gera o hash; sempre 32 caracteres
  hexadecimais (`0-9` e `a-f`).
- **Epilogo**: a parte final do documento TISS, a etiqueta `<ans:hash>`, onde o
  hash precisa ser gravado.
- **Parser**: o componente que le o texto do XML e monta a arvore de etiquetas
  na memoria. Aqui o parser e o `DOMDocument`, nativo do PHP.

Em uma frase: voce passa os bytes de um XML TISS e recebe os 32 caracteres do
hash. (Um **byte** e a menor unidade de dado do computador.) Este e o port PHP
("port" = a mesma lib reescrita em outra linguagem). Outras linguagens (Python,
Rust, C, C++, Node.js, etc.) seguem o mesmo contrato e os mesmos vetores de
conformidade.

Para entender o problema que a lib resolve, veja
[`docs/USAGE.md`](../../docs/USAGE.md) (guia de uso) e
[`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) (conceitos e visao geral).

- Repositorio principal: <https://github.com/petrinhu/TISS_ANS_hash>
- Spec canonica: [`docs/SPEC.md`](../../docs/SPEC.md)
- Implementacao de referencia: [`conformance/reference.py`](../../conformance/reference.py) (Python + lxml)
- Status: **alpha**, 20/20 vetores sinteticos PASS (18 positivos + 2 negativos)

## Antes de comecar: instalar o PHP e o Composer

PHP e a linguagem deste port. O **Composer** e o gerenciador que baixa e instala
bibliotecas (dependencias) de projetos PHP.

- Instale o PHP pelo site oficial: <https://www.php.net/manual/pt_BR/install.php>
  (precisa da versao 8.1 ou mais nova). Em Linux costuma estar no gerenciador de
  pacotes da distro (ex.: `sudo dnf install php php-dom php-mbstring`).
- Instale o Composer pelo site oficial: <https://getcomposer.org/download/>
- Confira a instalacao:

```bash
php --version
composer --version
```

## Requisitos

- PHP **8.1+** (testado em 8.5).
- Extensoes: `ext-dom`, `ext-libxml`, `ext-mbstring` (todas standard na maioria das builds). Uma **extensao** e um modulo que acrescenta funcoes ao PHP; estas tres costumam ja vir habilitadas.

## Instalacao

Uma **dependencia** e uma biblioteca de terceiros que o seu codigo usa; o
Composer a baixa e instala. O comando abaixo adiciona esta lib ao seu projeto:

```bash
composer require petrinhu/tiss-hash
```

Publicado no Packagist (o repositorio oficial de pacotes PHP):
<https://packagist.org/packages/petrinhu/tiss-hash>. O comando acima ja resolve
direto da internet, sem configuracao extra.

> **Nota (detalhe transparente para voce):** o Packagist serve este pacote a
> partir de um repositorio dedicado e somente-leitura,
> `github.com/petrinhu/tiss-hash-php`, que e um espelho de `langs/php` gerado por
> split automatico a cada release (o Packagist exige o `composer.json` na raiz, e
> aqui o codigo vive num monorepo). Voce nao precisa fazer nada com isso: basta
> `composer require petrinhu/tiss-hash`.
>
> **Alternativa: instalar do fonte (checkout do monorepo).** Se voce clonou o
> monorepo e quer usar o codigo local, aponte o Composer para a pasta do port:
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

Especificacao canonica completa: [`docs/SPEC.md`](../../docs/SPEC.md).

Catalogo de 15 ambiguidades canonicas que cada port deve reproduzir:
[`conformance/AMBIGUITY_NOTES.md`](../../conformance/AMBIGUITY_NOTES.md).

## Conformidade

"Conformidade" significa provar que este port produz o mesmo hash da
implementacao oficial em todos os casos previstos. Cada **vetor** e um par
"arquivo de entrada -> hash esperado": positivo deve produzir um hash, negativo
deve ser rejeitado (a lib precisa recusar o arquivo, em vez de inventar um hash).

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

Rodar os testes localmente, a partir da raiz do repositorio (a pasta que voce
baixou com `git clone`):

```bash
cd langs/php
composer install   # baixa as dependencias de teste
composer test      # roda os 20 vetores de conformidade
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

## Ver também

- [`docs/USAGE.md`](../../docs/USAGE.md): guia de uso, receitas e perguntas
  frequentes (comece por aqui se voce quer so usar a lib).
- [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md): conceitos e visao geral.
- [`docs/SPEC.md`](../../docs/SPEC.md): especificacao canonica do algoritmo.
- [`docs/PORTING_GUIDE.md`](../../docs/PORTING_GUIDE.md): guia para portar para
  outras linguagens.
- [`conformance/reference.py`](../../conformance/reference.py): implementacao de
  referencia (o "oraculo" que define a resposta certa).
