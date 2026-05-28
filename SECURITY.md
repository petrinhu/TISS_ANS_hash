# Política de Segurança

Obrigado por dedicar tempo a divulgar uma vulnerabilidade de forma responsável.

## Canal de reporte

**E-mail:** `petrinhu@yahoo.com.br`

**Assunto:** prefixar com `[TISS_ANS_hash][SEC]` para roteamento rápido.

**Não** abra issue pública no GitHub ou Codeberg para questões de segurança. Use o e-mail acima.

PGP / S/MIME: não disponível atualmente. Mensagens em texto claro são aceitáveis dado o escopo limitado da lib (sem operação online, sem dados em trânsito). Se você precisa de canal cifrado, mencione no primeiro contato e combinamos.

## Escopo aceito

Reportes válidos:

- **Hash incorreto** para algum input válido (port produz hash diferente do canônico em `conformance/vectors.json`).
- **Parser XML vulnerável**: XXE, billion-laughs, quadratic blowup, DTD externo aceito, expansão descontrolada de entidades, leitura de arquivo local via SYSTEM.
- **Defeito de empacotamento** que permite execução de código arbitrário ao instalar (ex.: post-install hook malicioso, dependência typosquatted).
- **CVE em dependência transitiva** que afeta o uso real da lib (não apenas teoria).
- **Vazamento acidental** de PII de paciente nos vetores de conformidade públicos (esperamos zero PII; reporte se encontrar).
- **Falha de validação** que pode causar denial-of-service no integrador (ex.: input que faz o parser travar/consumir memória ilimitada).

## Fora de escopo

Não são vulnerabilidades nesta lib:

- **Uso integrado**: como o integrador transmite, persiste ou loga o XML. Responsabilidade do integrador (ver [`docs/legal/LGPD-NOTE.md`](docs/legal/LGPD-NOTE.md)).
- **Infraestrutura do integrador**: SOAP endpoint da operadora exposto, credenciais vazadas em log do integrador, etc.
- **MD5 ser criptograficamente fraco**: vem do padrão TISS oficial, não da lib. A lib calcula o que o padrão exige. Para autenticidade e não-repúdio, o padrão usa XAdES (fora do escopo desta lib).
- **Manual TISS divergir da realidade**: o defeito está no manual oficial da ANS, não na lib. Lib documenta a divergência em [`docs/SPEC.md §4`](docs/SPEC.md#4-caveat-crítica-encoding-do-md5-é-utf-8-não-iso-8859-1).
- **Operadora rejeitar lote por motivo não-relacionado ao hash**: regras de negócio, XSD inválido, assinatura ausente, etc., não dependem desta lib.
- **Pedidos de feature, dúvidas de uso, bugs funcionais**: abrir issue pública normal (ver [`CONTRIBUTING.md`](CONTRIBUTING.md)).

## SLA orientativo

**Best-effort, sem garantia contratual** (a lib é MIT, sem garantias; ver [`LICENSE`](LICENSE)). O mantenedor é um indivíduo, não uma empresa com plantão.

Alvos práticos:

| Etapa                      | Prazo orientativo                       |
|----------------------------|-----------------------------------------|
| Acuso de recebimento       | 5 dias úteis                            |
| Triagem inicial            | 10 dias úteis                           |
| Patch ou mitigação         | depende da severidade; 30-90 dias       |
| Divulgação coordenada      | até **90 dias** após primeiro contato   |

Se em 90 dias não houver patch nem comunicação, você pode divulgar publicamente; pedimos apenas que indique no reporte público a tentativa de coordenação.

## Divulgação responsável

Pedimos que você:

1. **Não exponha publicamente** o detalhe da vulnerabilidade antes do patch (ou dos 90 dias).
2. **Não use** a vulnerabilidade para acessar dados de terceiros, derrubar serviços, etc.
3. **Forneça repro mínimo**: idealmente um XML sintético que dispara o problema (zero PII).
4. **Indique como prefere ser creditado** no advisory (nome, handle, anônimo, link).

Em troca:

- Crédito no advisory público (a menos que prefira anonimato).
- Comunicação transparente sobre cronograma e decisões.
- Quando aplicável, atribuição de CVE.

## Sem bug bounty

Não há programa de recompensa monetária. Projeto sem patrocinador. Crédito público é o que conseguimos oferecer.

## Boas práticas para integradores

Independente de vulnerabilidades nesta lib, recomendamos:

- **Atualizar** sempre que houver release de patch (`0.x.Y`).
- **Pinning de versão** com lockfile (`requirements.txt`, `Pipfile.lock`, `Cargo.lock`, etc.).
- **Auditar dependências transitivas** periodicamente (`pip-audit`, `cargo audit`, `npm audit`).
- **Não passar** XML não-confiável sem validação prévia de tamanho (defesa em profundidade contra DoS).
- **Isolar** o processo que executa parsing XML (containers, seccomp, AppArmor; aplica-se a qualquer parser).

## Histórico de advisories

Nenhum advisory publicado até o momento.

(Futuros advisories serão listados aqui, com link para o CVE quando aplicável.)
