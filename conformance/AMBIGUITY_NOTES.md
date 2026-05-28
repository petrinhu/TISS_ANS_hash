# Ambiguidades fixadas pela referência

Comportamentos do algoritmo de hash TISS/ANS que **NÃO** são óbvios pela leitura do manual nem pela descrição em prosa do algoritmo — mas que estão fixados pelo que `reference.py` produz. Cada port (C, C++, Rust, Python, PHP, Node.js, etc.) tem que reproduzir esses comportamentos byte-a-byte.

**Regra ouro:** o que a `reference.py` faz é o canônico. Se você acha que ela "deveria fazer diferente", tem dois caminhos:

1. Concordar com a referência atual e implementar igual no port.
2. Propor mudança ao usuário (que valida); se aprovado, atualizar referência + vetores + esta nota.

Não há terceira via "meu port faz diferente porque acho mais correto". Hash conformance é exato.

---

## 1. Encoding dos bytes do MD5 é UTF-8, NÃO ISO-8859-1

**Contraditório com:** manual TISS (Componente Organizacional nov/2025, pág 53, item 146) diz textualmente "O encoding a ser utilizado será sempre o ISO-8859-1".

**Realidade fixada:** o arquivo é lido como ISO-8859-1, mas a string concatenada é **re-encodada em UTF-8** antes do MD5.

**Evidência:** 3 goldens reais (`real_envio1/2/3.xml`) só batem com UTF-8 nos bytes; com ISO-8859-1 produzem hashes diferentes.

**Implicação para ports:**
- Letras ASCII puras não diferem entre UTF-8 e ISO-8859-1 (1 byte cada). Os 3 reais usam predominantemente ASCII; o teste discriminativo é o vetor com acento.
- Caracteres como `É` (U+00C9): em ISO-8859-1 = `0xC9` (1 byte); em UTF-8 = `0xC3 0x89` (2 bytes). MD5 sobre sequências de bytes diferentes = hash diferente.

**Vetor discriminador:** `syn_acento.xml`. Se um port produz hash diferente nesse vetor, está usando ISO-8859-1 nos bytes (erro clássico, induzido pelo manual).

---

## 2. Comentários XML `<!--...-->` ENTRAM no concat

**Intuição comum:** comentários são meta-dados; parsers de aplicação geralmente os ignoram; logo, o hash também deveria ignorar.

**Realidade fixada (`reference.py`):** a função usa `root.iter()` do lxml, que **inclui** nós `Comment`. O filtro `len(el) == 0` (sem filhos) é satisfeito por nós Comment, então o `.text` do comentário (o conteúdo entre `<!--` e `-->`) entra na string concatenada.

**Evidência:** rodar a referência em `syn_comentario.xml` mostra a leaf list:
```
leaf <cyfunction Comment ...>  ' COMENTARIO_QUE_ENTRA '
leaf {ans}campo                 'valor1'
leaf {ans}hash                  ''
```
Concat resultante: `'\n    \n     COMENTARIO_QUE_ENTRA \n    valor1\n  \n  \n    \n  \n'`

**Implicação para ports:**
- Bibliotecas que **filtram comentários por padrão** (caso comum em DOM de C++, .NET, etc.) produzirão hash **diferente** e errado.
- Para passar conformance, o port deve incluir comentários na iteração de folhas.
- O texto do comentário é o conteúdo **literal** entre `<!--` e `-->`, incluindo whitespace adjacente.

**Vetor discriminador:** `syn_comentario.xml`.

**Status:** esta é uma **ambiguidade não-intencional** da referência (subproduto de `lxml.iter()`). Pode ser revisada com o usuário. Por ora, é o canônico — e os ports devem reproduzir.

> **Recomendação operacional:** XMLs TISS reais raramente têm comentários (são gerados por sistema). O risco prático é baixo, mas o teste é mantido pra travar comportamento determinístico.

---

## 3. CDATA é tratado como texto normal

**Comportamento:** `<![CDATA[a < b & c]]>` é entregue pelo parser como a string literal `a < b & c` (sem os delimitadores `<![CDATA[` e `]]>`, sem decodificação de entidades — não há entidades dentro de CDATA).

**Vetor discriminador:** `syn_cdata.xml`.

**Implicação para ports:**
- Parsers DOM padrão fazem isso automaticamente. Não há ação especial.
- Cuidado com parsers que expõem CDATA como tipo de nó separado (alguns parsers de Java/C antigo): garanta que `.text` ou equivalente concatene o conteúdo.

---

## 4. Entidades XML predefinidas SÃO decodificadas antes do concat

**Comportamento:** o parser converte `&amp;` → `&`, `&lt;` → `<`, `&gt;` → `>`, `&quot;` → `"`, `&apos;` → `'` **antes** de entregar o `.text`. O concat usa o texto decodificado.

**Vetor discriminador:** `syn_entidades_xml.xml` (valor `a&amp;b&lt;c&gt;d&quot;e&apos;f` vira no concat `a&b<c>d"e'f`).

**Implicação para ports:**
- Comportamento padrão de qualquer parser XML compliant. Nada especial.
- Atenção a parsers configurados em modo "raw" ou "preserve entities" — devem ser desligados.

---

## 5. Atributos NÃO entram no concat

**Comportamento:** apenas o `.text` do elemento entra. Atributos (`attr="..."`) e nomes de tag são ignorados.

**Vetor discriminador:** `syn_atributo_folha.xml`.

**Implicação para ports:**
- Iterar **apenas** o text node do elemento, nunca os attribute nodes.
- Verificar manualmente em parsers que oferecem APIs como `node.toString()` (geralmente serializa tudo, inclusive atributos — não usar).

---

## 6. Prefixo de namespace é irrelevante

**Comportamento:** atributos como `xsi:type="xs:string"` são ignorados (cf. §5). O *prefixo* `ans:` é só ruído sintático: o parser entrega o elemento com namespace `http://www.ans.gov.br/padroes/tiss/schemas`; o concat só usa o `.text`, não o prefixo.

**Vetor discriminador:** `syn_namespace_xsi.xml`.

**Implicação para ports:**
- Não filtrar elementos por prefixo. Iterar todos e usar `.text` independente de namespace.
- `<ans:hash>` é localizado por XPath com namespace bem definido (`{http://www.ans.gov.br/padroes/tiss/schemas}hash`), não por prefixo literal.

---

## 7. Whitespace dentro do valor é preservado literalmente

**Comportamento:** o `.text` de uma folha entra **exatamente** como veio do parser, incluindo:
- Espaços iniciais/finais (`<x>   </x>` contribui 3 espaços).
- Tabs e CR/LF dentro do valor (`<x>linha1\r\nlinha2</x>` contribui exatamente esses 13 bytes em UTF-8).

**Importante:** o parser pode normalizar CR/LF em line endings (XML 1.0 §2.11: `\r\n` e `\r` viram `\n` no info set entregue à aplicação). A referência **confia no parser** — não faz normalização adicional, mas também não a desabilita.

**Vetores discriminadores:**
- `syn_whitespace_puro.xml` — preservação de espaços puros.
- `syn_crlf_value.xml` — CR/LF dentro de valor (vira `\n` após normalização XML 1.0).

**Implicação para ports:**
- NÃO chamar `.trim()` / `strip()` / `String.normalize()` no `.text`.
- Confiar na normalização padrão do parser (que segue XML 1.0).

---

## 8. Indentação entre tags NÃO entra (porque não é folha)

**Comportamento:** em XML formatado tipo
```xml
<ans:cabecalho>
  <ans:campo>X</ans:campo>
</ans:cabecalho>
```

o `<ans:cabecalho>` tem `.text == "\n  "` e `.tail == "\n"`, mas como tem filho, **não é folha** e é pulado pelo filtro `len(el) == 0`. Logo, a indentação não entra. Só o `.text` do `<ans:campo>` entra (`"X"`).

**Por que importa:** se o port iterar **todos** os elementos (não só folhas), ou usar `etree.tostring(method='text')` ingênuamente, vai capturar a indentação e produzir hash errado.

**Implicação para ports:**
- Implementar o filtro de folha corretamente. Em C/C++ DOM: `firstChild == null` ou `childCount == 0`. Em Rust `roxmltree`: `!node.has_children()`. Em Python `xml.etree`: `len(elem) == 0`.

---

## 9. Múltiplos `<ans:hash>` no documento: comportamento NÃO fixado

**Comportamento atual da referência:** `root.find(".//ans:hash", NS)` retorna apenas o **primeiro** match. Se houver outros, eles **não** são zerados e seu conteúdo entra no concat normalmente.

**Status:** caso patológico. O padrão TISS só prevê um `<ans:hash>` (no `<ans:epilogo>`). **NÃO há vetor de teste** pra esse cenário; comportamento é considerado não-fixado.

**Recomendação para ports:** seguir a referência (zerar só o primeiro). Documentar.

---

## 10. Caracteres fora do encoding declarado: comportamento NÃO defensivo

**Cenário observado:** arquivo declarado `encoding='iso-8859-1'` contendo bytes que representariam `€` em CP1252 (byte `0x80`).

**Comportamento do lxml:** aceita silenciosamente, devolve U+0080 (caractere de controle "Padding Character") como conteúdo. Sem erro, sem warning.

**Status:** **NÃO** virou vetor de teste, intencionalmente:
- O comportamento é específico de lxml/libxml2 e provavelmente diferente em outros parsers (alguns rejeitariam, alguns substituiriam por `?`).
- Padrão TISS proíbe esses bytes; é input inválido.
- Fixar um vetor para comportamento de input inválido cria contrato inútil e quebradiço.

**Recomendação para ports:** documentar o comportamento do parser usado quando recebe bytes inválidos. Idealmente, **rejeitar** (mais defensivo que a referência Python). Mas se aceitar, alinhar com a referência **não é exigido** pela suite — input fora de spec não tem hash canônico.

**Vetor afim incluso (mas válido):** `syn_iso8859_simbolos.xml` — usa `° § ½ µ`, todos **válidos** em ISO-8859-1. Esse SIM tem hash fixado.

---

## 11. BOM UTF-8 no início do arquivo: aceito pela referência

**Comportamento:** arquivo começando com bytes `EF BB BF` (BOM UTF-8) e declaração `encoding='utf-8'` é aceito normalmente pelo parser. O BOM não entra no concat (parser o trata como marcador, não conteúdo).

**Vetor discriminador:** `syn_bom_utf8.xml`.

**Status:** TISS proíbe BOM (`ISO-8859-1` é o encoding obrigatório, e ISO-8859-1 não tem BOM). Mas, defensivamente, decidimos fixar comportamento da referência caso algum sistema upstream envie BOM por engano.

**Implicação para ports:**
- Se o parser do port aceitar BOM (caso comum em Java, .NET, Node.js) e produzir o mesmo hash, ok.
- Se rejeitar, é aceitável documentar e marcar este vetor como "skip por design" — mas o ideal é reproduzir.

---

## 12. Valores numéricos com zeros à esquerda são preservados como string

**Comportamento:** `<numero>00123</numero>` contribui literalmente `00123` ao concat, NÃO `123`.

**Por que importa:** um port escrito por dev acostumado com tipagem forte poderia tentar "limpar" zeros à esquerda. Não faça.

**Vetor discriminador:** `syn_leading_zero.xml`.

---

## 13. Elementos vazios: `<x></x>` e `<x/>` são equivalentes e contribuem `""`

**Comportamento:** ambas formas produzem `.text = None` ou `""`. A referência usa `(el.text or "")`, garantindo string vazia. Concat inalterado (vazio + algo == algo).

**Vetor discriminador:** `syn_empty.xml` (mistura `<campoA></campoA>` + `<campoB/>` + `<campoC>valorC</campoC>`).

**Implicação para ports:**
- Tratar `null`/`None`/`undefined` de `.text` como string vazia, sem skip do elemento.
- Garantir que `<x/>` é detectado como folha (sem filhos, sem conteúdo).

---

## 14. Ordem do concat é ordem de documento

**Comportamento:** elementos são iterados em ordem de aparição no documento. Re-ordenar elementos no XML muda o hash.

**Vetor discriminador:** `syn_multi_guia.xml` (duas guias em ordem específica; trocar a ordem produziria hash diferente).

**Implicação para ports:**
- Usar iteração in-order da DOM (depth-first, primeira aparição).
- NÃO ordenar por nome de tag, atributo, ou qualquer critério.

---

## 15. `<ans:hash>` é zerado mesmo se contiver hash prévio

**Comportamento:** o conteúdo de `<ans:hash>` é substituído por string vazia **antes** do concat. Isso permite re-calcular o hash de um documento já assinado sem precisar editar o XML antes.

**Evidência:** vários vetores sintéticos (`syn_minimal.xml`, `syn_multi_guia.xml`) gravam `LIXO_DEVE_SER_IGNORADO` ou `LIXO_IGNORADO` dentro do `<ans:hash>` propositalmente, pra provar que o passo de zeragem funciona.

**Implicação para ports:**
- Garantir que o `<ans:hash>` é localizado e zerado independente do conteúdo prévio.
- NÃO confiar que o `<ans:hash>` está vazio na entrada.

---

## Tabela-resumo (cheat sheet para implementadores)

| # | Decisão | Vetor que prova |
|---|---|---|
| 1 | MD5 sobre bytes UTF-8 (não ISO-8859-1) | `syn_acento.xml`, todos reais |
| 2 | Comentários XML ENTRAM no concat | `syn_comentario.xml` |
| 3 | CDATA tratado como texto literal | `syn_cdata.xml` |
| 4 | Entidades XML decodificadas antes | `syn_entidades_xml.xml` |
| 5 | Atributos NÃO entram | `syn_atributo_folha.xml` |
| 6 | Prefixo de namespace irrelevante | `syn_namespace_xsi.xml` |
| 7 | Whitespace em valor preservado | `syn_whitespace_puro.xml`, `syn_crlf_value.xml` |
| 8 | Indentação entre tags (não-folha) ignorada | implícito em todos formatados |
| 9 | Múltiplos `<ans:hash>`: comportamento NÃO fixado | — |
| 10 | Bytes inválidos no encoding: NÃO fixado | — |
| 11 | BOM UTF-8 aceito | `syn_bom_utf8.xml` |
| 12 | Leading zeros preservados | `syn_leading_zero.xml` |
| 13 | `<x></x>` e `<x/>` equivalentes (string vazia) | `syn_empty.xml` |
| 14 | Ordem do concat = ordem de documento | `syn_multi_guia.xml` |
| 15 | `<ans:hash>` zerado mesmo se tiver conteúdo | `syn_minimal.xml`, `syn_multi_guia.xml`, `syn_perf_grande.xml` |
