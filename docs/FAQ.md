---
title: FAQ, glossário e troubleshooting do lib_hash_ans
type: explanation
audience: iniciante (estudante de computação, integrador novo no TISS)
version: 0.1.0
last-reviewed: 2026-05-29
owner: petrinhu@yahoo.com.br
status: estável (9 ports prontos: Python, Rust, C, C++, Node.js, PHP, Java, Go, C#)
---

# FAQ, glossário e troubleshooting

Esta página é para quem está começando. Ela explica os termos do projeto em linguagem simples, responde as dúvidas mais comuns e ajuda a resolver os erros mais frequentes.

Se você ainda não sabe o que esta biblioteca faz, comece pela [visão geral no README](../README.md) ou pela explicação dos conceitos em [`CONCEITOS.md`](CONCEITOS.md). Para aprender na prática, passo a passo, veja o [`TUTORIAL.md`](TUTORIAL.md). Para usar no dia a dia, veja o [`USAGE.md`](USAGE.md). Para o detalhe técnico do algoritmo, veja o [`SPEC.md`](SPEC.md).

Esta página tem três partes:

1. [Glossário](#1-glossário): o que cada palavra significa.
2. [Perguntas frequentes (FAQ)](#2-perguntas-frequentes-faq): dúvidas comuns.
3. [Troubleshooting](#3-troubleshooting): quando algo dá errado.

---

## 1. Glossário

Lista em ordem alfabética. Cada termo tem uma explicação curta, pensada para quem nunca ouviu a palavra antes.

### ANS

Agência Nacional de Saúde Suplementar. É o órgão do governo brasileiro que regula os planos de saúde privados. A ANS define as regras de como operadoras (planos) e prestadores (clínicas, hospitais, laboratórios) trocam informações.

### byte

A menor unidade de informação que o computador guarda de forma prática. Um byte é um número de 0 a 255. Texto, imagem e qualquer arquivo são, no fundo, uma sequência de bytes. Pense num byte como uma única letra numa fita: o arquivo inteiro é a fita toda.

### CDATA

Um trecho especial dentro de um XML (ver `XML`) onde você pode escrever caracteres que normalmente teriam significado especial (como `<` ou `&`) sem que eles confundam o leitor do arquivo. É como colocar um texto entre aspas para dizer "leia isto literalmente, não interprete".

### CLI

Command Line Interface, ou interface de linha de comando. É o jeito de usar um programa digitando comandos numa janela de texto (o terminal), em vez de clicar em botões. Por exemplo, `python3 reference.py arquivo.xml` é um uso de CLI.

### conformidade

Estar "em conformidade" significa seguir uma regra ou padrão à risca. Aqui, um port (ver `port`) está em conformidade quando produz exatamente o mesmo resultado que a definição oficial manda, para todos os casos de teste. Ver também `vetor de conformidade`.

### dependência

Um pedaço de código de terceiros que o seu programa precisa para funcionar. Se a sua biblioteca usa outra biblioteca, essa outra é uma dependência. Quanto menos dependências, mais simples é instalar e manter. O port Python tem apenas uma dependência de execução (`defusedxml`).

### encoding

A regra que diz como transformar letras e símbolos em bytes (ver `byte`) e vice-versa. A mesma letra "é" pode virar bytes diferentes dependendo do encoding. Escolher o encoding errado é como ler um texto com o dicionário errado: sai tudo trocado. Os dois encodings que importam aqui são `UTF-8` e `ISO-8859-1`.

### epílogo

A parte final da mensagem TISS (ver `TISS`). No XML, é o elemento `<ans:epilogo>`, que fica no fim do documento e guarda o `hash` (ver `hash`) usado para verificar a integridade do conteúdo. "Epílogo" é a mesma palavra usada para o capítulo final de um livro: o fechamento.

### hash

Um número-resumo calculado a partir de um conteúdo. Você joga um arquivo inteiro numa fórmula e recebe um código curto e de tamanho fixo. Se mudar um único caractere do arquivo, o código muda. Serve para conferir se dois conteúdos são idênticos. É como a impressão digital de um documento: única para aquele conteúdo. Aqui o hash tem 32 caracteres hexadecimais (ver `MD5`), por exemplo o sintético `3aa0c578c95cdb861a125f480a8a4de5`.

### ISO-8859-1

Um encoding (ver `encoding`) antigo, também chamado de Latin-1, que cobre as letras e acentos do português e de outras línguas da Europa ocidental. O manual do TISS diz que os arquivos devem usar este encoding. Atenção: isso vale para o arquivo, mas NÃO para o cálculo do hash (ver a pergunta sobre UTF-8 na seção 2).

### lote

Um conjunto de guias (pedidos de pagamento, autorizações, etc.) agrupado numa única mensagem TISS para enviar à operadora de uma só vez. Em vez de mandar uma guia por vez, o prestador junta várias num lote.

### MD5

Uma fórmula específica para calcular hash (ver `hash`). O resultado do MD5 tem sempre 32 caracteres hexadecimais (dígitos de 0 a 9 e letras de a a f). O padrão TISS exige MD5. Importante: aqui o MD5 serve só para conferir integridade do conteúdo, não para segurança (ver a pergunta sobre isso em [`USAGE.md`](USAGE.md#por-que-md5-se-ele-é-fraco-em-criptografia)).

### namespace

Um rótulo que evita confusão de nomes dentro de um XML (ver `XML`). Imagine duas pessoas chamadas "João" numa sala: você usa o sobrenome para saber de quem fala. No XML, o namespace é esse "sobrenome". No TISS, o namespace é `http://www.ans.gov.br/padroes/tiss/schemas`, geralmente abreviado pelo prefixo `ans:` (como em `<ans:hash>`).

### parser

O componente que lê o texto do XML e o transforma numa estrutura que o programa entende (a árvore de elementos). "Parsear" significa analisar e interpretar. O parser é quem descobre onde começa e termina cada tag, qual está dentro de qual, etc.

### port

Uma implementação da mesma biblioteca em outra linguagem de programação. "Portar" é traduzir o código para que rode em Python, Rust, Java, e assim por diante, mantendo o mesmo comportamento. Este projeto tem 9 ports: Python, Rust, C, C++, Node.js, PHP, Java, Go e C#. Cada um fica em `langs/<lang>/`.

### TISS

Troca de Informações na Saúde Suplementar. É o padrão criado pela ANS (ver `ANS`) que define o formato das mensagens trocadas entre planos de saúde e prestadores no Brasil. As mensagens TISS são arquivos XML (ver `XML`).

### UTF-8

O encoding (ver `encoding`) mais usado hoje no mundo. Consegue representar qualquer caractere de qualquer língua. Neste projeto, UTF-8 é o encoding usado para calcular o hash, mesmo que o arquivo XML esteja declarado em ISO-8859-1. Esse detalhe é a "pegadinha" central do projeto (ver a pergunta sobre isso na seção 2).

### vetor de conformidade

Um caso de teste oficial: um arquivo de entrada mais o resultado esperado. Se o port produz o resultado esperado para todos os vetores, ele está em conformidade (ver `conformidade`). Este projeto tem 20 vetores (18 positivos, que devem gerar um hash certo, e 2 negativos, que devem ser recusados). Ficam em [`conformance/vectors.json`](../conformance/vectors.json).

### XML

eXtensible Markup Language. Um formato de arquivo de texto que organiza dados em tags aninhadas, parecido com as etiquetas do HTML de uma página web. Por exemplo, `<paciente><nome>Maria</nome></paciente>`. As mensagens TISS são arquivos XML.

---

## 2. Perguntas frequentes (FAQ)

### Preciso entender o algoritmo para usar a biblioteca?

Não. Para usar, basta chamar uma função: você passa os bytes do XML e recebe o hash de 32 caracteres de volta. O algoritmo é um detalhe interno. Veja os exemplos prontos no [`USAGE.md`](USAGE.md) e o passo a passo no [`TUTORIAL.md`](TUTORIAL.md).

Se um dia você quiser entender por que o resultado é aquele (por curiosidade, para portar para uma nova linguagem, ou para depurar um caso estranho), aí sim leia o [`SPEC.md`](SPEC.md) e o [`CONCEITOS.md`](CONCEITOS.md). Mas não é pré-requisito para usar.

### Por que 9 linguagens?

Porque cada equipe de software usa a linguagem que já conhece, e ninguém deveria ter que reimplementar este algoritmo do zero (e arriscar errar a pegadinha do encoding). Os 9 ports cobrem os ambientes mais comuns na saúde suplementar brasileira:

- Python: scripts, integrações rápidas, back-ends.
- Rust e Go: serviços de back-end e microsserviços.
- C: base para falar com outras linguagens (FFI) e sistemas embarcados.
- C++: aplicações nativas e desempenho.
- Node.js: back-ends JavaScript e ferramentas.
- PHP: sistemas web tradicionais de faturamento.
- Java: sistemas hospitalares e ERPs corporativos.
- C# / .NET: aplicações de clínica em Windows.

Ter vários ports também é uma rede de segurança: se alguém errar a implementação em uma linguagem, o erro não passa, porque a CI (a automação que roda os testes) compara todos contra os mesmos vetores. Detalhe da decisão em [`CONCEITOS.md`](CONCEITOS.md) e em [`ARCHITECTURE.md`](ARCHITECTURE.md).

### Os hashes batem entre as linguagens?

Sim. Os 9 ports produzem exatamente o mesmo hash para o mesmo XML de entrada, byte a byte (ver `byte` no glossário). Isso é garantido por 20 vetores de conformidade (ver `vetor de conformidade`): 18 que devem gerar um hash específico e 2 que devem ser recusados. Toda vez que o código muda, a automação confere que todos os ports continuam batendo nos 20 vetores antes de liberar qualquer versão.

Na prática: se você calcular o hash de um lote em Python e um colega calcular o mesmo lote em Java, os dois recebem o mesmo código de 32 caracteres. A lista completa de vetores e seus hashes está em [`SPEC.md §8`](SPEC.md#8-vetores-de-conformidade).

### Posso usar em produção?

Sim, com uma recomendação de prudência. Os 9 ports passam os 20 vetores de conformidade e os parsers (ver `parser`) são endurecidos contra ataques conhecidos via XML. Antes de colocar no fluxo real, faça este teste simples: pegue alguns lotes (ver `lote`) seus que a operadora já aceitou no passado, calcule o hash com a biblioteca e confirme que bate com o que foi aceito. Isso valida que o seu caso de uso está coberto.

A licença é [MIT](../LICENSE): uso livre, inclusive comercial, sem garantias. Mais detalhes em [`USAGE.md`](USAGE.md#posso-usar-em-produção) e [`docs/legal/DISCLAIMER.md`](legal/DISCLAIMER.md).

### E os dados de paciente? A biblioteca guarda algo?

Não. A biblioteca apenas calcula o hash na memória e devolve o resultado. Ela não grava arquivo, não envia nada pela rede, não registra log do conteúdo. Quando a função termina, o XML some da memória do processo.

Mas atenção: o XML do TISS contém dados sensíveis de saúde. Quem manipula esses arquivos (você, o integrador) é responsável por protegê-los conforme a LGPD (Lei 13.709/2018). A biblioteca cuida só do cálculo; cuidar do arquivo, dos logs e do acesso é com você. As recomendações mínimas (não logar o conteúdo, limpar buffers, restringir acesso) estão em [`docs/legal/LGPD-NOTE.md`](legal/LGPD-NOTE.md).

### O manual oficial diz ISO-8859-1. Por que a biblioteca usa UTF-8?

Esta é a pergunta mais importante do projeto, e a razão de ele existir.

O manual do TISS diz que o encoding (ver `encoding`) é ISO-8859-1. Essa frase está correta para o arquivo XML, mas foi mal interpretada por muita gente como se valesse também para o cálculo do hash. Não vale.

Quando você calcula o MD5 sobre bytes em ISO-8859-1, o hash sai diferente do que a ANS aceita. O hash correto (o que a ANS de fato aceita) só aparece quando os bytes são convertidos para UTF-8 antes do cálculo. Isso foi descoberto comparando o resultado com hashes reais que a ANS já tinha aceitado.

Resumindo:

- Encoding do arquivo XML: ISO-8859-1 (como o manual manda).
- Encoding usado para calcular o hash: UTF-8 (o que funciona na prática).

A biblioteca já cuida dessa conversão internamente. Você só precisa passar os bytes brutos do arquivo. A explicação técnica completa está em [`SPEC.md §4`](SPEC.md#4-caveat-crítica-encoding-do-md5-é-utf-8-não-iso-8859-1).

---

## 3. Troubleshooting

Erros comuns, agrupados por categoria. Cada item traz a causa provável e a solução.

Os nomes de erro variam por linguagem (em Python é `InvalidTissXml`, em Java `InvalidTissXmlException`, em Go um `error` não-nulo, e assim por diante), mas as causas são as mesmas. O nome do erro de cada linguagem está na subseção "Como tratar erro" da seção daquela linguagem; comece pela [visão geral por linguagem](USAGE.md#1-visão-geral-por-linguagem) do `USAGE.md`.

### XML inválido (o arquivo não foi reconhecido)

**Sintoma:** a função lança um erro de XML inválido (em Python, `InvalidTissXml`) logo ao ler o conteúdo.

**Causa provável:** o XML está malformado. Falta fechar uma tag, há um caractere proibido, ou o conteúdo nem é XML (por exemplo, um arquivo vazio, um HTML, ou um JSON passado por engano). Também cai aqui o XML que tem um `DOCTYPE` ou uma entidade externa, que a biblioteca recusa de propósito por segurança (proteção contra ataques tipo XXE).

**Solução:**

1. Abra o arquivo num editor e confira se todas as tags abrem e fecham (todo `<tag>` tem o seu `</tag>`).
2. Confirme que é mesmo um XML TISS, e não outro tipo de arquivo.
3. Valide a boa-formação com uma ferramenta externa, por exemplo `xmllint --noout arquivo.xml`. Se ela reclamar, conserte o que ela apontar.
4. Não passe XML com `DOCTYPE` ou entidades externas: remova essas construções do documento.

### Encoding errado (o hash não bate)

**Sintoma:** o arquivo é processado sem erro, mas o hash gerado é diferente do que a operadora ou o sistema antigo esperava.

**Causa provável:** quase sempre é o encoding. Os casos mais comuns:

- Você decodificou o arquivo para texto e reencodou em ISO-8859-1 antes de chamar a função, em vez de passar os bytes brutos.
- Você normalizou o XML antes (rodou um formatador, `xmllint --format`, `--c14n`, ou um "pretty print"), o que mudou espaços dentro de valores.
- O valor antigo dentro de `<ans:hash>` foi calculado com o encoding errado (ISO-8859-1) por um sistema legado e nunca foi aceito pela ANS, então comparar com ele leva você ao engano.

**Solução:**

1. Sempre passe os bytes brutos do arquivo, lendo em modo binário. Não decodifique nem reencode você mesmo. Exemplo errado e certo em [`USAGE.md §12.1`](USAGE.md#121-o-encoding-dos-bytes-do-md5-é-utf-8-não-iso-8859-1).
2. Não rode formatadores nem normalizadores no XML antes de calcular. Passe exatamente os bytes que vão para a ANS. Ver [`USAGE.md §12.2`](USAGE.md#122-não-arrume-o-xml-antes-de-hashear).
3. Não confie no hash que já estava gravado no arquivo: recalcule sempre. Ver [`USAGE.md §12.4`](USAGE.md#124-não-confie-no-hash-já-gravado-no-arquivo).
4. Para confirmar que a biblioteca está certa, rode a referência num vetor sintético e veja se bate: `python3 conformance/reference.py conformance/inputs/syn_minimal.xml` deve devolver `3aa0c578c95cdb861a125f480a8a4de5`.

### Múltiplos `<ans:hash>` (entrada recusada)

**Sintoma:** a função recusa o arquivo com erro, mesmo o XML parecendo válido.

**Causa provável:** o documento tem mais de um elemento `<ans:hash>`. O padrão TISS prevê exatamente um. A biblioteca não tenta adivinhar qual zerar; por segurança, recusa.

**Solução:** corrija o XML para ter um único `<ans:hash>`, dentro do `<ans:epilogo>`. Se você está montando o XML por concatenação de pedaços, verifique se não duplicou o bloco do epílogo. Este caso é coberto pelo vetor negativo `syn_multi_hash.xml`; detalhe em [`SPEC.md §8.1`](SPEC.md#81-vetores-negativos-rejeição).

### UTF-16 recusado (encoding fora de escopo)

**Sintoma:** a função recusa o arquivo com erro de encoding fora de escopo.

**Causa provável:** o arquivo está em UTF-16 (ou UTF-32), detectado pela marca no início do arquivo (BOM). A biblioteca trabalha apenas com ISO-8859-1 e UTF-8, que são os encodings do TISS. UTF-16/UTF-32 estão fora de escopo e são recusados de propósito, para não gerar um hash silenciosamente errado.

**Solução:** converta o arquivo para o encoding correto antes de calcular. Em geral o XML TISS deve estar declarado e salvo como ISO-8859-1. Cuidado com editores de texto que salvam em UTF-16 sem avisar; ao salvar, escolha explicitamente o encoding certo. Este caso é coberto pelo vetor negativo `syn_utf16.xml`; detalhe em [`SPEC.md §8.1`](SPEC.md#81-vetores-negativos-rejeição).

### Arquivo não encontrado (erro de entrada/saída)

**Sintoma:** ao usar a função que recebe um caminho de arquivo (por exemplo `hash_tiss_file`), você recebe um erro de arquivo não encontrado ou de permissão (em Python, `FileNotFoundError` ou `PermissionError`, ambos do tipo `OSError`).

**Causa provável:** o caminho está errado, o arquivo não existe, ou o processo não tem permissão de leitura. Lembre que o caminho é relativo à pasta onde o programa está rodando, não à pasta onde o arquivo de código está.

**Solução:**

1. Confira o caminho. Prefira caminho absoluto (começando da raiz do sistema) quando estiver em dúvida.
2. Verifique se o arquivo existe e se o usuário do processo tem permissão de leitura.
3. Se o conteúdo já está na memória (veio de um banco, de uma requisição HTTP, etc.), use a função que recebe bytes em vez da que recebe caminho. Exemplos em [`USAGE.md §2`](USAGE.md#2-python).

---

## Ver também

- [`README.md`](../README.md): visão geral do projeto.
- [`CONCEITOS.md`](CONCEITOS.md): por que o projeto existe e como pensar nele (explanation).
- [`TUTORIAL.md`](TUTORIAL.md): primeiro hash, passo a passo (tutorial).
- [`USAGE.md`](USAGE.md): guia de uso e receitas (how-to).
- [`SPEC.md`](SPEC.md): especificação canônica do algoritmo (reference).
- [`docs/legal/LGPD-NOTE.md`](legal/LGPD-NOTE.md): obrigações de quem processa XML TISS.
