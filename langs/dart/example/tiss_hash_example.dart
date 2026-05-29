// Exemplo minimo de uso do port Dart da lib tiss_hash.
//
// Rode a partir de langs/dart/:
//   dart run example/tiss_hash_example.dart caminho/para/lote.xml

import 'dart:io';

import 'package:tiss_hash/tiss_hash.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('uso: dart run example/tiss_hash_example.dart <lote.xml>');
    exitCode = 64; // EX_USAGE
    return;
  }

  final path = args.first;
  try {
    // A partir de um caminho de arquivo (assincrono).
    final md5 = await hashTissFile(path);
    stdout.writeln('$md5  $path');

    // Equivalente sincrono a partir de bytes ja em memoria:
    final bytes = File(path).readAsBytesSync();
    assert(hashTiss(bytes) == md5);
  } on InvalidTissXmlException catch (e) {
    stderr.writeln('XML rejeitado: ${e.message}');
    exitCode = 65; // EX_DATAERR
  } on FileSystemException catch (e) {
    stderr.writeln('erro de I/O: ${e.message}');
    exitCode = 66; // EX_NOINPUT
  }
}
