# Changelog

Todas as mudancas relevantes deste port sao documentadas aqui. Formato baseado
em [Keep a Changelog](https://keepachangelog.com/), versionamento
[SemVer](https://semver.org/).

## 0.1.0

- Versao inicial (alpha) do port Dart da lib `tiss_hash`.
- API: `hashTiss(List<int> bytes) -> String`,
  `hashTissFile(String path) -> Future<String>`, excecao
  `InvalidTissXmlException`, constante `tissNamespace`.
- 20/20 vetores de conformidade (`conformance/vectors.json`) PASS
  (18 positivos + 2 negativos), batendo byte-a-byte com a referencia Python.
- Suporte a encoding ISO-8859-1 e UTF-8 (com/sem BOM UTF-8); rejeita
  UTF-16/UTF-32 e documentos com mais de um `<ans:hash>`.
- Comentarios XML entram no concat (ambiguidade #2 da referencia).
- Normalizacao de fim-de-linha XML (CRLF/CR vira LF) antes do parse.
- Deps runtime: `package:xml` (parser) e `package:crypto` (MD5).
