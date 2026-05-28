---
title: Disclaimer técnico e legal
type: explanation
audience: integradores, usuários da lib, jurídico
version: 1.0.0
last-reviewed: 2026-05-27
owner: petrinhu@yahoo.com.br
status: orientação técnica (não é parecer jurídico)
---

# Disclaimer técnico e legal

> Este documento esclarece **limites de uso** e **limites de responsabilidade** da biblioteca `lib_hash_ans` (e ports `tiss-hash`, etc.). Não substitui parecer jurídico nem regulatório.

## 1. Esta lib NÃO é dispositivo médico

A biblioteca `lib_hash_ans` é um utilitário de **infraestrutura administrativa** (cálculo de hash de mensagens de troca regulatória entre operadoras e prestadores). Ela **não**:

- Auxilia decisão clínica.
- Diagnostica condição.
- Prescreve tratamento.
- Monitora sinais vitais.
- Controla equipamento médico.
- Processa imagem médica.

Portanto, **não está enquadrada** como software como dispositivo médico (SaMD) sob:

- **Brasil:** RDC ANVISA nº 751/2022 e atos correlatos (atualmente vigentes), nem RDC nº 657/2022 (que tratam de software médico).
- **União Europeia:** Regulamento (UE) 2017/745 (MDR), nem Regulamento (UE) 2017/746 (IVDR).
- **EUA:** FDA 21 CFR Part 820 (QSR) ou 21 CFR Part 11.

Caso o integrador insira a lib dentro de um produto que se enquadre como dispositivo médico, a responsabilidade regulatória é do integrador, não da lib.

## 2. Software fornecido AS IS

A lib é distribuída sob **licença MIT** (ver [`LICENSE`](../../LICENSE)), que estabelece:

> "THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE."

Tradução prática:

- **Sem garantia** de adequação a propósito específico.
- **Sem garantia** de comerciabilidade.
- **Sem garantia** de não-violação de patentes/direitos.
- **Sem responsabilidade** dos autores por dano direto, indireto, incidental ou consequente decorrente do uso (ou da impossibilidade de uso) da lib.

O integrador adota a lib por sua conta e risco, após avaliação técnica e legal própria.

## 3. Caveat de encoding: UTF-8 vs ISO-8859-1

O algoritmo de hash MD5 do epílogo TISS, conforme **prática real validada contra hashes confirmados pela ANS**, usa **UTF-8** nos bytes alimentados ao MD5. Isso **contradiz a prosa** do manual TISS (Componente Organizacional, nov/2025, p. 53, item 146), que diz textualmente "O encoding a ser utilizado será sempre o ISO-8859-1".

Esta lib implementa o comportamento **real** (UTF-8), não o documental (ISO-8859-1), por ser o que a ANS aceita na prática. Caso a ANS, em algum momento futuro:

- Corrija a documentação para refletir UTF-8: a lib continua correta.
- Mude o algoritmo real para usar ISO-8859-1: a lib precisará de nova versão major (2.0) com migração documentada.
- Mude para outro algoritmo (SHA-256, etc.): idem.

Detalhes técnicos em [`docs/SPEC.md §4`](../SPEC.md#4-caveat-crítica-encoding-do-md5-é-utf-8-não-iso-8859-1) e [`conformance/AMBIGUITY_NOTES.md §1`](../../conformance/AMBIGUITY_NOTES.md).

O autor **não responde** por rejeição de lote pela operadora ou pela ANS decorrente de:

- Alteração de algoritmo pela ANS sem revisão da lib.
- Bug do parser XML do integrador que altera o conteúdo antes do hash.
- Erro do integrador na montagem do XML (faltam campos, ordem errada).
- Falha de assinatura digital (XAdES) que é etapa separada do hash.
- Falha de transmissão, autenticação, ou política da operadora.

## 4. MD5 não é primitiva criptográfica forte

MD5 está há anos classificado como **criptograficamente quebrado** para uso em assinatura, autenticação ou prova de integridade contra adversário ativo (colisões de prefixo conhecido desde Wang et al., 2004; ataques práticos demonstrados em CAs reais em 2008).

Esta lib usa MD5 **porque o padrão TISS exige**. Aqui o MD5 funciona como **checksum** de detecção de corrupção acidental e de integridade declarativa, não como primitiva de segurança. Para autenticidade, não-repúdio e integridade contra adversário, o próprio padrão TISS usa **assinatura digital XAdES** (fora do escopo desta lib).

O autor **não recomenda** usar MD5 fora do contexto TISS para finalidades de segurança.

## 5. Limites de responsabilidade

O autor da lib `lib_hash_ans` (e dos ports oficiais publicados sob sua autoria) **não se responsabiliza por**:

- **Rejeição** de lote pela operadora ou ANS por qualquer motivo (regra de negócio, XSD inválido, assinatura, faturamento, prazo, etc.).
- **Atraso** ou **interrupção** de processamento causados pela lib.
- **Perda de dados** do integrador.
- **Vazamento** de dados do integrador (a lib não persiste nem transmite; ver [`LGPD-NOTE.md`](LGPD-NOTE.md)).
- **Multas, sanções ou penalidades** aplicadas pela ANS, pela ANPD ou por qualquer autoridade ao integrador.
- **Mudança de padrão TISS** que torne a lib obsoleta.
- **Bug em dependência** (`defusedxml`, `lxml`, etc.) que afete a operação.
- **Interpretação divergente** de requisito TISS por operadora específica.

Em qualquer hipótese, o limite de responsabilidade do autor é o estabelecido na licença MIT: **zero**.

## 6. O que o integrador deve fazer antes de produção

Recomendações mínimas (não exaustivas):

1. **Validar contra lotes reais** seus, que já foram aceitos pela operadora-alvo, antes de subir para produção.
2. **Manter pipeline de teste** que reexecute a fixture de conformidade a cada atualização da lib.
3. **Monitorar** a taxa de rejeição de lotes em produção. Anomalia pode indicar problema na lib, no XML gerado, ou mudança na operadora.
4. **Cobrir o caminho de rollback**: poder voltar para versão anterior da lib em caso de regressão.
5. **Adotar pinning** de versão da lib em lockfile (`requirements.txt`, `Cargo.lock`, etc.).
6. **Ler [`CHANGELOG.md`](../../CHANGELOG.md)** antes de atualizar.
7. **Reportar** discrepâncias por canal apropriado (issue pública para bug funcional; e-mail `[SEC]` para vulnerabilidade; ver [`SECURITY.md`](../../SECURITY.md)).

## 7. Idioma e jurisdição

Documentação primária da lib está em **português brasileiro**, refletindo o domínio (saúde suplementar brasileira) e o público-alvo. Em caso de divergência entre versões traduzidas e a original em pt-BR, prevalece o texto original em pt-BR.

A licença MIT (texto original em inglês) prevalece em sua redação canônica para fins legais; traduções têm caráter informativo.

## 8. Atualização deste documento

Este documento será revisado em qualquer das seguintes situações:

- Mudança da licença da lib.
- Mudança regulatória relevante (RDC ANVISA, ANPD, ANS) que afete o enquadramento.
- Mudança no algoritmo TISS.
- Identificação de risco ou limitação não coberta aqui.

Versão atual: vide frontmatter (`version`, `last-reviewed`). Histórico em [`CHANGELOG.md`](../../CHANGELOG.md).
