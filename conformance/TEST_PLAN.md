# Plano de teste — Conformidade `lib_hash_ans`

Suite de conformidade canônica que **todo port** (C, C++, Rust, Python, PHP, Node.js, etc.) tem que passar byte-a-byte. A implementação de referência (`reference.py`) é o oráculo: o hash que ela produz É o resultado correto, mesmo quando o algoritmo diverge da prosa do manual TISS.

## Escopo

**In:**
- Validar que cada port reproduz exatamente os hashes MD5 listados em `vectors.json`.
- Cobrir casos de borda de parsing, encoding, whitespace, estrutura XML e performance.
- Fixar comportamentos ambíguos da referência (ver `AMBIGUITY_NOTES.md`).

**Out:**
- Validar conformidade com o schema XSD TISS oficial (fora do escopo do hash).
- Geração de XML TISS válido (só consumimos).
- Assinatura digital (separado do hash).
- Transporte / SOAP / autenticação.

## Algoritmo (espec. canônica)

Reproduzida em `vectors.json` campo `algorithm`:

1. **Parse XML** com parser padrão (não precisa `remove_blank_text`).
2. **Zerar** o conteúdo do elemento `<ans:hash>` antes do concat.
3. **Concatenar** o `.text` de cada elemento-folha (sem filhos) em ordem de documento.
4. **MD5** dos bytes **UTF-8** da string concatenada (NÃO ISO-8859-1, apesar do manual).
5. **hexdigest** minúsculo, 32 caracteres.

Detalhe crítico: o arquivo é lido como ISO-8859-1 (encoding declarado pelo TISS), mas os valores extraídos são re-encodados em UTF-8 antes do MD5.

## Estrutura do `vectors.json`

```json
{
  "algorithm": {
    "name": "TISS/ANS epilogo MD5",
    "steps": [ ... ],
    "encoding_bytes_md5": "utf-8",
    "namespace": "http://www.ans.gov.br/padroes/tiss/schemas",
    "note": "..."
  },
  "vectors": [
    {
      "id": "syn_minimal.xml",
      "input": "inputs/syn_minimal.xml",
      "expected_md5": "3aa0c578c95cdb861a125f480a8a4de5",
      "source": "derived",
      "desc": "descricao livre do caso de borda coberto"
    },
    ...
  ]
}
```

O manifesto público distribuído contém **15 vetores, todos `source: derived` (100% sintéticos)**. O campo `source` admite o valor `"real"` no schema, mas vetores reais (PII de pacientes) só existem no build privado do mantenedor e nunca são commitados.

**Schema dos campos por vetor:**

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `id` | string | sim | Nome único do vetor (sempre igual ao basename do input). |
| `input` | string | sim | Caminho relativo (a partir de `conformance/`) ao XML de entrada. |
| `expected_md5` | string (32 hex lowercase) | sim | Hash que a referência produz e que o port DEVE reproduzir. |
| `source` | `"real"` ou `"derived"` | sim | `real` = golden validado pelo usuário; `derived` = sintético gerado pela referência. |
| `desc` | string | sim | Descrição em pt-br do caso de borda coberto. |

**Imutabilidade:**
- Vetores `source: real` **NÃO** podem ser modificados. São ground truth do usuário.
- Vetores `source: derived` existentes **NÃO** devem ser removidos nem renomeados. Apenas ADICIONAR novos.
- Hashes em `vectors.json` são regerados automaticamente por `build_fixture.py`. Mudança inesperada em hash de vetor derivado indica regressão na referência ou no input.

## Como cada port consome os vetores

Algoritmo de teste universal (pseudo-código):

```
manifesto = ler_json("conformance/vectors.json")
fails = []
for v in manifesto["vectors"]:
    raw = ler_bytes("conformance/" + v["input"])
    calc = port.hash_tiss_bytes(raw)
    if calc != v["expected_md5"]:
        fails.append((v["id"], calc, v["expected_md5"]))
if fails: REPROVAR e listar
```

**Requisitos do port:**

- Função pública mínima: `hash_tiss_bytes(raw: bytes) -> str` (32 hex lowercase).
- Função auxiliar: `hash_tiss_file(path: str) -> str` (conveniência).
- Não depender de pasta corrente; receber `path` absoluto ou bytes.
- Não printar; retornar a string hex.
- Falhar com erro tipado em XML malformado (não silenciar).

**Categorias de teste (organização):**

| Categoria | Vetores | Cobre |
|---|---|---|
| **Goldens reais (privados, fora do repo)** | três XMLs reais TISS | Validados manualmente pelo mantenedor; contêm PII e NÃO entram no manifesto público. Validados apenas no build privado (`TISS_PRIVATE_XMLS`). |
| **Estrutura básica** | `syn_minimal.xml`, `syn_empty.xml`, `syn_multi_guia.xml` | Cabeçalho mínimo, campos vazios (`<x></x>` e `<y/>`), ordem documento em multi-guia. |
| **Encoding** | `syn_acento.xml`, `syn_iso8859_simbolos.xml`, `syn_bom_utf8.xml` | Acentuação (`É Ç Ã`), símbolos latin1 (`° § ½ µ`), arquivo com BOM UTF-8. |
| **Whitespace** | `syn_crlf_value.xml`, `syn_whitespace_puro.xml` | CR/LF dentro de valor preservado, valor com só espaços preservado. |
| **Parsing XML** | `syn_entidades_xml.xml`, `syn_cdata.xml`, `syn_comentario.xml` | Entidades predefinidas decodificadas; CDATA tratado como texto; comentários (ambiguidade — ver notes). |
| **Estrutura XML avançada** | `syn_atributo_folha.xml`, `syn_namespace_xsi.xml` | Atributos ignorados; namespace alternativo (`xsi:`) ignorado. |
| **Valores literais** | `syn_leading_zero.xml` | Strings numéricas preservadas (`00123` ≠ `123`). |
| **Performance** | `syn_perf_grande.xml` | ~455 KB / ~1500 guias / ~9000 folhas. Baseline da referência Python: ~5 ms/iter. |

## Critérios PASS / FAIL

### PASS (por vetor)
- `port.hash_tiss_bytes(raw)` retorna **exatamente** `expected_md5` (string-igual, lowercase, 32 chars).

### FAIL (qualquer um)
- Hash diferente do esperado.
- Função explode (exceção não documentada) num input que a referência aceita.
- Aceita sem erro um input que a referência rejeita (XML malformado, etc.).
- Retorna string em case diferente (maiúsculo) ou com prefixo/sufixo.
- Demora absurdamente mais que a referência em `syn_perf_grande.xml` (alerta de perf, não fail de correção; tolerância sugerida: ≤ 10× a referência da própria linguagem).

### Suite PASS
- 100% dos vetores PASS. Sem skip, sem retry.
- Reproduzível em 100 runs locais (zero flakiness).
- Determinístico em qualquer ordem (sem dependência de execução).

## Casos explicitamente NÃO testados (e por quê)

| Caso | Por que não está nos vetores |
|---|---|
| `€` (U+20AC) em arquivo declarado `iso-8859-1` | Não é caractere ISO-8859-1; bytes inválidos. Parser do lxml aceita silenciosamente com semântica errada (vira U+0080). Não vira contrato; ver `AMBIGUITY_NOTES.md` §"Caracteres fora do encoding". |
| XML em UTF-16 / encoding alternativo | TISS exige ISO-8859-1. Comportamento entre parsers de linguagens diferentes diverge demais; vetor não seria universal. |
| XML malformado / tag não fechada | Espera-se erro do parser; não vira PASS-vetor. Cada port testa internamente que rejeita; não no manifest. |
| Entidades XML externas (`<!ENTITY foo SYSTEM ...>`) | Risco XXE; referência usa `resolve_entities=False`. Comportamento do parser por linguagem varia; fora do escopo. |
| Documento sem `<ans:hash>` | Caso ambíguo; manual pede que sempre exista. Não fixado; port pode aceitar ou rejeitar. |
| Múltiplos `<ans:hash>` no documento | Não previsto pelo padrão TISS; comportamento não-determinístico entre parsers; não fixado. |
| Atributos `xml:space="preserve"` / `xml:lang` | TISS não usa. Casos sintéticos seriam artificiais. |
| Documento > 5 MB | Vetor pesa demais no repo; perf testada com 455KB e os ports devem escalar O(n). |
| Assinatura digital XMLDSig do epílogo | Fora do escopo do hash; tem CONTRACT próprio. |

## Estratégia por nível de teste

| Nível | Cobertura | Frameworks sugeridos por linguagem |
|---|---|---|
| Unit | concat de folhas, encoding UTF-8, zeragem do hash | pytest / Catch2 / cargo test / vitest / phpunit |
| Conformance (este) | os 15 vetores deste manifest | linguagem-nativa lendo `vectors.json` |
| Property-based | invariante "hash(doc1+doc1) ≠ hash(doc1)" e "reordenar atributos não muda hash" | hypothesis / proptest / fast-check |
| Performance | baseline + tolerância no `syn_perf_grande.xml` | criterion / benchmark.js / pytest-benchmark |
| Integração | API real recebendo arquivo via HTTP/CLI | curl + jq / playwright |

## Risk-based prioritization

| Risco | Probabilidade | Impacto | Vetor primário |
|---|---|---|---|
| Port usa ISO-8859-1 nos bytes do MD5 | Alta (manual induz ao erro) | Crítico (hash errado) | `syn_acento.xml`, `syn_iso8859_simbolos.xml` |
| Port ignora atributos diferente | Baixa | Médio | `syn_atributo_folha.xml`, `syn_namespace_xsi.xml` |
| Port "normaliza" whitespace | Média | Crítico | `syn_crlf_value.xml`, `syn_whitespace_puro.xml` |
| Port resolve CDATA diferente | Média | Crítico | `syn_cdata.xml` |
| Port ignora comentário (intuitivamente correto, mas a referência NÃO ignora) | Alta | Crítico | `syn_comentario.xml` + `AMBIGUITY_NOTES.md` |
| Port falha em arquivo grande | Baixa | Alto | `syn_perf_grande.xml` |
| Port "limpa" zeros à esquerda | Baixa | Médio | `syn_leading_zero.xml` |

## Critérios de saída

- [ ] Os 15 vetores listados em `vectors.json` foram regerados pela referência.
- [ ] Os 3 goldens reais privados (fora do repo) continuam com hash inalterado no build privado.
- [ ] Cada port-target tem suite que lê `vectors.json` e bate 15/15.
- [ ] `AMBIGUITY_NOTES.md` revisado por cada implementador antes de codar.
- [ ] Performance do `syn_perf_grande.xml` documentada por linguagem.
- [ ] Sem teste flaky em 100 runs consecutivos (`for i in $(seq 100); do pytest ...; done`).

## Operação

**Regenerar o manifest** (depois de adicionar/editar sintéticos):

```bash
cd conformance
python3 build_fixture.py
```

Saída esperada (build público): `OK: 15 vetores (0 reais, 15 sinteticos)`, sem traceback. No build privado do mantenedor (`TISS_PRIVATE_XMLS` apontando para os XMLs reais), os 3 goldens reais devem bater via assert interno — mas continuam fora do `vectors.json` distribuído.

**Rodar a referência manualmente em um arquivo**:

```bash
python3 reference.py inputs/syn_acento.xml
```

**Adicionar novo vetor sintético** (workflow):

1. Editar `build_fixture.py`: adicionar tupla na lista `SINTETICOS` (ou `SINTETICOS_RAW` se bytes não-padrão).
2. Rodar `python3 build_fixture.py`.
3. Confirmar que `vectors.json` ganhou o novo entry e que reais continuam batendo.
4. Se o caso é ambíguo, registrar em `AMBIGUITY_NOTES.md`.
5. Commit: `test(conformance): adiciona vetor syn_<nome> cobrindo <caso>`.

**Adicionar novo golden real**:

1. Validar o hash manualmente fora da suite (autoridade do usuário).
2. Acrescentar o par `(arquivo, hash)` em `REAIS` em `build_fixture.py`.
3. Colocar o arquivo em `inputs/` (já que `legacy/` não está mais disponível).
4. Rodar `build_fixture.py` — o assert valida que a referência reproduz o golden.
