---
title: "Tutorial: seu primeiro hash TISS do zero (Python)"
type: tutorial
audience: iniciante (estudante de computação, primeiro contato com a lib)
version: 0.1.0
last-reviewed: 2026-05-29
owner: petrinhu@yahoo.com.br
status: estável (port Python pronto)
---

# Tutorial: seu primeiro hash TISS do zero

**Tempo estimado:** 15 a 20 min
**Nível:** iniciante. Se você nunca rodou um script Python, este guia é pra você.
**O que você terá ao fim:** um programa de 3 linhas que lê um arquivo XML e imprime um hash na tela.

Este é um **tutorial**: feito para você aprender fazendo, do começo ao fim, na ordem. Cada passo tem o comando exato e o que você deve ver acontecer. Se algo não bater com o esperado, pare e confira o passo antes de seguir.

Quando você quiser usar a lib de verdade no seu projeto (e nas outras 8 linguagens), o documento certo é o guia de uso, [`USAGE.md`](USAGE.md). Aqui o objetivo é só te levar do nada até o primeiro hash funcionando.

## Antes de começar: 3 palavras que você vai ver o tempo todo

Vamos definir o jargão na primeira vez. Releia esta lista sempre que travar.

- **Hash**: um número de tamanho fixo calculado a partir de um conteúdo qualquer. Pense numa "impressão digital" do arquivo: se você mudar um único caractere do conteúdo, a impressão digital muda completamente. Aqui o hash sai como 32 caracteres entre `0-9` e `a-f` (isso se chama **hexadecimal**, ou "hex"). Exemplo de hash (sintético, ilustrativo): `3aa0c578c95cdb861a125f480a8a4de5`.
- **MD5**: o nome do algoritmo específico que produz esse hash. É só a "receita" usada pra calcular a impressão digital. O Padrão TISS exige MD5.
- **XML**: um formato de arquivo de texto que guarda dados dentro de "etiquetas" (chamadas **tags**) como `<nome>João</nome>`. O mundo da saúde suplementar brasileira troca dados nesse formato, no chamado **Padrão TISS**.

Os demais termos (parser, namespace, byte, encoding, epílogo, dependência, CLI) aparecem explicados no passo onde forem usados.

## 1. Instalar o Python

A lib que você vai usar é escrita em **Python**, uma linguagem de programação. Para rodá-la, seu computador precisa ter o Python instalado.

Talvez ele já esteja. Abra o seu terminal (no Linux/macOS é o app "Terminal"; no Windows, o "PowerShell" ou "Prompt de Comando") e digite:

```bash
python3 --version
```

O que esperar ver: uma linha como `Python 3.12.4`. **O número precisa ser 3.10 ou maior** (3.10, 3.11, 3.12...). Se aparecer 3.9 ou menor, ou se aparecer algo como "comando não encontrado", você precisa instalar/atualizar.

Para instalar, baixe do site oficial: <https://www.python.org/downloads/>. Escolha a versão estável mais recente, baixe o instalador para o seu sistema e siga o assistente.

> Dica para Windows: no instalador, marque a caixa **"Add Python to PATH"** antes de clicar em instalar. Sem isso, o terminal não acha o `python3`.

Depois de instalar, feche e reabra o terminal e rode `python3 --version` de novo para confirmar.

## 2. Pegar a biblioteca

### 2.1 O que é uma "biblioteca" e o que é `pip`

Uma **biblioteca** (ou "lib", ou **dependência**) é código pronto que outra pessoa escreveu e que você reaproveita no seu programa, em vez de escrever tudo do zero. A nossa lib se chama `tiss-hash`.

Para instalar bibliotecas Python existe uma ferramenta que vem junto com o Python: o **pip**. Você diz "pip, instale a lib X" e ele baixa e prepara tudo.

### 2.2 O que é um `venv` e por que usar

Um **ambiente virtual** (em inglês *virtual environment*, abreviado **venv**) é uma "caixa" isolada onde você instala as bibliotecas de um projeto, sem misturar com o resto do sistema. É como ter uma gaveta separada por projeto: o que você guarda numa não bagunça as outras. Usar venv evita o clássico "instalei uma coisa pra um projeto e quebrou outro".

Crie e ative um venv:

```bash
python3 -m venv .venv
```

Isso cria uma pasta `.venv` no diretório atual. Agora ative ela:

```bash
# Linux ou macOS:
source .venv/bin/activate

# Windows (PowerShell):
.venv\Scripts\Activate.ps1
```

O que esperar ver: o seu prompt do terminal passa a começar com `(.venv)`. Isso indica que a "gaveta" está aberta e tudo que o `pip` instalar daqui pra frente vai pra dentro dela.

> Para sair do venv mais tarde, digite `deactivate`. Para voltar a usá-lo numa nova sessão de terminal, rode o comando `source` (ou o `Activate.ps1`) de novo.

### 2.3 Baixar o repositório e instalar a lib

Com o venv ativo, baixe o código do projeto. **Clonar** um repositório significa copiar para a sua máquina todos os arquivos do projeto que estão no servidor (aqui, o GitHub). A ferramenta usada é o `git`:

```bash
git clone https://github.com/petrinhu/TISS_ANS_hash.git
cd TISS_ANS_hash/langs/python
```

> Se você não tem o `git`, baixe em <https://git-scm.com/downloads>. Alternativa sem git: o GitHub permite baixar um `.zip` pelo botão "Code" e descompactar.

Agora instale a lib a partir desse código baixado:

```bash
pip install -e .
```

O `-e` quer dizer "editável": instala apontando para os arquivos que você baixou, em vez de copiar. Para um tutorial dá no mesmo; só saiba que o `.` no fim significa "a pasta atual" (você está dentro de `langs/python`, que tem o arquivo de configuração da lib).

O que esperar ver: várias linhas de progresso terminando com algo como `Successfully installed tiss-hash-0.1.0 defusedxml-...`. O `defusedxml` é a única dependência da lib (uma proteção de segurança na leitura do XML); o `pip` a instala sozinho.

Confirme que deu certo:

```bash
python3 -c "import tiss_hash; print('ok', tiss_hash.__version__)"
```

O que esperar ver: `ok 0.1.0` (ou outra versão). Se aparecer `ModuleNotFoundError`, a instalação não funcionou: confira se o venv está ativo (prompt com `(.venv)`) e repita o `pip install -e .`.

## 3. Criar um XML TISS de exemplo

Agora você vai criar um arquivo de entrada para a lib calcular o hash. Vamos usar um exemplo **mínimo e sintético** (inventado, sem dado de paciente real).

Antes, mais dois termos:

- **Namespace**: é um "sobrenome" que se dá às tags do XML para não confundir tags de origens diferentes. No Padrão TISS, as tags levam o prefixo `ans:` (de Agência Nacional de Saúde Suplementar), e esse prefixo é ligado a um endereço oficial que aparece no atributo `xmlns:ans="..."`. É só identificação; você não precisa acessar esse endereço.
- **Epílogo**: a parte final da mensagem TISS, dentro da tag `<ans:epilogo>`. É justamente onde mora a tag `<ans:hash>`, que vai receber a impressão digital do conteúdo.

Crie um arquivo chamado `lote.xml`. Você pode usar qualquer editor de texto (VS Code, Bloco de Notas, `nano`, `gedit`). Cole exatamente este conteúdo e salve:

```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<ans:mensagemTISS xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">
  <ans:cabecalho>
    <ans:tipoTransacao>ENVIO_LOTE_GUIAS</ans:tipoTransacao>
    <ans:sequencialTransacao>1</ans:sequencialTransacao>
  </ans:cabecalho>
  <ans:epilogo>
    <ans:hash></ans:hash>
  </ans:epilogo>
</ans:mensagemTISS>
```

O que cada parte faz:

- A primeira linha (`<?xml ...?>`) é a "ficha técnica" do arquivo: diz que é XML e qual o **encoding** declarado (já já explicamos encoding).
- `<ans:mensagemTISS ...>` é a tag que envolve tudo. O `xmlns:ans="..."` define o namespace.
- O `<ans:cabecalho>` tem dois dados de exemplo (tipo de transação e um número sequencial).
- O `<ans:epilogo>` contém `<ans:hash></ans:hash>` **vazia de propósito**: é o espaço reservado onde o hash deveria ser gravado. A lib ignora o que estiver aqui dentro e calcula o hash do resto.

> Por que a `<ans:hash>` fica vazia? Porque o hash é calculado sobre todo o conteúdo, **exceto** o próprio campo de hash. Se o hash entrasse no cálculo dele mesmo, seria impossível calcular. Então a lib zera esse campo internamente antes de calcular. Você não precisa fazer nada: pode deixar vazio (como acima) ou com qualquer lixo dentro, o resultado é o mesmo.

Salve o `lote.xml` na mesma pasta onde você está no terminal (a pasta `langs/python`), para o próximo passo achar o arquivo facilmente.

## 4. Rodar: calcular o hash

Crie um segundo arquivo, chamado `meu_hash.py`, na mesma pasta, com estas três linhas:

```python
from tiss_hash import hash_tiss_file

digest = hash_tiss_file("lote.xml")
print(digest)
```

Linha a linha:

1. `from tiss_hash import hash_tiss_file` traz para o seu script a função pronta da lib. **Função** é um pedaço de código com nome que você manda executar.
2. `digest = hash_tiss_file("lote.xml")` chama essa função passando o nome do seu arquivo; ela lê o XML e devolve o hash, que guardamos na variável `digest`.
3. `print(digest)` mostra o resultado na tela.

Agora execute o script. Aqui você está usando a **CLI** (do inglês *command-line interface*, "interface de linha de comando"): é só a forma de mandar comandos digitando texto no terminal, em vez de clicar em botões.

```bash
python3 meu_hash.py
```

O que esperar ver: uma única linha com 32 caracteres hex, parecida com esta (valor **ilustrativo**, só para você ter ideia do formato):

```
3aa0c578c95cdb861a125f480a8a4de5
```

> Importante: o hash que **você** vai ver pode ser diferente deste, porque depende exatamente do conteúdo do seu `lote.xml` (espaços, quebras de linha, acentos). O valor acima é um hash sintético do projeto, mostrado só como exemplo de formato. O que importa é: saiu uma linha com 32 caracteres hex, sem erro. Se foi isso, parabéns: você calculou seu primeiro hash TISS.

## 5. Entender o que aconteceu

Em uma frase: a lib leu os bytes do seu XML, juntou em sequência o texto de todas as tags que não têm tags-filhas (chamadas "folhas"), tratou esse texto juntado como **UTF-8**, e calculou o MD5 desses bytes, devolvendo 32 caracteres hex.

Dois termos que faltavam:

- **Byte**: a menor unidade de dado que o computador manipula (um número de 0 a 255). Um arquivo de texto é, no fundo, uma sequência de bytes. Cada caractere vira um ou mais bytes conforme o encoding.
- **Encoding**: a regra que diz como cada caractere (por exemplo a letra `ç` ou `ã`) é convertido em bytes. Existem várias regras; duas comuns são **UTF-8** e **ISO-8859-1**. A mesma letra acentuada vira bytes diferentes em cada regra, e por isso o encoding muda o hash.

Aqui mora o detalhe mais importante (e a razão de este projeto existir): o manual do Padrão TISS sugere ISO-8859-1, mas o hash que a ANS de fato aceita é calculado em **UTF-8**. A lib já faz a coisa certa pra você, em todas as 9 linguagens. Você não precisa decidir nada sobre encoding: só passe os bytes do arquivo.

Para a versão completa, com a regra exata, os casos de borda e o passo a passo do algoritmo, leia a especificação canônica em [`SPEC.md`](SPEC.md). Para o "porquê" conceitual (o que é o hash do epílogo, por que MD5, a história da divergência de encoding), veja [`CONCEITOS.md`](CONCEITOS.md).

Por fim, **conformidade** é a garantia de que cada uma das 9 linguagens produz exatamente o mesmo hash para a mesma entrada. O projeto mantém 20 casos de teste (chamados "vetores": 18 que devem produzir um hash conhecido e 2 que devem ser rejeitados), e toda linguagem precisa passar nos 20 antes de qualquer publicação.

## 6. Erros comuns de iniciante

Estes são os tropeços mais frequentes na primeira vez. Cada um mostra o que dispara o erro e como resolver.

### XML inválido: `InvalidTissXml`

Se o conteúdo do arquivo não for um XML bem-formado (uma tag aberta e não fechada, por exemplo), a lib avisa com um erro chamado `InvalidTissXml` (um **parser**, que é a parte que lê e interpreta o XML, não consegue entender o arquivo).

Teste de propósito: troque o conteúdo do `lote.xml` por `<isto-nao-fecha>` e rode o script. Você verá um traceback terminando com algo como:

```
tiss_hash._core.InvalidTissXml: ...
```

Como resolver: conserte o XML (toda tag aberta `<x>` precisa de uma fechada `</x>`). Volte ao conteúdo correto do passo 3.

### Arquivo não encontrado

Se você digitar o nome errado, ou rodar o script de uma pasta diferente de onde está o `lote.xml`, verá:

```
FileNotFoundError: [Errno 2] No such file or directory: 'lote.xml'
```

Como resolver: confirme que `meu_hash.py` e `lote.xml` estão na mesma pasta e que você roda `python3 meu_hash.py` de dentro dessa pasta. O comando `ls` (Linux/macOS) ou `dir` (Windows) lista os arquivos da pasta atual para você conferir.

### Encoding: não converta o arquivo "na mão"

Iniciantes às vezes abrem o arquivo como texto e reconvertem antes de passar para a lib. **Não faça isso.** A lib precisa dos **bytes brutos** do arquivo para acertar o encoding internamente. Usando `hash_tiss_file("lote.xml")` (como neste tutorial) você nem corre esse risco, porque ela mesma abre o arquivo do jeito certo. Só fique atento se um dia for ler o arquivo por conta própria: leia em modo binário, nunca como texto já decodificado. O detalhe está explicado no guia de uso, [`USAGE.md`](USAGE.md), seção de pegadinhas.

## Resumo

Você:

- instalou o Python (3.10+) e confirmou a versão;
- criou um ambiente isolado (venv) e instalou a lib `tiss-hash` com o `pip`;
- escreveu um XML TISS mínimo com a tag `<ans:hash>` vazia;
- rodou um script de 3 linhas e obteve 32 caracteres hex;
- entendeu, em alto nível, o que o algoritmo faz e por que o encoding é UTF-8.

## Próximos passos

- Usar a lib de verdade, com receitas práticas (ler bytes da memória, integrar com uma API web, processar uma pasta inteira de lotes): [`USAGE.md`](USAGE.md).
- Entender a fundo o conceito e a história do hash do epílogo: [`CONCEITOS.md`](CONCEITOS.md).
- Consultar a regra exata do algoritmo, com casos de borda: [`SPEC.md`](SPEC.md).
- Tirar dúvidas rápidas (por que MD5, posso usar em produção, e se a ANS mudar): [`FAQ.md`](FAQ.md).

## E nas outras linguagens?

Este tutorial usou Python por ser o mais simples para começar, mas a lib existe em 9 linguagens (Python, Rust, C, C++, Node.js, PHP, Java, Go, C#), todas com o mesmo resultado. Para instalar e calcular o hash em qualquer uma das outras, veja [`USAGE.md`](USAGE.md).
