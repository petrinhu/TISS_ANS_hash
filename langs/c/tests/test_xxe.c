/*
 * test_xxe.c - regressao de seguranca: XXE (XML External Entity).
 *
 * Achado A-SEC1 da auditoria bigtech 2026-05-28: XML_PARSE_NONET nao
 * bloqueia `file://`; com XML_PARSE_NOENT, um DOCTYPE com entidade
 * externa SYSTEM "file:///..." vazava o conteudo do arquivo local pro
 * concat hashed. Fix: deny_external_entity_loader registrado na init.
 *
 * Este teste cria um arquivo-segredo temporario, monta um payload XXE
 * que tenta inje-lo via &xxe;, e verifica que o segredo NAO entra no
 * hash. Estrategia: o hash do payload-XXE deve ser IGUAL ao hash de um
 * payload de controle onde o mesmo elemento tem valor vazio. Se a
 * entidade externa fosse resolvida, o conteudo do arquivo entraria no
 * concat e os hashes divergiriam.
 *
 * Exit code: 0 = XXE bloqueado (seguro); 1 = vazamento ou erro de setup.
 */

/* mkstemp/fdopen exigem POSIX sob -std=c11 -Wpedantic. */
#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "tiss_hash.h"

#define NS "xmlns:ans=\"http://www.ans.gov.br/padroes/tiss/schemas\""

static const char *SECRET = "SEGREDO_XXE_NAO_DEVE_VAZAR_9f3a2b";

int main(void)
{
    /* 1. Cria arquivo-segredo temporario. */
    char secret_path[] = "/tmp/tiss_xxe_secret_XXXXXX";
    int fd = mkstemp(secret_path);
    if (fd < 0) {
        fprintf(stderr, "[ERRO] mkstemp falhou\n");
        return 1;
    }
    {
        FILE *f = fdopen(fd, "w");
        if (!f) { fprintf(stderr, "[ERRO] fdopen\n"); return 1; }
        fputs(SECRET, f);
        fclose(f);
    }

    /* 2. Payload XXE: tenta injetar o arquivo via entidade externa. */
    char payload[2048];
    int n = snprintf(payload, sizeof(payload),
        "<?xml version='1.0' encoding='iso-8859-1'?>\n"
        "<!DOCTYPE ans:mensagemTISS [<!ENTITY xxe SYSTEM \"file://%s\">]>\n"
        "<ans:mensagemTISS %s>\n"
        "  <ans:cabecalho>\n"
        "    <ans:observacao>&xxe;</ans:observacao>\n"
        "  </ans:cabecalho>\n"
        "  <ans:epilogo>\n"
        "    <ans:hash></ans:hash>\n"
        "  </ans:epilogo>\n"
        "</ans:mensagemTISS>",
        secret_path, NS);
    if (n < 0 || (size_t)n >= sizeof(payload)) {
        fprintf(stderr, "[ERRO] payload truncado\n");
        remove(secret_path);
        return 1;
    }

    /* 3. Payload de controle: mesma estrutura, valor vazio (sem entidade). */
    const char *control =
        "<?xml version='1.0' encoding='iso-8859-1'?>\n"
        "<ans:mensagemTISS " NS ">\n"
        "  <ans:cabecalho>\n"
        "    <ans:observacao></ans:observacao>\n"
        "  </ans:cabecalho>\n"
        "  <ans:epilogo>\n"
        "    <ans:hash></ans:hash>\n"
        "  </ans:epilogo>\n"
        "</ans:mensagemTISS>";

    char hash_xxe[TISS_HASH_HEX_LEN];
    char hash_ctl[TISS_HASH_HEX_LEN];

    tiss_hash_status_t rc_xxe = tiss_hash_bytes(
        (const unsigned char *)payload, strlen(payload), hash_xxe);
    tiss_hash_status_t rc_ctl = tiss_hash_bytes(
        (const unsigned char *)control, strlen(control), hash_ctl);

    remove(secret_path);

    /* Aceitavel: parse do payload XXE falhar (entidade nao resolvida ->
     * libxml2 pode rejeitar). Isso tambem e seguro. */
    if (rc_xxe != TISS_HASH_OK) {
        fprintf(stdout,
            "[PASS] payload XXE rejeitado no parse (rc=%s) — seguro\n",
            tiss_hash_strerror(rc_xxe));
        return 0;
    }

    if (rc_ctl != TISS_HASH_OK) {
        fprintf(stderr, "[ERRO] controle falhou no parse: %s\n",
                tiss_hash_strerror(rc_ctl));
        return 1;
    }

    /* Payload XXE parseou. Seguro SE o hash bate com o controle de valor
     * vazio (entidade contribuiu nada). Divergencia = vazamento. */
    if (strcmp(hash_xxe, hash_ctl) == 0) {
        fprintf(stdout,
            "[PASS] entidade externa nao resolvida (hash == controle vazio)\n"
            "  hash: %s\n", hash_xxe);
        return 0;
    }

    fprintf(stderr,
        "[FAIL] XXE VAZOU: hash do payload diverge do controle vazio\n"
        "  xxe:      %s\n"
        "  controle: %s\n"
        "  -> conteudo do arquivo local entrou no concat hashed\n",
        hash_xxe, hash_ctl);
    return 1;
}
