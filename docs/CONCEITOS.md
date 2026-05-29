---
title: Conceitos, o que e e para que serve
type: explanation
audience: leigo / estudante iniciante de computacao
last-reviewed: 2026-05-29
owner: petrinhu@yahoo.com.br
---

# Conceitos: o que e e para que serve

Esta pagina explica, do zero, o que esta biblioteca faz e por que ela existe. Foi escrita para quem nunca ouviu falar de TISS, de hash ou de XML. Cada termo tecnico e explicado na primeira vez que aparece, com analogias simples.

Se voce ja conhece o assunto e quer ir direto ao codigo, pule para [USAGE.md](USAGE.md) (uso por linguagem) ou [SPEC.md](SPEC.md) (definicao tecnica do algoritmo).

> Nota de leitura: "biblioteca" (ou "lib") aqui significa um pedaco de codigo pronto que voce coloca dentro do seu programa para reaproveitar, em vez de escrever tudo de novo. Como uma receita pronta que voce inclui no seu livro de receitas.

## 1. Saude suplementar e a ANS

No Brasil, "saude suplementar" e a parte do sistema de saude formada pelos planos de saude privados (as operadoras) e por quem atende os pacientes por esses planos (clinicas, hospitais, laboratorios, chamados de prestadores), funcionando ao lado do SUS publico. A **ANS (Agencia Nacional de Saude Suplementar)** e o orgao do governo que regula esse setor: define as regras que operadoras e prestadores precisam seguir, inclusive como eles trocam informacoes entre si.

## 2. O Padrao TISS e por que existem arquivos XML

Quando uma clinica atende um paciente de um plano de saude, ela precisa cobrar o plano por aquele atendimento. Para que qualquer clinica consiga "conversar" com qualquer plano sem cada um inventar um formato proprio, a ANS criou o **Padrao TISS** (Troca de Informacoes em Saude Suplementar): um conjunto de regras que padroniza como essas informacoes (guias de consulta, exames, internacoes, valores cobrados) sao escritas e enviadas.

> Nao citamos aqui o numero da versao do Padrao TISS porque a ANS publica uma versao nova quase todo ano. O que esta lib resolve nao depende da versao.

Esse padrao define que as informacoes viajam dentro de **arquivos XML**. Um "lote TISS" e basicamente um arquivo XML com varias guias de atendimento juntas, que a clinica envia para a operadora do plano.

## 3. O que e um arquivo XML

**XML** (eXtensible Markup Language, "linguagem de marcacao extensivel") e um jeito de guardar informacao em texto puro, organizado de forma que tanto um humano quanto um programa consigam ler. A informacao fica dentro de **tags** (etiquetas): um par de marcas, uma de abertura e uma de fechamento, com o valor no meio.

Cada par "abre-valor-fecha" forma um **elemento**. Exemplo minimo:

```xml
<paciente>
  <nome>Maria</nome>
  <idade>34</idade>
</paciente>
```

Lendo: o elemento `<paciente>` contem dois elementos dentro dele, `<nome>` (com o valor "Maria") e `<idade>` (com o valor "34"). A barra `/` na marca de fechamento (`</nome>`) indica onde o elemento termina. Um elemento que so guarda um valor, sem outros elementos dentro, e chamado de **elemento-folha** (como `<nome>` e `<idade>` acima). Essa nocao de "folha" vai ser importante mais adiante.

Para ler um XML, um programa usa um **parser** (analisador): a parte do codigo que le o texto e transforma essas tags em uma estrutura que o programa entende. Voce nao precisa escrever um parser, cada linguagem ja vem com um.

## 4. O que e um hash, e o que e MD5

Um **hash** e um numero, ou um codigo, calculado a partir de um texto (ou de qualquer dado). Pense nele como uma **impressao digital do texto**: a partir de um texto grande, gera-se um codigo curto e de tamanho fixo que o identifica. A propriedade mais importante: se voce mudar **um unico caractere** do texto, o hash muda completamente, fica totalmente diferente. Isso permite detectar se alguem alterou o conteudo.

> Outra analogia: e como o lacre de uma caixa. Se o lacre ainda bate, ninguem mexeu na caixa. Se nao bate, algo foi alterado no caminho.

**MD5** e uma das formulas (algoritmos) que calculam esse hash. Ela sempre devolve um codigo de **32 caracteres** usando apenas os digitos de `0` a `9` e as letras de `a` a `f` (isso se chama formato **hexadecimal**, ou "hex", uma forma de escrever numeros que usa 16 simbolos em vez dos 10 do nosso dia a dia).

Exemplo de hash MD5 (do vetor de teste sintetico `syn_minimal`, dados ficticios deste projeto):

```
3aa0c578c95cdb861a125f480a8a4de5
```

Conte: sao 32 caracteres, todos entre `0-9` e `a-f`.

> Observacao tecnica: o MD5 nao e mais considerado seguro contra ataques deliberados modernos e nao deve ser usado para senhas ou seguranca forte. Mas o Padrao TISS exige MD5 para esse campo especifico, entao a lib usa MD5 por obrigacao do padrao, nao por escolha de seguranca.

## 5. O "epilogo" do XML TISS e o campo de hash

Em um lote TISS, depois de todas as guias de atendimento, vem uma parte final chamada **epilogo** (a "conclusao" do arquivo, como o final de uma carta). Dentro do epilogo existe um campo de hash: o elemento `<ans:hash>`.

> O prefixo `ans:` antes do nome do elemento vem de um conceito de XML chamado **namespace** (espaco de nomes): um rotulo que diz "este elemento pertence ao vocabulario da ANS", evitando confusao caso dois vocabularios diferentes usem um elemento com o mesmo nome. Para entender esta pagina, basta saber que `<ans:hash>` e o campo onde mora o hash do lote.

Esse campo guarda a impressao digital (o hash MD5) de todo o conteudo do lote. Quando a clinica envia o arquivo, a operadora e a ANS recalculam o hash do que receberam e comparam com o valor que veio no `<ans:hash>`. Se baterem, o lote chegou integro. Se nao baterem, o lote foi alterado no caminho (ou gerado errado) e e **rejeitado**. E o lacre da caixa, aplicado ao arquivo.

## 6. O problema que esta lib resolve

Para calcular o hash, o programa precisa transformar o texto do lote em **bytes** antes de passar pela formula MD5. "Byte" e a menor unidade de informacao que o computador guarda; transformar texto em bytes se chama **encoding** (codificacao): a regra que diz qual sequencia de bytes representa cada letra, acento ou simbolo. Existem varias dessas regras, com nomes como **ISO-8859-1** e **UTF-8**. A letra "c-cedilha" (c), por exemplo, vira bytes diferentes dependendo da regra escolhida.

Aqui esta a pegadinha:

- O manual oficial do Padrao TISS diz que o encoding e **ISO-8859-1**.
- Mas, na pratica, a ANS valida o hash sobre os bytes em **UTF-8**.

Quem le o manual ao pe da letra e calcula o MD5 sobre bytes ISO-8859-1 gera um hash **errado**, e a ANS **rejeita o lote**. Como o hash muda completamente quando muda qualquer detalhe da entrada (secao 4), basta essa diferenca de encoding para o codigo final ficar totalmente diferente do esperado.

Esta lib calcula o hash **do jeito que a ANS realmente aceita** (bytes UTF-8). Isso nao foi adivinhado: foi descoberto comparando com arquivos reais cujo hash a ANS confirmou, ate achar a unica combinacao que reproduz aqueles valores. O detalhe completo dessa descoberta esta em [SPEC.md, secao 4](SPEC.md).

## 7. Para que serve a lib

Resumo em uma frase: voce entrega o arquivo XML do lote TISS, e a lib devolve o **hash MD5 correto do epilogo**, aquele que a ANS aceita.

E ela faz isso em **9 linguagens de programacao**: Python, Rust, C, C++, Node.js, PHP, Java, Go e C#. Cada uma vive em sua pasta dentro de `langs/<linguagem>/`. O ponto central: as 9 produzem o **mesmo resultado, identico byte a byte**. Nao importa em qual linguagem seu sistema foi escrito, o hash sai igual.

Para garantir isso, o projeto tem uma **suite de conformidade** com **20 vetores de teste**: 18 positivos (entradas validas com o hash esperado) e 2 negativos (entradas invalidas que a lib deve recusar). "Conformidade" aqui significa estar de acordo com a regra definida: antes de qualquer versao ser liberada, todas as 9 linguagens precisam passar nos 20 testes, todas dando o mesmo hash. Os dados desses testes sao 100% **sinteticos** (inventados), nenhum dado real de paciente entra no projeto.

> Sobre **dependencias**: uma "dependencia" e outro pedaco de software que a lib precisa para funcionar. Esta lib procura usar o minimo possivel, para ser facil de instalar e segura. Veja os detalhes por linguagem em [USAGE.md](USAGE.md).

## 8. Quem usa

Quem desenvolve sistemas que **geram e enviam lotes TISS**:

- clinicas e consultorios;
- hospitais e laboratorios;
- empresas de software de gestao em saude (faturamento medico, prontuario, sistemas hospitalares);
- qualquer prestador ou integrador que precise mandar lotes para uma operadora de plano de saude.

Se voce esta nesse grupo e o seu hash "nao bate" com o que a ANS espera, e bem provavel que o problema seja exatamente o encoding descrito na secao 6.

## 9. O fluxo, em um diagrama

Da entrada do XML ate os 32 caracteres de saida:

```
  +-------------------+
  | Arquivo XML       |   voce entrega o lote TISS (bytes do arquivo)
  | (lote TISS)       |
  +-------------------+
            |
            v
  +-------------------+
  | Zera o campo      |   o conteudo de <ans:hash> e esvaziado
  | <ans:hash>        |   (o hash nao entra no calculo dele mesmo)
  +-------------------+
            |
            v
  +-------------------+
  | Concatena os      |   junta o texto de cada elemento-folha,
  | valores           |   na ordem em que aparecem no arquivo
  +-------------------+
            |
            v
  +-------------------+
  | MD5 sobre bytes   |   transforma o texto em bytes UTF-8
  | UTF-8             |   (NAO ISO-8859-1) e aplica a formula MD5
  +-------------------+
            |
            v
  +-------------------+
  | 32 caracteres hex |   ex.: 3aa0c578c95cdb861a125f480a8a4de5
  | (o hash final)    |   esse e o valor que a ANS aceita
  +-------------------+
```

Em palavras: o XML entra, o campo de hash e zerado, os valores das folhas sao concatenados (juntados um apos o outro), o resultado vira bytes UTF-8, aplica-se o MD5 e saem 32 caracteres hexadecimais. A descricao tecnica passo a passo esta em [SPEC.md, secao 3](SPEC.md).

## 10. Para onde ir agora

- Quer colocar a mao na massa e calcular um hash do zero, com um exemplo guiado: veja [TUTORIAL.md](TUTORIAL.md).
- Quer usar a lib na sua linguagem (Python, Rust, C, C++, Node.js, PHP, Java, Go ou C#): veja [USAGE.md](USAGE.md).
- Quer duvidas comuns respondidas: veja [FAQ.md](FAQ.md).
- Quer a definicao tecnica exata do algoritmo: veja [SPEC.md](SPEC.md).

Proximo passo: ver [TUTORIAL.md](TUTORIAL.md) (mao na massa) ou [USAGE.md](USAGE.md) (sua linguagem).
