# Atribuições de terceiros (Third-Party Licenses)

O projeto **TISS_ANS_hash** é distribuído sob a licença **MIT** (ver `LICENSE`).
Este arquivo **não altera** a licença do projeto: ele apenas **agrega os avisos
de copyright e atribuição** exigidos pelas licenças das bibliotecas de terceiros
usadas por cada port (port = implementação por linguagem em `langs/<lang>/`).

A atribuição é organizada **por port**, distinguindo:

- **Runtime / distribuída** — dependência que acompanha ou é exigida em tempo de
  execução pelo software entregue ao usuário; a licença normalmente exige
  preservar o aviso de copyright ao distribuir.
- **Test / dev-only** — dependência usada apenas para construir/testar; **não**
  é embarcada no artefato distribuível, salvo quando o código-fonte da
  dependência está versionado neste repositório (caso em que a atribuição é
  mantida mesmo sendo de teste — ver C++/doctest).

> Versões: quando o manifesto fixa uma faixa (`^`, `~`, `>=`), reproduzimos a
> restrição declarada, não a versão exata resolvida no lockfile.
> As licenças MIT, Apache-2.0, BSD e Boost são todas permissivas e compatíveis
> com a redistribuição sob MIT do projeto.

---

## Visão geral por port

| Port | Dependência | Licença (SPDX) | Tipo | Fonte (manifesto) |
|---|---|---|---|---|
| Python | defusedxml `>=0.7.1` | PSF-2.0 (Python Software Foundation License) | runtime | `langs/python/pyproject.toml` |
| Python | lxml `>=4.9` | BSD-3-Clause | runtime (extra opcional, não instalado por padrão) | `langs/python/pyproject.toml` |
| Python | pytest / pytest-cov | MIT | test/dev | `langs/python/pyproject.toml` |
| Rust | roxmltree `0.20` | MIT OR Apache-2.0 | runtime | `langs/rust/Cargo.toml` |
| Rust | md-5 (RustCrypto) `0.10` | MIT OR Apache-2.0 | runtime | `langs/rust/Cargo.toml` |
| Rust | serde / serde_json `1` | MIT OR Apache-2.0 | test/dev | `langs/rust/Cargo.toml` |
| Node | @xmldom/xmldom `^0.9.0` | MIT | runtime | `langs/node/package.json` |
| PHP | ext-dom / ext-libxml / ext-mbstring | extensões PHP (PHP License 3.01); libxml2 = MIT | runtime (do sistema) | `langs/php/composer.json` |
| PHP | phpunit `^10.5` | BSD-3-Clause | test/dev | `langs/php/composer.json` |
| C | libxml2 | MIT | runtime (sistema, link dinâmico) | `langs/c/CMakeLists.txt` |
| C | OpenSSL (libcrypto) | Apache-2.0 | runtime (sistema, link dinâmico) | `langs/c/CMakeLists.txt` |
| C++ | pugixml `>=1.10` (sistema ou FetchContent v1.14) | MIT | runtime | `langs/cpp/CMakeLists.txt` |
| C++ | OpenSSL (libcrypto) | Apache-2.0 | runtime (sistema, link dinâmico) | `langs/cpp/CMakeLists.txt` |
| C++ | doctest | MIT | test-only **(header versionado no repo)** | `langs/cpp/third_party/doctest.h` |
| Java | — (JDK puro: `javax.xml` + `java.security.MessageDigest`) | — | — | `langs/java/pom.xml` |
| Java | JUnit Jupiter `5.10.2` | EPL-2.0 | test/dev | `langs/java/pom.xml` |
| Java | org.json `20240303` | Public Domain (JSON License variante) | test/dev | `langs/java/pom.xml` |
| Go | golang.org/x/text `v0.14.0` | BSD-3-Clause | runtime | `langs/go/go.mod` |
| C# | System.Text.Encoding.CodePages `8.0.0` | MIT | runtime | `langs/csharp/src/TissHash/TissHash.csproj` |
| C# | xunit / Microsoft.NET.Test.Sdk | MIT (Apache-2.0 para alguns componentes MS) | test/dev | `langs/csharp/tests/.../TissHash.Tests.csproj` |

> **Observação sobre link dinâmico de libs de sistema (C/C++):** libxml2,
> OpenSSL e pugixml-do-sistema normalmente são linkados dinamicamente a partir
> de pacotes do SO; este repositório **não** redistribui binários dessas libs.
> A atribuição abaixo é mantida por boa prática e para quem optar por empacotar
> a biblioteca junto (ex.: build estático ou container).

---

## Python (`langs/python/`)

### defusedxml — runtime
- Licença: **PSF-2.0** (Python Software Foundation License).
- Copyright (c) Christian Heimes e contribuidores.
- Atribuição: preservar o aviso de copyright e a licença PSF ao redistribuir.

### lxml — runtime (extra opcional `lxml`, não instalado por padrão)
- Licença: **BSD-3-Clause**.
- Copyright (c) lxml dev team.

### pytest, pytest-cov — test/dev (não distribuído)
- Licença: **MIT**.

---

## Rust (`langs/rust/`)

### roxmltree — runtime
- Licença: **MIT OR Apache-2.0** (escolha do consumidor).
- Copyright (c) Yevhenii Reizner (RazrFalcon) e contribuidores.

### md-5 (RustCrypto) — runtime
- Licença: **MIT OR Apache-2.0** (escolha do consumidor).
- Copyright (c) RustCrypto Developers.

### serde, serde_json — test/dev (não distribuído)
- Licença: **MIT OR Apache-2.0**.

---

## Node (`langs/node/`)

### @xmldom/xmldom — runtime
- Licença: **MIT**.
- Copyright (c) xmldom authors / Jindi Witschi e contribuidores.

```
The MIT License (MIT)
Copyright (c) the xmldom authors
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software") ...
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
```

---

## PHP (`langs/php/`)

### ext-dom, ext-libxml, ext-mbstring — runtime (extensões PHP do sistema)
- As extensões fazem parte do runtime PHP, sob **PHP License 3.01**.
- A `ext-dom`/`ext-libxml` usam a libxml2 subjacente, licenciada **MIT**
  (Copyright (c) Daniel Veillard).

### phpunit — test/dev (não distribuído)
- Licença: **BSD-3-Clause** — Copyright (c) Sebastian Bergmann.

---

## C (`langs/c/`)

> Linkadas dinamicamente a partir de pacotes do sistema; não redistribuídas
> neste repositório.

### libxml2 — runtime
- Licença: **MIT**.
- Copyright (c) 1998-2012 Daniel Veillard. All Rights Reserved.

### OpenSSL (libcrypto) — runtime
- Licença: **Apache-2.0** (OpenSSL 3.x).
- Copyright (c) 1998-2024 The OpenSSL Project Authors. All Rights Reserved.
- A Apache-2.0 exige preservar avisos de copyright, o texto da licença e o
  aviso de modificações (se houver) ao redistribuir.

---

## C++ (`langs/cpp/`)

### pugixml — runtime
- Licença: **MIT**.
- Copyright (c) 2006-2024 Arseny Kapoulkine.
- Obtida via pacote do sistema ou, em fallback, via CMake FetchContent (v1.14).

### OpenSSL (libcrypto) — runtime
- Licença: **Apache-2.0** (OpenSSL 3.x).
- Copyright (c) 1998-2024 The OpenSSL Project Authors. All Rights Reserved.

### doctest — test-only, **header versionado** em `langs/cpp/third_party/doctest.h`
- Licença: **MIT**.
- Copyright (c) 2016-2023 Viktor Kirilov.
- O header é distribuído no repositório, portanto a atribuição MIT é mantida
  mesmo sendo dependência de teste.
- Partes derivadas de **Catch2** (Boost Software License 1.0) e de **lest**
  (Boost Software License 1.0), conforme avisos no topo do próprio arquivo.

```
doctest.h - the lightest feature-rich C++ single-header testing framework
Copyright (c) 2016-2023 Viktor Kirilov
Distributed under the MIT Software License
https://opensource.org/licenses/MIT
```

---

## Java (`langs/java/`)

> O código de produção do port Java **não usa dependências de terceiros**:
> apenas a JDK (`javax.xml` + `java.security.MessageDigest`).

### JUnit Jupiter `5.10.2` — test/dev (não distribuído)
- Licença: **EPL-2.0** (Eclipse Public License 2.0).
- Copyright (c) the JUnit Team.

### org.json `20240303` — test/dev (não distribuído)
- Licença: **Public Domain** (variante "JSON License" com a cláusula
  "The Software shall be used for Good, not Evil").
- Copyright (c) 2002 JSON.org.

---

## Go (`langs/go/`)

### golang.org/x/text `v0.14.0` — runtime
- Licença: **BSD-3-Clause**.
- Copyright (c) 2009 The Go Authors. All rights reserved.

```
Copyright (c) 2009 The Go Authors. All rights reserved.
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
... (BSD-3-Clause) ...
```

---

## C# (`langs/csharp/`)

### System.Text.Encoding.CodePages `8.0.0` — runtime
- Licença: **MIT**.
- Copyright (c) .NET Foundation and Contributors.

### xunit, Microsoft.NET.Test.Sdk, xunit.runner.visualstudio — test/dev (não distribuído)
- xunit: **Apache-2.0** (componentes históricos sob "xUnit.net license", baseada em Apache-2.0).
- Microsoft.NET.Test.Sdk: **MIT** — Copyright (c) .NET Foundation.

---

## Itens a confirmar com o jurídico/DPO

> Recomendação técnica; validar com DPO/jurídico antes de tratar como definitivo.

1. **org.json (`20240303`)** — a cláusula "shall be used for Good, not Evil"
   torna a licença **não-OSI** e tecnicamente não-livre para alguns auditores
   (Debian/FSF a consideram problemática). Como é **test-only e não
   distribuída**, o risco é baixo, mas convém avaliar trocar por uma lib JSON
   de teste sob MIT/Apache (ex.: Jackson, Gson) se houver política interna que
   barre licenças não-OSI mesmo em escopo de teste.
2. **OpenSSL** — confirmar a versão efetivamente linkada no ambiente de
   distribuição: OpenSSL **3.x = Apache-2.0**; OpenSSL **1.x = dual
   OpenSSL/SSLeay License** (atribuição diferente). O CMakeLists silencia
   `-Wdeprecated-declarations` de OpenSSL 3.x, o que indica 3.x, mas o pacote
   real depende do SO do consumidor.
3. **xunit** — a denominação histórica "xUnit.net license" deriva de Apache-2.0;
   confirmar a versão/SPDX exata se for relevante para o relatório de SCA.
4. Se algum port passar a **redistribuir binários** de libs de sistema
   (libxml2, OpenSSL, pugixml) — ex.: build estático, container, bundle —, a
   atribuição Apache-2.0 do OpenSSL passa a ser **obrigatória no artefato** e
   este arquivo deve acompanhar o pacote.
```
