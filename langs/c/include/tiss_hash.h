/*
 * tiss_hash.h - Port C do hash MD5 do epilogo XML TISS/ANS.
 *
 * Spec canonica: docs/SPEC.md (raiz do repositorio).
 * Referencia executavel: conformance/reference.py (Python + lxml).
 * 15 ambiguidades canonicas: conformance/AMBIGUITY_NOTES.md.
 *
 * Algoritmo (resumo):
 *   1. Parse do XML (libxml2, hardened contra XXE).
 *   2. Zerar conteudo do primeiro <ans:hash> (namespace TISS).
 *   3. Concatenar texto de cada NO-FOLHA (Element ou Comment sem filhos
 *      Element/Comment/PI), em ordem de documento.
 *   4. MD5 dos bytes UTF-8 da string concatenada.
 *   5. Devolver hex lowercase, 32 caracteres + NUL.
 *
 * Encoding: o arquivo declara geralmente iso-8859-1, mas libxml2 normaliza
 * tudo pra UTF-8 internamente. O MD5 e SEMPRE sobre bytes UTF-8 — NAO
 * ISO-8859-1, apesar do manual TISS. Ver ambiguidade #1.
 *
 * Thread-safety:
 *   - As funcoes da API podem ser chamadas concorrentemente em threads
 *     diferentes (DOM nao compartilhado entre chamadas).
 *   - A inicializacao do parser libxml2 e feita via `pthread_once`
 *     (Linux/macOS) na primeira chamada; caller nao precisa fazer nada.
 *   - Se voce ja inicializou libxml2 no processo (`xmlInitParser`) antes
 *     de usar esta lib, tudo bem — `xmlInitParser` e idempotente.
 *
 * Licenca: MIT.
 */
#ifndef TISS_HASH_H
#define TISS_HASH_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Namespace XML do Padrao TISS/ANS. */
#define TISS_HASH_NAMESPACE "http://www.ans.gov.br/padroes/tiss/schemas"

/* Tamanho do buffer de saida: 32 hex + '\0'. */
#define TISS_HASH_HEX_LEN 33

/* Codigos de retorno. */
typedef enum {
    TISS_HASH_OK              = 0, /* sucesso */
    TISS_HASH_ERR_INVALID_XML = 1, /* XML mal-formado / rejeitado pelo parser */
    TISS_HASH_ERR_IO          = 2, /* falha de I/O ao ler arquivo */
    TISS_HASH_ERR_ALLOC       = 3, /* malloc/realloc falhou */
    TISS_HASH_ERR_ARG         = 4  /* argumento invalido (ex.: NULL) */
} tiss_hash_status_t;

/*
 * Calcula MD5 hex (lowercase, 32 chars + NUL) do XML em bytes brutos.
 *
 * Parametros:
 *   xml      - ponteiro pros bytes do XML. NAO pode ser NULL.
 *   len      - tamanho em bytes do buffer xml. Deve ser > 0.
 *   out_hex  - buffer de saida com pelo menos TISS_HASH_HEX_LEN bytes.
 *              No retorno OK, contera 32 caracteres hex + '\0' terminator.
 *
 * Retorno:
 *   TISS_HASH_OK em sucesso. Em erro, conteudo de out_hex e indefinido.
 */
tiss_hash_status_t tiss_hash_bytes(const unsigned char *xml,
                                   size_t len,
                                   char out_hex[TISS_HASH_HEX_LEN]);

/*
 * Le arquivo XML do disco e calcula o hash.
 *
 * Parametros:
 *   path     - caminho do arquivo (NUL-terminated). NAO pode ser NULL.
 *   out_hex  - buffer de saida, conforme tiss_hash_bytes.
 */
tiss_hash_status_t tiss_hash_file(const char *path,
                                  char out_hex[TISS_HASH_HEX_LEN]);

/*
 * Descricao legivel do codigo de status. Nunca retorna NULL.
 * String estatica (nao precisa free).
 */
const char *tiss_hash_strerror(tiss_hash_status_t s);

/*
 * Versao da biblioteca (semver, string literal estatica).
 */
const char *tiss_hash_version(void);

#ifdef __cplusplus
}
#endif

#endif /* TISS_HASH_H */
