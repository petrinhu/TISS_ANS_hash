# tiss-hash (PHP) - Wiki

> **Espelho read-only.** Este repositorio e um split de `langs/php` do monorepo
> [TISS_ANS_hash](https://github.com/petrinhu/TISS_ANS_hash). Issues e pull
> requests vao **no monorepo**, nunca aqui. Este repo existe so para publicar no
> Packagist como [`petrinhu/tiss-hash`](https://packagist.org/packages/petrinhu/tiss-hash).

## O que e

`petrinhu/tiss-hash` e o **port PHP** da lib `TISS_ANS_hash`: calcula o **hash
MD5 do epilogo** (a etiqueta `<ans:hash>`) de um documento XML do Padrao TISS/ANS
(saude suplementar do Brasil, regulamentada pela ANS). Voce passa os bytes do
XML, recebe os 32 caracteres hexadecimais do hash. Nada mais: nao persiste, nao
transmite, nao assina, nao valida contra XSD.

A lib e multi-linguagem (13 ports, todos com o **mesmo hash byte a byte**). Este
e o port PHP.

## Instalacao (Composer)

O **Composer** e o gerenciador que baixa e instala bibliotecas de projetos PHP.
A lib ja esta publicada no Packagist (o repositorio oficial de pacotes PHP):

```bash
composer require petrinhu/tiss-hash
```

Requisitos: PHP **8.2+** e as extensoes `ext-dom`, `ext-libxml`, `ext-mbstring`
(em geral ja habilitadas).

## Uso minimo

```php
<?php
require 'vendor/autoload.php';

use TissHash\TissHash;

$hash = TissHash::hashTiss(file_get_contents('lote.xml'));
echo $hash; // ex.: "3aa0c578c95cdb861a125f480a8a4de5"
```

Passo a passo completo (API, exemplos, erros) em [[Como-usar]].

## A pegadinha do encoding (importante)

Os bytes alimentados ao MD5 sao **UTF-8, NAO ISO-8859-1**. O manual oficial do
Padrao TISS diz "ISO-8859-1", mas isso se refere ao encoding do arquivo, nao dos
bytes que alimentam o MD5. Calcular MD5 sobre bytes ISO-8859-1 gera um hash que a
ANS **rejeita**. Por isso a regra de ouro: **nao reimplemente o algoritmo**, use
este port. Detalhe na [SPEC](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md) do monorepo.

## Privacidade (LGPD)

XML TISS contem dados sensiveis de saude de paciente. A lib so calcula um hash
em memoria, mas quem integra e responsavel: nunca logar, persistir ou transmitir
o conteudo do XML real nem o **hash de dados reais** (o hash e PII indireta).
Nunca exponha a versao do Padrao TISS nem o nome da operadora. Em exemplos use
apenas o hash sintetico `3aa0c578c95cdb861a125f480a8a4de5`.

## Links

- Pacote no Packagist: <https://packagist.org/packages/petrinhu/tiss-hash>
- Monorepo (fonte de verdade), GitHub: <https://github.com/petrinhu/TISS_ANS_hash>
- Monorepo, mirror Codeberg: <https://codeberg.org/petrinhu/TISS_ANS_hash>
- Guia para IA/agente: [AGENTS.md](https://github.com/petrinhu/tiss-hash-php/blob/main/AGENTS.md)
- Como usar (esta wiki): [[Como-usar]]
