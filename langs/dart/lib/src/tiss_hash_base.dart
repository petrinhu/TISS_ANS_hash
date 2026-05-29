// Copyright (c) 2026 Petrus Silva Costa. MIT License.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

/// URI do namespace XML do Padrao TISS/ANS.
///
/// Usado para localizar `<ans:hash>`. O prefixo convencional e `ans:`, mas o
/// que conta e a **URI**: qualquer prefixo serve, desde que mapeie pra esta
/// URI (e o namespace pode ate ser o default, sem prefixo). Por isso o port
/// casa `<hash>` por `namespaceUri` + `local`, nunca pelo prefixo literal.
const String tissNamespace = 'http://www.ans.gov.br/padroes/tiss/schemas';

/// Local name do elemento que guarda o hash dentro do epilogo TISS.
const String _hashLocalName = 'hash';

/// Erro lancado quando o XML e invalido ou rejeitado pelo contrato do hash
/// TISS (parser falhou, encoding fora de escopo, ou multiplos `<ans:hash>`).
///
/// E uma excecao tipada (`implements Exception`) para permitir discriminacao
/// via `on InvalidTissXmlException catch (e)`.
class InvalidTissXmlException implements Exception {
  /// Mensagem descritiva (sem PII; nunca inclui conteudo do XML).
  final String message;

  /// Causa raiz preservada (ex.: o `XmlException` do parser), quando houver.
  final Object? cause;

  const InvalidTissXmlException(this.message, {this.cause});

  @override
  String toString() {
    final base = 'InvalidTissXmlException: $message';
    return cause == null ? base : '$base (causa: $cause)';
  }
}

/// Calcula o hash MD5 canonico do epilogo TISS/ANS a partir dos bytes do XML.
///
/// Retorna uma string hex de **32 caracteres minusculos** (lowercase).
///
/// Aceita arquivos declarados como `encoding="iso-8859-1"` (padrao TISS) ou
/// `encoding="utf-8"`, com ou sem BOM UTF-8 no inicio. Rejeita UTF-16/UTF-32
/// (detectados por BOM) e documentos com mais de um `<ans:hash>`.
///
/// Algoritmo (identico aos demais ports e a referencia em
/// `conformance/reference.py`):
///   1. Decodifica os bytes respeitando a declaracao `encoding=`.
///   2. Parseia o XML preservando comentarios.
///   3. Localiza `<ans:hash>` pela URI do namespace (nao por prefixo) e zera
///      seu texto. Documento sem `<ans:hash>` e VALIDO; com mais de um e
///      REJEITADO.
///   4. Concatena o texto de cada **no-folha** (Element ou Comment sem filhos
///      Element/Comment/PI), em ordem de documento.
///   5. MD5 dos bytes **UTF-8** da string concatenada.
///   6. Hex minusculo (32 chars).
///
/// Lanca [InvalidTissXmlException] se a entrada for invalida/rejeitada.
String hashTiss(List<int> bytes) {
  _rejectUnsupportedEncoding(bytes);

  final xmlStr = _decodeXmlBytes(bytes);

  // Normalizacao de fim-de-linha da spec XML (XML 1.0 secao 2.11): antes do
  // parse, todo "\r\n" e "\r" isolado vira "\n". A referencia (lxml) e os
  // demais ports (xmldom, etc.) aplicam isso; o package:xml NAO normaliza por
  // padrao, entao fazemos aqui pra bater byte-a-byte (vetor syn_crlf_value).
  final normalized = _normalizeXmlEol(xmlStr);

  final XmlDocument doc;
  try {
    // Comentarios sao preservados por padrao no package:xml. Valores
    // so-de-espaco (<x>   </x>) tambem sobrevivem (sem trim de conteudo).
    doc = XmlDocument.parse(normalized);
  } on XmlException catch (e) {
    throw InvalidTissXmlException('XML invalido ou mal-formado', cause: e);
  }

  // O Padrao TISS preve no maximo UM <ans:hash>. Multiplos = documento
  // invalido -> rejeitar (nao adivinhar qual zerar).
  final hashNodes = doc.descendants
      .whereType<XmlElement>()
      .where((e) =>
          e.name.local == _hashLocalName &&
          e.name.namespaceUri == tissNamespace)
      .toList(growable: false);
  if (hashNodes.length > 1) {
    throw InvalidTissXmlException(
      'multiplos <ans:hash> no documento '
      '(encontrados ${hashNodes.length}, esperado no maximo 1)',
    );
  }
  final XmlElement? hashNode = hashNodes.isEmpty ? null : hashNodes.first;

  // Concat dos textos de folha em ordem de documento, zerando <ans:hash>.
  final buffer = StringBuffer();
  for (final node in doc.descendants) {
    if (!_isLeafForHash(node)) continue;
    if (identical(node, hashNode)) {
      // Zerar conteudo: equivale a concatenar "".
      continue;
    }
    buffer.write(_leafText(node));
  }

  final digest = md5.convert(utf8.encode(buffer.toString()));
  return digest.toString(); // hexdigest minusculo, 32 chars.
}

/// Atalho conveniente: le o arquivo do disco e calcula [hashTiss].
///
/// Lanca [InvalidTissXmlException] se o XML for invalido.
Future<String> hashTissFile(String path) async {
  final bytes = await File(path).readAsBytes();
  return hashTiss(bytes);
}

// ---------------------------------------------------------------------------
// Internos
// ---------------------------------------------------------------------------

/// Decide se um no e "folha pro hash":
///   - aceita Element e Comment;
///   - "sem filhos" no sentido da referencia lxml: sem filhos
///     Element/Comment/PI. Filhos Text/CDATA NAO contam (TISS nao tem conteudo
///     misto, entao um elemento com so Text dentro e folha de valor).
bool _isLeafForHash(XmlNode node) {
  final type = node.nodeType;
  if (type != XmlNodeType.ELEMENT && type != XmlNodeType.COMMENT) {
    return false;
  }
  for (final child in node.children) {
    final ct = child.nodeType;
    if (ct == XmlNodeType.ELEMENT ||
        ct == XmlNodeType.COMMENT ||
        ct == XmlNodeType.PROCESSING) {
      return false;
    }
  }
  return true;
}

/// Texto de uma folha, equivalente ao `el.text` do lxml:
///   - Element: concat dos filhos Text/CDATA (entidades ja decodificadas).
///   - Comment: o conteudo entre `<!--` e `-->` (literal, sem decode).
///
/// Para um Comment, `innerText` do package:xml retorna "" (o texto fica em
/// `.value`), entao tratamos explicitamente.
String _leafText(XmlNode node) {
  if (node is XmlComment) {
    return node.value;
  }
  // Element-folha: innerText concatena os Text/CDATA filhos.
  return node.innerText;
}

/// Normalizacao de fim-de-linha da spec XML 1.0 (secao 2.11): antes do parse,
/// toda sequencia `\r\n` (CRLF) e todo `\r` isolado (CR) sao traduzidos para um
/// unico `\n` (LF). Implementado em uma passada para nao alocar regex.
String _normalizeXmlEol(String s) {
  if (!s.contains('\r')) return s; // caminho rapido: sem CR, nada a fazer.
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s.codeUnitAt(i);
    if (ch == 0x0D) {
      // CR
      out.writeCharCode(0x0A); // -> LF
      // Engole o LF seguinte de um par CRLF.
      if (i + 1 < s.length && s.codeUnitAt(i + 1) == 0x0A) {
        i++;
      }
    } else {
      out.writeCharCode(ch);
    }
  }
  return out.toString();
}

/// Rejeita encodings fora de escopo (UTF-16 / UTF-32) por deteccao de BOM nos
/// bytes crus, ANTES de qualquer decode. Escopo suportado = ISO-8859-1 + UTF-8.
///
/// UTF-32 e checado ANTES de UTF-16 porque o BOM UTF-32-LE (`FF FE 00 00`) tem
/// o BOM UTF-16-LE (`FF FE`) como prefixo.
void _rejectUnsupportedEncoding(List<int> bytes) {
  if (bytes.length >= 4) {
    final b0 = bytes[0], b1 = bytes[1], b2 = bytes[2], b3 = bytes[3];
    final utf32le = b0 == 0xFF && b1 == 0xFE && b2 == 0x00 && b3 == 0x00;
    final utf32be = b0 == 0x00 && b1 == 0x00 && b2 == 0xFE && b3 == 0xFF;
    if (utf32le || utf32be) {
      throw const InvalidTissXmlException(
        'encoding UTF-32 nao suportado (escopo: ISO-8859-1, UTF-8)',
      );
    }
  }
  if (bytes.length >= 2) {
    final b0 = bytes[0], b1 = bytes[1];
    final utf16le = b0 == 0xFF && b1 == 0xFE;
    final utf16be = b0 == 0xFE && b1 == 0xFF;
    if (utf16le || utf16be) {
      throw const InvalidTissXmlException(
        'encoding UTF-16 nao suportado (escopo: ISO-8859-1, UTF-8)',
      );
    }
  }
}

/// Decodifica bytes do XML para uma `String` Unicode que o `package:xml` possa
/// parsear.
///
/// Estrategia (espelha o port Node):
///   1. Strippa BOM UTF-8 (`EF BB BF`) se presente.
///   2. Inspeciona ~200 bytes ASCII do prologo procurando declaracao
///      `encoding="iso-8859-1"` (case-insensitive, aspas simples ou duplas).
///   3. Se ISO-8859-1: decodifica latin1 (cada byte 0x00..0xFF vira o codepoint
///      Unicode correspondente; mapping bijetivo) e reescreve a declaracao
///      `encoding=` para `utf-8` (a String resultante ja e Unicode puro, o
///      parser nao deve mais ver "iso-8859-1").
///   4. Caso contrario: assume UTF-8.
String _decodeXmlBytes(List<int> bytes) {
  var view = bytes;
  // Strip BOM UTF-8.
  if (view.length >= 3 &&
      view[0] == 0xEF &&
      view[1] == 0xBB &&
      view[2] == 0xBF) {
    view = view.sublist(3);
  }

  // Inspeciona o prologo em latin1 (ASCII-safe) pra achar a declaracao.
  final headLen = view.length < 200 ? view.length : 200;
  final head = latin1.decode(view.sublist(0, headLen)).toLowerCase();
  final isIso = head.contains('encoding="iso-8859-1"') ||
      head.contains("encoding='iso-8859-1'");

  if (isIso) {
    final decoded = latin1.decode(view);
    // Reescreve a declaracao pra utf-8 (conteudo agora e Unicode puro).
    return decoded.replaceFirst(
      RegExp(r'''encoding=(['"])iso-8859-1\1''', caseSensitive: false),
      'encoding="utf-8"',
    );
  }

  // Assume UTF-8 (ASCII e subset). allowMalformed=false: bytes invalidos
  // no encoding declarado disparam FormatException, que o chamador converte.
  try {
    return utf8.decode(view);
  } on FormatException catch (e) {
    throw InvalidTissXmlException(
      'bytes invalidos no encoding declarado (UTF-8)',
      cause: e,
    );
  }
}
