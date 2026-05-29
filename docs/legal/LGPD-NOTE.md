---
title: Aviso LGPD para integradores
type: explanation
audience: integradores (controladores e operadores de dados pessoais), DPO, jurídico
version: 1.0.0
last-reviewed: 2026-05-27
owner: petrinhu@yahoo.com.br
status: orientação técnica (não é parecer jurídico)
---

# Aviso LGPD para integradores do `lib_hash_ans`

> **Disclaimer.** Este documento é **orientação técnica**, não parecer jurídico. Sempre consulte advogado/DPO sobre obrigações concretas da sua organização. Referências de norma (LGPD, ANPD) estão no fim do documento.

## 1. Posição da lib na cadeia de tratamento

A biblioteca `lib_hash_ans` (e seus ports: `tiss-hash` em Python, e demais previstos) é uma **ferramenta-meio**:

- Recebe **bytes** de XML TISS em memória.
- Calcula um hash MD5 (32 chars hex).
- Devolve a string.
- Não persiste o XML.
- Não transmite o XML.
- Não registra log do conteúdo.
- Não anonimiza, não tokeniza, não rotula.

Tecnicamente, a lib é equivalente a uma função matemática pura sobre os bytes recebidos. **Não é controladora nem operadora** de dados pessoais sob a LGPD: ela é uma dependência de software, análoga a `hashlib`, `lxml`, `openssl` ou qualquer outra biblioteca de utilidade.

A responsabilidade LGPD recai inteiramente sobre o **integrador** que adota a lib em seu sistema (clínica, hospital, fornecedor TISS, operadora de saúde, etc.).

## 2. Por que isso importa para você (integrador)

XMLs TISS contêm **dados pessoais sensíveis de saúde** (LGPD, art. 5º, II), incluindo tipicamente:

- Nome completo e CPF do beneficiário.
- Número de carteirinha, plano e operadora.
- Data de nascimento, sexo, endereço.
- Diagnósticos (CID-10), procedimentos (TUSS/CBHPM), códigos de medicamentos.
- Datas de atendimento, prestador executante.
- Em alguns casos, dados de menores (proteção reforçada art. 14).

Ao usar esta lib dentro do seu pipeline, **você** está realizando tratamento de dados pessoais. As obrigações descritas abaixo aplicam-se ao seu sistema, independente de a lib ser MIT, gratuita ou de terceiros.

## 3. Recomendações mínimas para o integrador

### 3.1 Base legal (art. 7º e 11)

Identifique e documente a base legal para o tratamento. Para saúde suplementar, normalmente:

- **Art. 7º, II + art. 11, II, "f":** cumprimento de obrigação legal/regulatória (transmissão TISS exigida por norma da ANS).
- **Art. 7º, V + art. 11, II, "f":** execução de contrato com o beneficiário (atendimento contratado).
- **Art. 11, II, "a":** consentimento, apenas em casos onde nenhuma das hipóteses acima se aplica (raro em fluxo TISS padrão).

Confunda os artigos por sua conta e risco. **Consulte DPO ou advogado especializado.**

### 3.2 Encarregado pelo Tratamento (DPO, art. 41)

Toda organização que trate dados pessoais deve indicar **Encarregado**. Para operações de pequeno porte, a ANPD admite simplificações (Resolução CD/ANPD nº 2/2022), mas a obrigação de canal de comunicação com titulares permanece.

### 3.3 Registro de Operações de Tratamento de Dados, RTOA (art. 37)

Documente:

- Categorias de dados tratados.
- Finalidades.
- Base legal.
- Compartilhamentos (operadora, ANS, terceirizados).
- Período de retenção.
- Medidas de segurança aplicadas.

### 3.4 Relatório de Impacto à Proteção de Dados Pessoais, RIPD (art. 38)

Recomendável (e em alguns casos exigível) para fluxos que tratem dados sensíveis em larga escala. ANPD pode requisitar. Modelo de referência: ANPD, Guia Orientativo "Como elaborar Relatório de Impacto à Proteção de Dados Pessoais", v2.0 (2023).

### 3.5 Contratos com operadores (art. 39)

Se você usa serviços de terceiros (cloud, ERP, SaaS de faturamento, etc.) que tocam o XML TISS, formalize **contrato de operador** com cláusulas LGPD: finalidade restrita, medidas de segurança, sub-operadores, devolução/eliminação ao término, auditoria.

A própria lib `tiss-hash` **não é** um operador no sentido do art. 39: é dependência de software. Mas o **provedor de cloud** onde seu sistema roda, sim.

### 3.6 Retenção e eliminação (art. 15-16)

Defina prazo de retenção do XML alinhado à:

- Norma TISS aplicável (auditoria ANS).
- Norma fiscal/contábil.
- Necessidade clínica.

Ao término, elimine de forma irreversível (não basta `rm` em disco compartilhado). Para mídias físicas, considere padrões DoD 5220.22-M ou NIST SP 800-88.

### 3.7 Direitos do titular (art. 18)

Tenha canal e processo para atender:

- Confirmação de tratamento.
- Acesso aos dados.
- Correção.
- Anonimização, bloqueio, eliminação (quando aplicável).
- Portabilidade.
- Eliminação dos tratados com consentimento.
- Revogação de consentimento.

Lembre-se: dados de saúde tratados com base em obrigação legal (TISS) **não** podem ser eliminados a pedido do titular durante o período de retenção legal.

### 3.8 Segurança (art. 46-49)

Aplicar medidas técnicas e administrativas adequadas. Para o pipeline TISS, mínimo razoável:

- Trânsito do XML sobre TLS 1.2+ (SOAP/HTTPS).
- Cifragem em repouso para storage que retém XML.
- Controle de acesso por identidade (RBAC, MFA).
- Log de acesso (sem cópia do payload).
- Hardening de host (atualizações, antivírus, firewall).
- Segregação de ambientes (dev/staging/prod).
- Não logar conteúdo de XML em sistemas de observabilidade (Sentry, Datadog, ELK, etc.).
- Limpar buffers em memória após uso (best-effort; depende da linguagem).

A lib `tiss-hash` já adota parser endurecido contra **XXE** e **billion-laughs** (via `defusedxml`), o que é uma medida de segurança em parsing, não em proteção de dados pessoais especificamente.

### 3.9 Incidentes (art. 48)

Tenha plano de resposta a incidente. Em caso de vazamento de dado pessoal:

- Comunicar ANPD em prazo razoável (atualmente sem prazo numérico fixo; ANPD trabalha com "prazo razoável" desde a Resolução CD/ANPD nº 15/2024 e orientações subsequentes).
- Comunicar titulares afetados.
- Mitigar e documentar.

## 4. Boas práticas técnicas adicionais

- **Não logue o XML** em sistema centralizado de log. Logue apenas: timestamp, identificador anonimizado do lote, hash calculado, código de erro.
- **Não persista** o XML fora do tempo estritamente necessário ao processamento e à auditoria.
- **Considere execução client-side** (browser via WASM, quando disponível) para casos em que o cálculo possa ser feito sem trânsito do dado ao servidor (argumento de minimização, art. 6º, III).
- **Restrinja acesso ao processo** que executa parsing: container isolado, seccomp/AppArmor, usuário não-privilegiado.
- **Audite dependências** periodicamente (`pip-audit`, `cargo audit`, equivalentes).
- **Treine o time** sobre o que pode/não pode ser registrado em ticket, chat, e-mail.

## 5. O que esta lib NÃO faz (e portanto não é cobrança ANPD contra nós)

- Não envia telemetria.
- Não chama serviços remotos.
- Não armazena cache em disco.
- Não escreve em variável de ambiente.
- Não cria arquivo temporário com conteúdo do XML.

O comportamento é determinístico, in-process, sem efeito colateral observável além do retorno da função.

## 6. Para o seu DPO

Se seu DPO precisa de informações sobre esta lib para incluir no RTOA ou RIPD:

- **Natureza:** biblioteca open source, MIT.
- **Função:** cálculo de hash MD5 sobre XML in-memory.
- **Sub-processadores:** nenhum (sem chamada de rede).
- **Vendedor:** mantenedor individual, sem CNPJ vinculado ao projeto.
- **Localização do processamento:** mesmo processo do aplicativo cliente; nenhum dado sai do processo.
- **Retenção pela lib:** zero. A função retorna a string e libera referências; gerenciamento de memória cabe ao runtime do integrador.
- **Auditoria:** código-fonte público em [GitHub](https://github.com/petrinhu/TISS_ANS_hash) e [Codeberg](https://codeberg.org/petrinhu/TISS_ANS_hash).

## 7. Referências

- **LGPD**, Lei nº 13.709/2018 (texto consolidado em [`https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm`](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm)).
- **ANPD**, Guia Orientativo "Tratamento de Dados Pessoais pelo Poder Público", v2.0, 2023.
- **ANPD**, Guia Orientativo "Como elaborar Relatório de Impacto à Proteção de Dados Pessoais (RIPD)", v2.0, 2023.
- **ANPD**, Resolução CD/ANPD nº 2/2022 (regulamenta o regime de tratamento por agentes de pequeno porte).
- **ANPD**, Resolução CD/ANPD nº 15/2024 (comunicação de incidentes de segurança).
- **ANS**, Padrão TISS (Componente Organizacional vigente). A lib é agnóstica à versão do Padrão TISS — o algoritmo de hash é estável entre versões.

## 8. Licenciamento desta lib

A lib `lib_hash_ans` (e seus ports) é distribuída sob licença **MIT** (ver [`LICENSE`](../../LICENSE)). Isso significa, em linguagem comum:

- Uso livre, comercial e não-comercial.
- Modificação livre.
- Redistribuição livre, com manutenção do aviso de copyright e da licença.
- **Sem garantias.** O software é fornecido "como está" ("AS IS"); o autor não responde por danos decorrentes do uso. Ver também [`DISCLAIMER.md`](DISCLAIMER.md).

A licença MIT **não** isenta o integrador de suas obrigações LGPD. Ao contrário: por ser MIT e o software ser amplamente reutilizável, é o integrador que decide o contexto de uso e responde por ele.
