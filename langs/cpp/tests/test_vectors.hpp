// GERADO AUTOMATICAMENTE - NAO EDITAR.
// Fonte: conformance/vectors.json
// Gerador: langs/cpp/tools/gen_test_vectors.py
//
// Re-gerar:
//   python3 langs/cpp/tools/gen_test_vectors.py

#pragma once

#include <array>
#include <string_view>

struct TissVector {
    std::string_view id;
    std::string_view expected_md5;  // vazio quando expect_error == true
    bool expect_error;
};

inline constexpr std::array<TissVector, 20> kTissVectors {{
    TissVector{"syn_minimal.xml", "3aa0c578c95cdb861a125f480a8a4de5", false},
    TissVector{"syn_acento.xml", "a20afc9a89aadaa2179d03d225337662", false},
    TissVector{"syn_empty.xml", "e43622c19cad903e2abd678330b9d7ca", false},
    TissVector{"syn_crlf_value.xml", "4df6fcedd9ed44aa9741d70e10f06746", false},
    TissVector{"syn_multi_guia.xml", "0e1339fa27441b62c28e38267f10632d", false},
    TissVector{"syn_entidades_xml.xml", "b0d587961802b967dd4e6033dc659625", false},
    TissVector{"syn_cdata.xml", "9fe56c6419fc78dd26313d63834b877f", false},
    TissVector{"syn_comentario.xml", "2c934218fab50edb83f9c8902f30cdfd", false},
    TissVector{"syn_atributo_folha.xml", "7a811223bea501d2b307c9181de25fb3", false},
    TissVector{"syn_namespace_xsi.xml", "7691354564876cbd1f105bf85cb9abd0", false},
    TissVector{"syn_whitespace_puro.xml", "4b09417e46d92615764c81b434e3dd58", false},
    TissVector{"syn_leading_zero.xml", "a258e0ce23d683450961493351fa21b8", false},
    TissVector{"syn_iso8859_simbolos.xml", "f17145d66f22e7641a4ea466e4b8024b", false},
    TissVector{"syn_default_ns.xml", "3ad92bd5ebbf35364433b897d08bf23a", false},
    TissVector{"syn_sem_hash.xml", "710a997000c9780901be02fafe449c64", false},
    TissVector{"syn_entidade_numerica.xml", "aefea736f666cc84a68da21ff699dadc", false},
    TissVector{"syn_perf_grande.xml", "4ea0da5e9916827df848a3fcf661d3d7", false},
    TissVector{"syn_bom_utf8.xml", "47d20fe3f5bb21cba74e54e5292170ab", false},
    TissVector{"syn_multi_hash.xml", "", true},
    TissVector{"syn_utf16.xml", "", true},
}};
