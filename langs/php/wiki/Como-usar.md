# Como usar o port PHP

> Port PHP da lib `TISS_ANS_hash`. Instala via Composer, calcula o hash MD5 do
> epilogo `<ans:hash>` de um XML do Padrao TISS/ANS. Volta para a [[Home]].

## 1. Instalar

```bash
composer require petrinhu/tiss-hash
```

Requisitos: PHP 8.2+, extensoes `ext-dom`, `ext-libxml`, `ext-mbstring`.

## 2. API publica

Namespace `TissHash`:

| Simbolo | Descricao |
| --- | --- |
| `TissHash\TissHash::hashTiss(string $xmlBytes): string` | hash MD5 (32 chars hex) a partir dos bytes do XML |
| `TissHash\TissHash::hashTissFile(string $path): string` | atalho que le o arquivo e delega para `hashTiss` |
| `TissHash\TissHash::TISS_NAMESPACE` | constante com a URI do namespace TISS |
| `TissHash\InvalidTissXmlException` | excecao (subclasse de `\RuntimeException`) |

**Regra de ouro:** passe sempre os **bytes crus** do XML (o resultado de
`file_get_contents()`). Nao decodifique nem "conserte" o XML antes: a lib
controla o encoding internamente.

## 3. Exemplo completo (XML sintetico)

```php
<?php
require 'vendor/autoload.php';

use TissHash\TissHash;

$xml = <<<XML
<?xml version="1.0" encoding="iso-8859-1"?>
<ans:mensagemTISS xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">
  <ans:cabecalho>
    <ans:identificacaoTransacao>
      <ans:tipoTransacao>ENVIO_LOTE_GUIAS</ans:tipoTransacao>
    </ans:identificacaoTransacao>
  </ans:cabecalho>
  <ans:epilogo>
    <ans:hash>00000000000000000000000000000000</ans:hash>
  </ans:epilogo>
</ans:mensagemTISS>
XML;

echo TissHash::hashTiss($xml); // 32 caracteres hex minusculos
```

O conteudo de `<ans:hash>` e **zerado** antes do calculo (o hash nao entra em si
mesmo). Tanto faz o que estiver la dentro.

> Nunca use XML ou hash de dados reais em exemplo, teste ou log. So sintetico.

## 4. Tratamento de erro

```php
use TissHash\InvalidTissXmlException;
use TissHash\TissHash;

try {
    $hash = TissHash::hashTiss($xmlBytes);
    // usar $hash
} catch (InvalidTissXmlException $e) {
    // XML vazio, malformado, encoding fora de escopo, ou multiplos <ans:hash>.
    // A mensagem NUNCA contem o XML original (apenas o erro tecnico do parser).
    error_log('XML TISS invalido: ' . $e->getMessage());
}
```

## 5. Contrato de rejeicao

| Entrada | Comportamento |
| --- | --- |
| XML bem-formado com 1 `<ans:hash>` | retorna hash de 32 chars |
| XML bem-formado **sem** `<ans:hash>` | **valido**: concatena tudo, sem erro |
| **Multiplos** `<ans:hash>` | **erro** `InvalidTissXmlException` |
| Encoding **UTF-16 / UTF-32** (por BOM) | **erro** (so ISO-8859-1 e UTF-8) |
| XML malformado / bytes vazios | **erro** `InvalidTissXmlException` |

Entidade externa (XXE) e sempre bloqueada.

## 6. Validar contra os vetores de conformidade

A "verdade" do projeto sao os 20 vetores sinteticos (18 positivos + 2 negativos)
em [`conformance/vectors.json`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/conformance/vectors.json)
no monorepo. Este port passa 20/20. Para conferir:

```bash
git clone https://github.com/petrinhu/TISS_ANS_hash
cd TISS_ANS_hash/langs/php
composer install
composer test
```

Saida esperada: `OK` com os 20 vetores mais testes auxiliares de API.

## 7. A pegadinha do encoding

Os bytes alimentados ao MD5 sao **UTF-8, NAO ISO-8859-1**, mesmo que o arquivo
declare `encoding="iso-8859-1"`. O `DOMDocument` le a declaracao e armazena
internamente em UTF-8; `textContent` ja vem em UTF-8, e `md5()` calcula sobre
esses bytes. Por isso nao reimplemente: a interpretacao literal do manual gera
hash errado. Ver [`docs/SPEC.md §4`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md).

## 8. Onde reportar (este repo e read-only)

Issues e pull requests vao **no monorepo**:

- GitHub: <https://github.com/petrinhu/TISS_ANS_hash/issues>
- Codeberg: <https://codeberg.org/petrinhu/TISS_ANS_hash/issues>

## Ver tambem

- [[Home]] desta wiki.
- [Pacote no Packagist](https://packagist.org/packages/petrinhu/tiss-hash).
- [`docs/USAGE.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/USAGE.md): guia de uso completo, por linguagem.
- [`docs/SPEC.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md): especificacao canonica do algoritmo.
- [AGENTS.md](https://github.com/petrinhu/tiss-hash-php/blob/main/AGENTS.md): guia para IA/agente.
