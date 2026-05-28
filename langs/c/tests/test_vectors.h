/*
 * GERADO AUTOMATICAMENTE — NAO EDITAR.
 * Fonte: conformance/vectors.json
 * Gerador: langs/c/tools/gen_test_vectors.py
 *
 * Re-gerar:
 *   python3 langs/c/tools/gen_test_vectors.py
 */
#ifndef TISS_TEST_VECTORS_H
#define TISS_TEST_VECTORS_H

typedef struct {
    const char *id;
    const char *expected_md5;
} tiss_vector_t;

static const tiss_vector_t TISS_VECTORS[] = {
    { "syn_minimal.xml", "3aa0c578c95cdb861a125f480a8a4de5" },
    { "syn_acento.xml", "a20afc9a89aadaa2179d03d225337662" },
    { "syn_empty.xml", "e43622c19cad903e2abd678330b9d7ca" },
    { "syn_crlf_value.xml", "4df6fcedd9ed44aa9741d70e10f06746" },
    { "syn_multi_guia.xml", "0e1339fa27441b62c28e38267f10632d" },
    { "syn_entidades_xml.xml", "b0d587961802b967dd4e6033dc659625" },
    { "syn_cdata.xml", "9fe56c6419fc78dd26313d63834b877f" },
    { "syn_comentario.xml", "2c934218fab50edb83f9c8902f30cdfd" },
    { "syn_atributo_folha.xml", "7a811223bea501d2b307c9181de25fb3" },
    { "syn_namespace_xsi.xml", "7691354564876cbd1f105bf85cb9abd0" },
    { "syn_whitespace_puro.xml", "4b09417e46d92615764c81b434e3dd58" },
    { "syn_leading_zero.xml", "a258e0ce23d683450961493351fa21b8" },
    { "syn_iso8859_simbolos.xml", "f17145d66f22e7641a4ea466e4b8024b" },
    { "syn_perf_grande.xml", "4ea0da5e9916827df848a3fcf661d3d7" },
    { "syn_bom_utf8.xml", "47d20fe3f5bb21cba74e54e5292170ab" },
};

#define TISS_VECTORS_COUNT (sizeof(TISS_VECTORS) / sizeof(TISS_VECTORS[0]))

#endif /* TISS_TEST_VECTORS_H */
