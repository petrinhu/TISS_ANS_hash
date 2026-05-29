/*
 * test_conformance.c - roda os vetores canonicos de conformance contra
 *                       tiss_hash_file().
 *
 * Vetores POSITIVOS (expect_error=0): compara o hash byte-a-byte com
 * expected_md5. Vetores NEGATIVOS (expect_error=1): asevera que a funcao
 * sinaliza ERRO (rc != TISS_HASH_OK) e NAO produz hash — entrada fora do
 * escopo TISS (multiplos <ans:hash>, encoding UTF-16/UTF-32).
 *
 * Uso:
 *   test_conformance [inputs_dir]
 *
 * Resolucao do diretorio de inputs (primeira fonte disponivel vence):
 *   1. argv[1]                   (CLI explicito, ex.: ctest passa o path)
 *   2. env TISS_CONFORMANCE_DIR  (robusto a CWD: aponta pra conformance/inputs)
 *   3. ../../../conformance/inputs (default relativo ao CWD do binario)
 *
 * O fallback por env existe pra que rodar o binario fora do ctest (CWD
 * diferente de langs/c/build) nao quebre — basta exportar a env.
 *
 * Exit code:
 *   0  se todos os vetores passarem (PASS == TISS_VECTORS_COUNT)
 *   1  se qualquer um falhar, ou erro de setup
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "tiss_hash.h"
#include "test_vectors.h"

/* Tamanho maximo razoavel pro path completo (dir + "/" + filename + NUL). */
#define PATH_MAX_LEN 4096

static const char *DEFAULT_INPUTS_DIR = "../../../conformance/inputs";

static int run_one(const char *inputs_dir, const tiss_vector_t *v)
{
    char path[PATH_MAX_LEN];
    int  n = snprintf(path, sizeof(path), "%s/%s", inputs_dir, v->id);
    if (n < 0 || (size_t)n >= sizeof(path)) {
        fprintf(stderr, "[FAIL] %-32s path truncado\n", v->id);
        return 0;
    }

    char out[TISS_HASH_HEX_LEN];
    tiss_hash_status_t rc = tiss_hash_file(path, out);

    if (v->expect_error) {
        /* Vetor NEGATIVO: deve sinalizar erro, nao produzir hash. */
        if (rc == TISS_HASH_OK) {
            fprintf(stderr,
                "[FAIL] %-32s esperava REJEICAO, mas obteve hash: %s\n",
                v->id, out);
            return 0;
        }
        fprintf(stdout, "[PASS] %-32s rejeitado: %s\n",
                v->id, tiss_hash_strerror(rc));
        return 1;
    }

    /* Vetor POSITIVO: deve calcular e bater com expected_md5. */
    if (rc != TISS_HASH_OK) {
        fprintf(stderr, "[FAIL] %-32s erro: %s (path=%s)\n",
                v->id, tiss_hash_strerror(rc), path);
        return 0;
    }

    if (strcmp(out, v->expected_md5) != 0) {
        fprintf(stderr, "[FAIL] %-32s\n  esperado: %s\n  obtido:   %s\n",
                v->id, v->expected_md5, out);
        return 0;
    }

    fprintf(stdout, "[PASS] %-32s %s\n", v->id, out);
    return 1;
}

/* Resolve o diretorio de inputs: CLI > env TISS_CONFORMANCE_DIR > default. */
static const char *resolve_inputs_dir(int argc, char **argv)
{
    if (argc >= 2) {
        return argv[1];
    }
    const char *env = getenv("TISS_CONFORMANCE_DIR");
    if (env != NULL && env[0] != '\0') {
        return env;
    }
    return DEFAULT_INPUTS_DIR;
}

int main(int argc, char **argv)
{
    const char *inputs_dir = resolve_inputs_dir(argc, argv);

    fprintf(stdout, "tiss-hash conformance: rodando %zu vetores em %s\n",
            (size_t)TISS_VECTORS_COUNT, inputs_dir);
    fprintf(stdout, "lib version: %s\n\n", tiss_hash_version());

    size_t passed = 0;
    for (size_t i = 0; i < TISS_VECTORS_COUNT; i++) {
        if (run_one(inputs_dir, &TISS_VECTORS[i])) {
            passed++;
        }
    }

    fprintf(stdout, "\n%zu/%zu PASS\n", passed, (size_t)TISS_VECTORS_COUNT);
    return (passed == TISS_VECTORS_COUNT) ? 0 : 1;
}
