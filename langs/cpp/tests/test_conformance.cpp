// test_conformance.cpp - roda os vetores canonicos contra HashTissFile().
//
// Vetores POSITIVOS (expect_error == false): compara byte-a-byte com o hash
// esperado de conformance/vectors.json.
// Vetores NEGATIVOS (expect_error == true): o port DEVE lancar
// tiss_hash::InvalidTissXml (ex: multiplos <ans:hash>, encoding UTF-16/32).
//
// Uso:
//   test_conformance --inputs <dir>     # custom inputs dir
//   test_conformance                     # usa default ../../../conformance/inputs
//
// Plus os args nativos do doctest (--test-case, --reporters, etc).

// Fornecemos main() proprio (parsing de --inputs), entao usar IMPLEMENT
// (sem WITH_MAIN).
#define DOCTEST_CONFIG_IMPLEMENT
#include "doctest.h"

#include "test_vectors.hpp"
#include "tiss_hash/tiss_hash.hpp"

#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>
#include <vector>

namespace {

// Path para o diretorio de inputs. Resolvido em ResolveInputsDir() no
// inicio dos testes (primeira fonte disponivel vence):
//   1. CLI --inputs <dir>        (se fornecido pelo runner; ex.: ctest)
//   2. env TISS_CONFORMANCE_DIR  (robusto a CWD; nome canonico)
//   3. env TISS_INPUTS_DIR       (alias retrocompativel)
//   4. ../../../conformance/inputs relativo ao CWD do binario (default)
std::filesystem::path g_inputs_dir;

std::filesystem::path ResolveInputsDir(int argc, const char* const* argv) {
    for (int i = 1; i < argc - 1; ++i) {
        if (std::strcmp(argv[i], "--inputs") == 0) {
            return std::filesystem::path{argv[i + 1]};
        }
    }
    if (const char* env = std::getenv("TISS_CONFORMANCE_DIR");
        env != nullptr && env[0] != '\0') {
        return std::filesystem::path{env};
    }
    if (const char* env = std::getenv("TISS_INPUTS_DIR");
        env != nullptr && env[0] != '\0') {
        return std::filesystem::path{env};
    }
    return std::filesystem::path{"../../../conformance/inputs"};
}

}  // namespace

TEST_CASE("conformance: vetores TISS/ANS (positivos batem hash; negativos rejeitam)") {
    REQUIRE_MESSAGE(std::filesystem::is_directory(g_inputs_dir),
                    "inputs dir nao existe: " << g_inputs_dir.string());

    // doctest re-executa o TEST_CASE inteiro uma vez por SUBCASE alcancado;
    // contadores no escopo do TEST_CASE NAO somam globalmente. Confiamos no
    // sumario final do doctest ([doctest] assertions: X/Y passed).
    for (const auto& v : kTissVectors) {
        const std::filesystem::path path =
            g_inputs_dir / std::string{v.id};

        SUBCASE(std::string{v.id}.c_str()) {
            CAPTURE(path.string());

            if (v.expect_error) {
                // Vetor NEGATIVO: deve lancar InvalidTissXml, nao hashear.
                CHECK_THROWS_AS((void)tiss_hash::HashTissFile(path),
                                tiss_hash::InvalidTissXml);
            } else {
                CAPTURE(v.expected_md5);
                std::string got;
                REQUIRE_NOTHROW(got = tiss_hash::HashTissFile(path));
                CHECK_EQ(got, std::string{v.expected_md5});
            }
        }
    }
}

TEST_CASE("API HashTiss(string_view) bate com HashTissFile()") {
    REQUIRE_MESSAGE(std::filesystem::is_directory(g_inputs_dir),
                    "inputs dir nao existe: " << g_inputs_dir.string());

    // Usa o syn_minimal.xml como sanity check do overload string_view.
    const std::filesystem::path path = g_inputs_dir / "syn_minimal.xml";
    REQUIRE(std::filesystem::is_regular_file(path));

    std::ifstream fh(path, std::ios::binary);
    REQUIRE(fh.good());
    std::string content((std::istreambuf_iterator<char>(fh)),
                        std::istreambuf_iterator<char>());

    const std::string h_view = tiss_hash::HashTiss(content);
    const std::string h_file = tiss_hash::HashTissFile(path);
    CHECK_EQ(h_view, h_file);
    CHECK_EQ(h_view.size(), tiss_hash::kHashHexLen);
}

TEST_CASE("API: XML invalido lanca InvalidTissXml") {
    // Lambda absorve o retorno [[nodiscard]] sem warning de -Wunused-result.
    auto call_malformed = []() {
        (void)tiss_hash::HashTiss(std::string_view{"<not-closed"});
    };
    auto call_empty = []() {
        (void)tiss_hash::HashTiss(std::string_view{""});
    };
    CHECK_THROWS_AS(call_malformed(), tiss_hash::InvalidTissXml);
    CHECK_THROWS_AS(call_empty(), tiss_hash::InvalidTissXml);
}

int main(int argc, char** argv) {
    g_inputs_dir = ResolveInputsDir(argc, argv);

    // Filtrar --inputs <dir> antes de passar pro doctest (que nao conhece).
    std::vector<char*> filtered;
    filtered.reserve(static_cast<std::size_t>(argc));
    for (int i = 0; i < argc; ++i) {
        if (std::strcmp(argv[i], "--inputs") == 0 && i + 1 < argc) {
            ++i;
            continue;
        }
        filtered.push_back(argv[i]);
    }

    doctest::Context ctx;
    ctx.applyCommandLine(static_cast<int>(filtered.size()), filtered.data());
    return ctx.run();
}
