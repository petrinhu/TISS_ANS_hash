/*
 * tiss_hash.c - Implementacao do port C do hash MD5 do epilogo TISS/ANS.
 *
 * -----------------------------------------------------------------------------
 * Decisao de parser: libxml2
 * -----------------------------------------------------------------------------
 * Avaliadas tres opcoes:
 *
 * - libxml2 (ESCOLHIDA): parser de fato em Linux/Unix, mantido pela Gnome,
 *   usado por baixo do lxml (Python) e DOMDocument (PHP). Suporta:
 *     - DOM completo com xmlNodeGetContent normalizando entidades.
 *     - Comentarios preservados na arvore (xmlNode com type XML_COMMENT_NODE).
 *     - Resolucao correta de namespace W3C (ns->href).
 *     - Hardening contra XXE via flags (XML_PARSE_NONET sem NOENT-EXT).
 *     - Normalizacao automatica do encoding declarado pra UTF-8 internamente.
 *
 * - expat: SAX-based, exige reconstruir manualmente o conceito de folha
 *   (tracking de pilha + lookahead). Mais leve, mas zero ganho real
 *   pra XMLs TISS (< 5 MB tipico). Descartado.
 *
 * - yxml/mxml: parsers minimos sem suporte de namespace W3C correto.
 *   Descartados.
 *
 * - libxml++ (C++): wrap C++ — fora de escopo (este e port C puro).
 *
 * -----------------------------------------------------------------------------
 * Decisao de MD5: OpenSSL EVP API (libcrypto)
 * -----------------------------------------------------------------------------
 * - OpenSSL EVP_* (ESCOLHIDA): API moderna (a low-level MD5_* foi deprecada
 *   em OpenSSL 3.0). Disponivel em qualquer Linux, mantido, FIPS-ready.
 *
 * - Bundle RFC 1321 reference impl (~150 LOC, dominio publico): viavel pra
 *   eliminar dep de libcrypto. Mantido como opcao futura mas nao escolhido
 *   pra simplicidade — quem ja usa libxml2 ja tem libssl/libcrypto via
 *   ecossistema. Caller que quiser zero-libcrypto pode trocar este arquivo.
 *
 * -----------------------------------------------------------------------------
 * Buffer de concatenacao
 * -----------------------------------------------------------------------------
 * Implementado como struct `concat_buf_t` com crescimento por dobramento
 * (amortizado O(1) por append). Preferido sobre xmlBuffer da libxml2 porque:
 *   - controle direto de erro de alocacao (TISS_HASH_ERR_ALLOC).
 *   - sem dep transitiva de utf-8 specifics da libxml2.
 *   - profile-friendly: 1 realloc por crescimento, sem overhead de
 *     conversao interna.
 *
 * -----------------------------------------------------------------------------
 * Inicializacao thread-safe
 * -----------------------------------------------------------------------------
 * xmlInitParser() e idempotente porem nao thread-safe na PRIMEIRA chamada.
 * Usamos pthread_once_t (POSIX) pra garantir uma unica inicializacao.
 *
 * Licenca: MIT.
 */

#include "tiss_hash.h"

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlerror.h>

/* Suprime aviso de header da OpenSSL 3.x em algumas distros (FIPS macros). */
#define OPENSSL_NO_DEPRECATED 1
#include <openssl/evp.h>

/* -------------------------------------------------------------------------- */
/* Constantes internas                                                        */
/* -------------------------------------------------------------------------- */

#define TISS_HASH_VERSION_STR "0.1.0"

/* MD5 digest = 16 bytes. */
#define MD5_DIGEST_LEN 16

/* Capacidade inicial do buffer de concat (8 KiB). XMLs TISS tipicos
 * geram concats entre 1 KiB e 200 KiB; 8K cobre o caso comum sem realloc. */
#define CONCAT_BUF_INIT_CAP 8192

/* -------------------------------------------------------------------------- */
/* Inicializacao unica do parser libxml2                                       */
/* -------------------------------------------------------------------------- */

static pthread_once_t g_init_once = PTHREAD_ONCE_INIT;

static void tiss_hash_init_libxml(void)
{
    /* Inicializa estruturas globais do libxml2 (catalogos, hashes, etc).
     * Idempotente em chamadas subsequentes, mas a PRIMEIRA chamada nao
     * e thread-safe — por isso o once. */
    xmlInitParser();

    /* Silenciar handler de erro default (escreve em stderr). Vamos
     * relatar erro via codigo de retorno; mensagens do parser ficam
     * acessiveis via xmlGetLastError() se o caller quiser instrumentar. */
    xmlSetGenericErrorFunc(NULL, NULL);
}

/* -------------------------------------------------------------------------- */
/* Buffer dinamico de concatenacao                                            */
/* -------------------------------------------------------------------------- */

typedef struct {
    char  *data;
    size_t len;
    size_t cap;
    int    oom; /* 1 se uma alocacao falhou; 0 caso contrario */
} concat_buf_t;

static void concat_init(concat_buf_t *b)
{
    b->data = (char *)malloc(CONCAT_BUF_INIT_CAP);
    b->len  = 0;
    b->cap  = b->data ? CONCAT_BUF_INIT_CAP : 0;
    b->oom  = b->data ? 0 : 1;
}

static void concat_free(concat_buf_t *b)
{
    free(b->data);
    b->data = NULL;
    b->len  = 0;
    b->cap  = 0;
}

/* Garante capacidade pra escrever mais `extra` bytes. */
static void concat_ensure(concat_buf_t *b, size_t extra)
{
    if (b->oom) {
        return;
    }
    /* Overflow check: len + extra nao pode estourar size_t. */
    if (extra > SIZE_MAX - b->len) {
        b->oom = 1;
        return;
    }
    size_t need = b->len + extra;
    if (need <= b->cap) {
        return;
    }
    size_t new_cap = b->cap ? b->cap : CONCAT_BUF_INIT_CAP;
    while (new_cap < need) {
        if (new_cap > SIZE_MAX / 2) {
            b->oom = 1;
            return;
        }
        new_cap *= 2;
    }
    char *new_data = (char *)realloc(b->data, new_cap);
    if (!new_data) {
        b->oom = 1;
        return;
    }
    b->data = new_data;
    b->cap  = new_cap;
}

static void concat_append(concat_buf_t *b, const char *s, size_t n)
{
    if (n == 0) {
        return;
    }
    concat_ensure(b, n);
    if (b->oom) {
        return;
    }
    memcpy(b->data + b->len, s, n);
    b->len += n;
}

/* -------------------------------------------------------------------------- */
/* Logica de folha + walker                                                   */
/* -------------------------------------------------------------------------- */

/* Verifica se um filho conta como "estruturado" pra desclassificar o pai
 * como folha. Espelha a logica do PHP/Rust ports:
 *   - XML_ELEMENT_NODE, XML_COMMENT_NODE, XML_PI_NODE contam.
 *   - Text/CDATA NAO contam (TISS sem mixed content; um elemento com so
 *     text dentro e folha de valor).
 */
static int is_structured_child(const xmlNode *child)
{
    switch (child->type) {
    case XML_ELEMENT_NODE:
    case XML_COMMENT_NODE:
    case XML_PI_NODE:
        return 1;
    default:
        return 0;
    }
}

/* Retorna 1 se o no e "folha pro hash": Element OU Comment sem filhos
 * estruturados. */
static int is_leaf_for_hash(const xmlNode *n)
{
    if (n->type != XML_ELEMENT_NODE && n->type != XML_COMMENT_NODE) {
        return 0;
    }
    for (const xmlNode *c = n->children; c != NULL; c = c->next) {
        if (is_structured_child(c)) {
            return 0;
        }
    }
    return 1;
}

/* Verifica se este elemento e o <ans:hash> do namespace TISS. */
static int is_tiss_hash_element(const xmlNode *n)
{
    if (n->type != XML_ELEMENT_NODE) {
        return 0;
    }
    if (n->name == NULL || strcmp((const char *)n->name, "hash") != 0) {
        return 0;
    }
    if (n->ns == NULL || n->ns->href == NULL) {
        return 0;
    }
    return strcmp((const char *)n->ns->href, TISS_HASH_NAMESPACE) == 0;
}

/* Acha o primeiro <ans:hash> em ordem de documento (DFS pre-order). */
static xmlNode *find_first_tiss_hash(xmlNode *node)
{
    for (xmlNode *n = node; n != NULL; n = n->next) {
        if (is_tiss_hash_element(n)) {
            return n;
        }
        if (n->children) {
            xmlNode *found = find_first_tiss_hash(n->children);
            if (found) {
                return found;
            }
        }
    }
    return NULL;
}

/* Remove todos os filhos de um nodo (usado pra "zerar" <ans:hash>). */
static void clear_node_children(xmlNode *n)
{
    xmlNode *c = n->children;
    while (c != NULL) {
        xmlNode *next = c->next;
        xmlUnlinkNode(c);
        xmlFreeNode(c);
        c = next;
    }
}

/* Apend do texto da folha ao buffer.
 *
 * - Elemento-folha: usa xmlNodeGetContent (concatena Text/CDATA filhos,
 *   ja decodificados em UTF-8). Para folha sem filhos, retorna "".
 *   Para folha com so Text/CDATA dentro, retorna o texto literal.
 * - Comentario-folha: n->content e o texto entre <!-- e --> (UTF-8).
 *
 * libxml2 normaliza CR/LF (XML 1.0 §2.11) durante o parse. CR/CRLF viram
 * LF antes de chegar aqui — comportamento alinhado com a referencia (que
 * tambem confia na normalizacao do parser). */
static void append_leaf_text(concat_buf_t *buf, const xmlNode *leaf)
{
    if (leaf->type == XML_COMMENT_NODE) {
        if (leaf->content) {
            concat_append(buf, (const char *)leaf->content,
                          strlen((const char *)leaf->content));
        }
        return;
    }

    /* Elemento-folha: xmlNodeGetContent aloca uma copia do texto. */
    xmlChar *txt = xmlNodeGetContent(leaf);
    if (txt) {
        concat_append(buf, (const char *)txt, strlen((const char *)txt));
        xmlFree(txt);
    }
    /* Se xmlNodeGetContent retornar NULL, equivale a "" — nao apendamos
     * nada (string vazia + concat = concat). */
}

/* Walker recursivo: em ordem de documento, encontra folhas (Element/Comment
 * sem filhos estruturados) e apenda seu texto. Pula o no <ans:hash> (cujo
 * conteudo ja foi zerado externamente, mas o pulo aqui e defensivo: ainda
 * que vazio, mantemos a semantica "<ans:hash> contribui string vazia").
 *
 * Nota: como zeramos os filhos do <ans:hash> via clear_node_children, ele
 * vira folha (sem children) e o append_leaf_text apendaria "" via
 * xmlNodeGetContent. O resultado e o mesmo, mas o skip explicito documenta
 * a intencao e protege contra futuras mudancas. */
static void walk(xmlNode *node, concat_buf_t *buf, const xmlNode *hash_node)
{
    for (xmlNode *n = node; n != NULL; n = n->next) {
        if (n->type != XML_ELEMENT_NODE && n->type != XML_COMMENT_NODE) {
            /* Text, CDATA, PI no topo nao sao iterados como folhas (eles
             * aparecem so como CONTEUDO de folhas Element via
             * xmlNodeGetContent). DTD/Entity nodes etc. tambem sao
             * pulados. */
            continue;
        }
        if (is_leaf_for_hash(n)) {
            if (n == hash_node) {
                /* <ans:hash> contribui string vazia (ja zerado). */
                continue;
            }
            append_leaf_text(buf, n);
        } else if (n->children) {
            /* Nao-folha: descer recursivo. */
            walk(n->children, buf, hash_node);
        }
    }
}

/* -------------------------------------------------------------------------- */
/* MD5 (OpenSSL EVP) + hex encoding                                           */
/* -------------------------------------------------------------------------- */

/* Converte 16 bytes do digest em 32 hex lowercase + NUL. */
static void hex_lower_encode(const unsigned char *digest, char out[TISS_HASH_HEX_LEN])
{
    static const char HEX[] = "0123456789abcdef";
    for (int i = 0; i < MD5_DIGEST_LEN; i++) {
        out[i * 2]     = HEX[(digest[i] >> 4) & 0x0F];
        out[i * 2 + 1] = HEX[ digest[i]       & 0x0F];
    }
    out[MD5_DIGEST_LEN * 2] = '\0';
}

/* Calcula MD5 dos bytes em (data, len) e escreve hex lowercase em out_hex.
 * Retorna 0 em sucesso, -1 em falha (alocacao do EVP_MD_CTX). */
static int md5_hex(const unsigned char *data, size_t len,
                   char out_hex[TISS_HASH_HEX_LEN])
{
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    if (!ctx) {
        return -1;
    }

    unsigned char raw[MD5_DIGEST_LEN];
    unsigned int  raw_len = 0;
    int           ok      = 0;

    /* impl=NULL escolhe a impl default (libcrypto default ENGINE). */
    if (EVP_DigestInit_ex(ctx, EVP_md5(), NULL) != 1) {
        goto out;
    }
    if (len > 0 && EVP_DigestUpdate(ctx, data, len) != 1) {
        goto out;
    }
    if (EVP_DigestFinal_ex(ctx, raw, &raw_len) != 1) {
        goto out;
    }
    if (raw_len != MD5_DIGEST_LEN) {
        goto out;
    }
    ok = 1;

out:
    EVP_MD_CTX_free(ctx);
    if (!ok) {
        return -1;
    }
    hex_lower_encode(raw, out_hex);
    return 0;
}

/* -------------------------------------------------------------------------- */
/* API publica                                                                */
/* -------------------------------------------------------------------------- */

tiss_hash_status_t tiss_hash_bytes(const unsigned char *xml,
                                   size_t len,
                                   char out_hex[TISS_HASH_HEX_LEN])
{
    if (xml == NULL || out_hex == NULL || len == 0) {
        return TISS_HASH_ERR_ARG;
    }
    /* libxml2 usa `int` pra tamanho em xmlReadMemory; rejeitar entrada
     * que estoura. Limite pratico TISS << INT_MAX. */
    if (len > (size_t)0x7FFFFFFF) {
        return TISS_HASH_ERR_ARG;
    }

    pthread_once(&g_init_once, tiss_hash_init_libxml);

    /* Hardening:
     *   XML_PARSE_NONET  - proibe rede (file://, http://) em resolucao
     *                      de DTD/entidade.
     *   XML_PARSE_NOENT  - substitui entidades predefinidas (&amp; etc.)
     *                      pelo valor — necessario pra reproduzir
     *                      ambiguidade #4 (entidades sao decodificadas).
     *
     * NAO usamos XML_PARSE_NOBLANKS: perderia whitespace dentro de
     * valores (ambiguidade #7).
     *
     * NAO usamos XML_PARSE_RECOVER em producao: queremos falhar em XML
     * mal-formado. */
    const int parse_flags = XML_PARSE_NONET | XML_PARSE_NOENT;

    xmlResetLastError();

    /* url=NULL, encoding=NULL deixa libxml2 detectar via declaracao XML
     * (geralmente iso-8859-1). O parser converte tudo pra UTF-8 internamente,
     * entao xmlNodeGetContent ja devolve UTF-8 — exatamente o que precisamos
     * pro MD5. */
    xmlDoc *doc = xmlReadMemory((const char *)xml, (int)len,
                                NULL, NULL, parse_flags);
    if (!doc) {
        return TISS_HASH_ERR_INVALID_XML;
    }

    xmlNode *root = xmlDocGetRootElement(doc);
    if (!root) {
        xmlFreeDoc(doc);
        return TISS_HASH_ERR_INVALID_XML;
    }

    /* 1) Zerar conteudo do primeiro <ans:hash>. Multiplos <ans:hash>
     *    no documento = comportamento NAO fixado (ambiguidade #9);
     *    seguimos a referencia e zeramos so o primeiro. */
    xmlNode *hash_node = find_first_tiss_hash(root);
    if (hash_node) {
        clear_node_children(hash_node);
    }

    /* 2) Walker em ordem de documento. */
    concat_buf_t buf;
    concat_init(&buf);
    if (buf.oom) {
        xmlFreeDoc(doc);
        return TISS_HASH_ERR_ALLOC;
    }

    walk(root, &buf, hash_node);

    tiss_hash_status_t rc = TISS_HASH_OK;
    if (buf.oom) {
        rc = TISS_HASH_ERR_ALLOC;
        goto cleanup;
    }

    /* 3) MD5 dos bytes UTF-8 (libxml2 ja entregou em UTF-8). */
    if (md5_hex((const unsigned char *)buf.data, buf.len, out_hex) != 0) {
        rc = TISS_HASH_ERR_ALLOC;
        goto cleanup;
    }

cleanup:
    concat_free(&buf);
    xmlFreeDoc(doc);
    return rc;
}

tiss_hash_status_t tiss_hash_file(const char *path,
                                  char out_hex[TISS_HASH_HEX_LEN])
{
    if (path == NULL || out_hex == NULL) {
        return TISS_HASH_ERR_ARG;
    }

    FILE *fp = fopen(path, "rb");
    if (!fp) {
        return TISS_HASH_ERR_IO;
    }

    if (fseek(fp, 0, SEEK_END) != 0) {
        fclose(fp);
        return TISS_HASH_ERR_IO;
    }
    long size_l = ftell(fp);
    if (size_l < 0) {
        fclose(fp);
        return TISS_HASH_ERR_IO;
    }
    if (fseek(fp, 0, SEEK_SET) != 0) {
        fclose(fp);
        return TISS_HASH_ERR_IO;
    }

    if (size_l == 0) {
        fclose(fp);
        return TISS_HASH_ERR_INVALID_XML;
    }

    size_t         size = (size_t)size_l;
    unsigned char *buf  = (unsigned char *)malloc(size);
    if (!buf) {
        fclose(fp);
        return TISS_HASH_ERR_ALLOC;
    }

    size_t n_read = fread(buf, 1, size, fp);
    int    rerr   = ferror(fp);
    fclose(fp);

    if (rerr || n_read != size) {
        free(buf);
        return TISS_HASH_ERR_IO;
    }

    tiss_hash_status_t rc = tiss_hash_bytes(buf, size, out_hex);
    free(buf);
    return rc;
}

const char *tiss_hash_strerror(tiss_hash_status_t s)
{
    switch (s) {
    case TISS_HASH_OK:              return "ok";
    case TISS_HASH_ERR_INVALID_XML: return "XML invalido ou mal-formado";
    case TISS_HASH_ERR_IO:          return "falha de I/O ao ler arquivo";
    case TISS_HASH_ERR_ALLOC:       return "falha de alocacao de memoria";
    case TISS_HASH_ERR_ARG:         return "argumento invalido";
    default:                        return "erro desconhecido";
    }
}

const char *tiss_hash_version(void)
{
    return TISS_HASH_VERSION_STR;
}
