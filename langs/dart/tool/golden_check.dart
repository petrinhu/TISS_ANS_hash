// Validacao de GOLDENS REAIS (privados) do port Dart.
//
// PRIVACIDADE (LGPD): este script NUNCA imprime o hash, o conteudo do XML, a
// versao TISS, a operadora ou qualquer PII. Reporta apenas PASS/FAIL por
// arquivo. Os XMLs reais vivem FORA do repo (diretorio privado do mantenedor)
// e nunca devem ser commitados.
//
// Uso:
//   dart run tool/golden_check.dart [DIR_PRIVADO]
// Default DIR_PRIVADO = env TISS_PRIVATE_XMLS, ou o path conhecido do
// mantenedor. Espera real_envio1/2/3.xml + expected_hashes.json no diretorio.

import 'dart:convert';
import 'dart:io';

import 'package:tiss_hash/tiss_hash.dart';

Future<int> main(List<String> args) async {
  final dirPath = args.isNotEmpty
      ? args.first
      : (Platform.environment['TISS_PRIVATE_XMLS'] ??
          '/home/petrus/IDrive/Documentos/projetos_claudebrain/Projects/'
              '_private_tiss_real_xmls');

  final dir = Directory(dirPath);
  if (!dir.existsSync()) {
    stderr.writeln('SKIP: diretorio privado de goldens nao encontrado.');
    stderr
        .writeln('  (defina TISS_PRIVATE_XMLS ou passe o path como argumento)');
    return 0; // SKIP nao e falha: ambiente publico nao tem os reais.
  }

  final expectedFile = File('${dir.path}/expected_hashes.json');
  if (!expectedFile.existsSync()) {
    stderr.writeln('FAIL: expected_hashes.json ausente no diretorio privado.');
    return 1;
  }

  final expected =
      (jsonDecode(expectedFile.readAsStringSync()) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));

  var pass = 0;
  var fail = 0;
  // Ordem estavel pra saida deterministica.
  final names = expected.keys.toList()..sort();
  for (final name in names) {
    final f = File('${dir.path}/$name');
    if (!f.existsSync()) {
      stdout.writeln('FAIL  $name (arquivo ausente)');
      fail++;
      continue;
    }
    try {
      final got = hashTiss(f.readAsBytesSync());
      // Comparacao constante de intencao: igualdade simples basta; NUNCA
      // imprimimos `got` nem `expected[name]`.
      if (got == expected[name]) {
        stdout.writeln('PASS  $name');
        pass++;
      } else {
        stdout.writeln('FAIL  $name (hash divergente)');
        fail++;
      }
    } on InvalidTissXmlException {
      stdout.writeln('FAIL  $name (rejeitado pelo parser)');
      fail++;
    }
  }

  stdout.writeln('---');
  stdout.writeln('goldens: $pass PASS / $fail FAIL (de ${names.length})');
  return fail == 0 ? 0 : 1;
}
