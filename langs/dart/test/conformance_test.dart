// Suite de conformidade do port Dart: roda os vetores de
// `conformance/vectors.json` e compara byte-a-byte com `expected_md5` da
// referencia Python (`conformance/reference.py`).
//
// Resolucao de caminhos via Platform.script (independe do CWD do runner).

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tiss_hash/tiss_hash.dart';

/// Resolve o diretorio `conformance/` subindo a partir do CWD (normalmente a
/// raiz do package `langs/dart` quando se roda `dart test`) ate achar um dir
/// `conformance/` irmao. Independe de onde o runner foi invocado.
Directory _conformanceDir() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final candidate = Directory('${dir.path}/conformance');
    if (candidate.existsSync() &&
        File('${candidate.path}/vectors.json').existsSync()) {
      return candidate;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break; // chegou na raiz do FS
    dir = parent;
  }
  throw StateError(
    'diretorio conformance/ nao encontrado subindo a partir de '
    '${Directory.current.path}; rode os testes dentro do checkout completo '
    'do repo lib_hash_ans.',
  );
}

void main() {
  final conformanceDir = _conformanceDir();
  final vectorsFile = File('${conformanceDir.path}/vectors.json');

  test('vectors.json existe no conformance/', () {
    expect(vectorsFile.existsSync(), isTrue,
        reason: 'vectors.json ausente: ${vectorsFile.path}');
  });

  final manifest =
      jsonDecode(vectorsFile.readAsStringSync()) as Map<String, dynamic>;
  final vectors = (manifest['vectors'] as List).cast<Map<String, dynamic>>();

  group('conformidade (vectors.json)', () {
    for (final vec in vectors) {
      final id = vec['id'] as String;
      final desc = vec['desc'] as String? ?? '';
      // Campo `expect`: ausente ou "hash" = POSITIVO (compara expected_md5);
      // "error" = NEGATIVO (port DEVE rejeitar, nao produzir hash).
      final isNegative = vec['expect'] == 'error';

      test('$id — $desc', () {
        final inputPath = '${conformanceDir.path}/${vec['input']}';
        final bytes = File(inputPath).readAsBytesSync();

        if (isNegative) {
          expect(
            () => hashTiss(bytes),
            throwsA(isA<InvalidTissXmlException>()),
            reason: 'vetor negativo $id deveria lancar InvalidTissXmlException',
          );
          return;
        }

        final got = hashTiss(bytes);
        expect(
          got,
          equals(vec['expected_md5']),
          reason: 'hash divergente para $id',
        );
      });
    }
  });

  group('API auxiliar', () {
    test('tissNamespace exporta a URI correta', () {
      expect(tissNamespace, 'http://www.ans.gov.br/padroes/tiss/schemas');
    });

    test('hashTissFile bate com hashTiss(bytes)', () async {
      final inputPath = '${conformanceDir.path}/inputs/syn_acento.xml';
      final fromFile = await hashTissFile(inputPath);
      final fromBytes = hashTiss(File(inputPath).readAsBytesSync());
      expect(fromFile, fromBytes);
      // Hash conhecido da referencia: prova UTF-8 nos bytes do MD5.
      expect(fromFile, 'a20afc9a89aadaa2179d03d225337662');
    });

    test('XML mal-formado lanca InvalidTissXmlException', () {
      final malformed = utf8.encode('<root><sem-fechar>');
      expect(
        () => hashTiss(malformed),
        throwsA(isA<InvalidTissXmlException>()),
      );
    });

    test('documento sem <ans:hash> e valido (concatena tudo)', () {
      final xml = utf8.encode(
        "<?xml version='1.0' encoding='utf-8'?>"
        '<ans:mensagemTISS xmlns:ans="$tissNamespace">'
        '<ans:cabecalho><ans:id>X</ans:id></ans:cabecalho>'
        '</ans:mensagemTISS>',
      );
      // Sem hash, so a folha <ans:id>X</ans:id> contribui -> MD5("X").
      expect(hashTiss(xml), '02129bb861061d1a052c592e2dc6b383');
    });

    test('namespace TISS como default (sem prefixo) localiza <hash>', () {
      // hash com namespace default deve ser zerado -> so folhas restantes contam.
      final xml = utf8.encode(
        "<?xml version='1.0' encoding='utf-8'?>"
        '<mensagemTISS xmlns="$tissNamespace">'
        '<epilogo><hash>LIXO</hash></epilogo>'
        '</mensagemTISS>',
      );
      // <hash> zerado, nenhuma outra folha -> MD5("").
      expect(hashTiss(xml), 'd41d8cd98f00b204e9800998ecf8427e');
    });

    test('comentario XML contribui ao concat (ambiguidade #2)', () {
      // Sem o comentario, hash seria MD5("") = d41d8cd9...
      final xml = utf8.encode(
        "<?xml version='1.0' encoding='utf-8'?>"
        '<ans:mensagemTISS xmlns:ans="$tissNamespace">'
        '<ans:cabecalho><!-- COMENTARIO --></ans:cabecalho>'
        '<ans:epilogo><ans:hash></ans:hash></ans:epilogo>'
        '</ans:mensagemTISS>',
      );
      expect(hashTiss(xml), isNot('d41d8cd98f00b204e9800998ecf8427e'));
    });
  });
}
