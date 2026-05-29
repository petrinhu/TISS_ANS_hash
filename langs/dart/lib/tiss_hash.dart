/// tiss_hash — Hash MD5 do epilogo `<ans:hash>` em XMLs do **Padrao TISS/ANS**
/// (Troca de Informacoes em Saude Suplementar, regulamentado pela Agencia
/// Nacional de Saude Suplementar).
///
/// Port Dart da lib multi-linguagem
/// [`lib_hash_ans`](https://github.com/petrinhu/TISS_ANS_hash). Bate
/// byte-a-byte com a implementacao de referencia (`conformance/reference.py`)
/// nos vetores de `conformance/vectors.json`.
///
/// Uso basico:
/// ```dart
/// import 'dart:io';
/// import 'package:tiss_hash/tiss_hash.dart';
///
/// void main() async {
///   final md5 = hashTiss(File('lote.xml').readAsBytesSync());
///   print(md5); // ex.: 3aa0c578c95cdb861a125f480a8a4de5
///
///   final md5b = await hashTissFile('lote.xml');
/// }
/// ```
library;

export 'src/tiss_hash_base.dart'
    show hashTiss, hashTissFile, InvalidTissXmlException, tissNamespace;
