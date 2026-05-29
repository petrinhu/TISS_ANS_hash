---
title: Escopo de conformidade com o padrão TISS
type: explanation
audience: integradores, auditores, jurídico
version: 1.0.0
last-reviewed: 2026-05-27
owner: petrinhu@yahoo.com.br
status: orientação técnica (não é parecer regulatório)
---

# Escopo de conformidade com o padrão TISS

> Este documento descreve **o que a lib `lib_hash_ans` cobre** e **o que NÃO cobre** dentro do Padrão TISS (Troca de Informações na Saúde Suplementar) da ANS. Não substitui parecer regulatório.

## 1. Padrão TISS, em uma frase

O **Padrão TISS** é o conjunto de regras editado pela **Agência Nacional de Saúde Suplementar (ANS)** que define como operadoras de planos de saúde e prestadores de serviço (médicos, clínicas, hospitais, laboratórios) trocam informações administrativas (autorização, faturamento, recurso de glosa, etc.) de forma estruturada e auditável.

A troca acontece via mensagens XML que seguem schemas XSD oficiais publicados pela ANS, transmitidas via Web Services SOAP, com assinatura digital XAdES e mecanismos de controle de integridade.

## 2. Escopo em relação às versões do padrão

Esta lib implementa o **algoritmo de hash do epílogo do Padrão TISS de forma agnóstica à versão**: ela calcula o conteúdo de `<ans:hash>` segundo o algoritmo documentado na SPEC, que é **estável entre as versões publicadas do padrão**. A lib **não declara conformidade com uma versão específica** do Padrão TISS, justamente porque a ANS revisa o padrão periodicamente e fixar um número de versão induziria afirmação enganosa.

- **Componente de Representação:** Padrão TISS (versão-agnóstica; ver nota acima).
- **Componente de Comunicação:** SOAP 1.1 sobre HTTPS.
- **Componente de Segurança e Privacidade:** assinatura XAdES; hash MD5 do epílogo.

Caso uma futura revisão do Padrão TISS altere o algoritmo de hash em si (o que a SPEC monitora), a mudança incompatível dispara nova major version (ver [`CHANGELOG.md`](../../CHANGELOG.md) e SemVer da SPEC).

## 3. O que a lib cobre

A lib cobre **uma única operação** dentro do padrão TISS:

> Cálculo do conteúdo do elemento `<ans:hash>` dentro de `<ans:epilogo>` em mensagens TISS, conforme algoritmo MD5 documentado na SPEC.

Isso significa:

| Item                                                  | Coberto pela lib?                  |
|-------------------------------------------------------|------------------------------------|
| Calcular `<ans:hash>` de uma mensagem TISS            | **Sim** (escopo único da lib)      |
| Validar o hash de uma mensagem recebida               | **Sim** (recalcula e compara)      |
| Inserir o hash calculado dentro do `<ans:hash>`       | **Não** (responsabilidade do integrador) |
| Validar XML contra XSD oficial TISS                   | **Não**                            |
| Assinar a mensagem com XAdES                          | **Não**                            |
| Validar assinatura XAdES recebida                     | **Não**                            |
| Construir a mensagem TISS (cabeçalho, lote, guias)    | **Não**                            |
| Transmitir via SOAP                                   | **Não**                            |
| Autenticar contra a operadora (certificado A1/A3)     | **Não**                            |
| Implementar tabelas de domínio (TUSS, CID, CBHPM)     | **Não**                            |
| Tratar protocolos de retorno (resposta, glosa)        | **Não**                            |
| Persistir lotes ou guias                              | **Não**                            |

A lib é **uma peça** no pipeline TISS. As demais peças são responsabilidade do integrador (próprias ou de terceiros).

## 4. Por que apenas o hash

Porque o algoritmo de hash é a **única parte** do padrão TISS que historicamente foi mal documentada e exigiu engenharia reversa para descobrir o comportamento real (encoding UTF-8 vs ISO-8859-1; ver [`docs/SPEC.md §4`](../SPEC.md#4-caveat-crítica-encoding-do-md5-é-utf-8-não-iso-8859-1)).

As demais partes (XSD, SOAP, XAdES, etc.) estão razoavelmente bem cobertas por:

- Schemas XSD oficiais publicados pela ANS.
- Bibliotecas SOAP nativas em cada linguagem.
- Bibliotecas de assinatura XAdES (várias open source: `xmlsec`, `signxml`, `eSig`, etc.).
- Documentação operacional pública da ANS.

Reimplementar essas partes seria reinventar a roda. A lib `lib_hash_ans` resolve **apenas o que está mal resolvido em outras libs**: o hash.

## 5. Limites de validação

A lib **não verifica** se o XML recebido é uma mensagem TISS estruturalmente válida. Ela:

- Parseia o XML (sintaxe XML correta).
- Identifica `<ans:hash>` por namespace `http://www.ans.gov.br/padroes/tiss/schemas`.
- Concatena texto de folhas em ordem documental.
- Calcula MD5.

Se você passar um XML qualquer (mesmo não-TISS), a lib calcula um hash sobre ele. O hash será determinístico para aquele input, mas não terá significado no contexto TISS.

**A validação contra XSD oficial TISS é responsabilidade do integrador.** Use `xmllint --schema`, `lxml.etree.XMLSchema`, equivalente da sua linguagem.

## 6. Conformidade da implementação

A lib é validada de duas formas:

### 6.1 Vetores sintéticos públicos (20 vetores: 18 positivos + 2 negativos)

Em [`conformance/vectors.json`](../../conformance/vectors.json), XMLs sintéticos cobrindo casos de borda. **18 positivos** (comparam hash):

- Mínimo (cabeçalho + epílogo).
- Acentuação (discriminador de encoding).
- Campos vazios.
- CR/LF dentro de valor.
- Múltiplas guias.
- Entidades XML predefinidas.
- Entidades de caractere numéricas.
- Seções CDATA.
- Comentários.
- Atributos em folha.
- Namespaces alternativos (`xsi:type`).
- Namespace TISS default (sem prefixo).
- Documento sem `<ans:hash>` (válido).
- Whitespace puro.
- Zeros à esquerda.
- Símbolos ISO-8859-1.
- Documento grande (performance).
- BOM UTF-8.

E **2 negativos** (entrada que o port deve rejeitar): múltiplos `<ans:hash>` e encoding UTF-16.

Detalhes em [`conformance/TEST_PLAN.md`](../../conformance/TEST_PLAN.md) e ambiguidades fixadas em [`conformance/AMBIGUITY_NOTES.md`](../../conformance/AMBIGUITY_NOTES.md).

### 6.2 Goldens reais (privados)

Durante a engenharia reversa, 3 XMLs reais com hashes confirmados pela ANS serviram como ground truth. Esses arquivos **não estão no repositório público** por conterem PII de pacientes (LGPD, art. 5º, II). Permanecem em diretório privado do mantenedor.

Validação contra esses goldens roda apenas em ambiente local do mantenedor antes de cada release. O conjunto sintético público é suficiente para qualquer port reproduzir o algoritmo byte-a-byte sem acesso aos privados.

## 7. Não é "homologação ANS"

A ANS **não homologa** bibliotecas de terceiros. O processo de homologação aplica-se a **operadoras** (que se certificam junto à ANS para uso do padrão TISS). Esta lib é insumo técnico que pode ser usado por operadoras ou prestadores em seus próprios sistemas.

Conformidade declarada pela lib significa: **o algoritmo de hash bate byte-a-byte com o resultado aceito pela ANS** no escopo dos vetores documentados. Não há selo, marca ou autorização formal da ANS sobre este projeto.

## 8. Conformidade ao longo do tempo

Mudanças no padrão TISS são publicadas pela ANS em notas técnicas, atualizações de Componente de Representação e nas tabelas de domínio. A lib monitora apenas o que afeta o **algoritmo de hash**: estrutura do epílogo, namespace `ans:`, encoding declarado.

Mudanças nas tabelas de domínio (TUSS, CBHPM, CID), em códigos de glosa, em protocolos de retorno, etc., **não afetam** a lib. Essas tabelas são problema do integrador.

Se a ANS publicar mudança no algoritmo de hash, a lib responde com:

1. Issue rastreando a mudança (label `spec`).
2. Atualização da SPEC, dos vetores, e dos ports.
3. Release com nova major version (breaking change).
4. Migration guide no `CHANGELOG.md`.

## 9. Referências

- **ANS**, Padrão TISS, página oficial: [`https://www.gov.br/ans/pt-br/assuntos/prestadores/padrao-para-troca-de-informacao-de-saude-suplementar-tiss`](https://www.gov.br/ans/pt-br/assuntos/prestadores/padrao-para-troca-de-informacao-de-saude-suplementar-tiss).
- **ANS**, Componente de Representação do Padrão TISS (XSDs oficiais publicados pela agência).
- **ANS**, Componente Organizacional TISS (versão vigente em novembro/2025).
- **ANS**, Manual de Conteúdo e Estrutura Padrão TISS.

## 10. Disclaimer

Este documento descreve o **escopo técnico** da lib e sua relação com o padrão TISS. **Não é parecer regulatório.** O integrador é responsável por verificar requisitos vigentes da ANS aplicáveis ao seu caso de uso e contratualizar serviços que cubram as etapas fora do escopo desta lib. Consulte profissional habilitado em regulação de saúde suplementar para análise jurídica.

Ver também: [`LGPD-NOTE.md`](LGPD-NOTE.md), [`DISCLAIMER.md`](DISCLAIMER.md).
