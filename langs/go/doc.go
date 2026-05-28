// Package tisshash implementa o algoritmo canonico do hash MD5 do epilogo
// XML do Padrao TISS/ANS (saude suplementar Brasil).
//
// O algoritmo (resumo):
//
//  1. Parse do XML (UTF-8 ou ISO-8859-1, com ou sem BOM).
//  2. Zerar o conteudo de <ans:hash> (identificado por namespace TISS).
//  3. Concatenar o texto de cada NO-FOLHA (elemento ou comentario sem filhos
//     Element/Comment/PI), em ordem de documento.
//  4. MD5 dos bytes UTF-8 da string concatenada.
//  5. Hex lowercase, 32 caracteres.
//
// Spec completa: https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md
// Ambiguidades fixadas: conformance/AMBIGUITY_NOTES.md no repositorio.
//
// Esta implementacao bate byte-a-byte com a referencia Python
// (conformance/reference.py) nos 15 vetores publicos.
package tisshash
