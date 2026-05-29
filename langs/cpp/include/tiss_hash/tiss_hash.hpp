// tiss_hash.hpp - API publica do port C++ da tiss-hash.
//
// Hash MD5 do epilogo <ans:hash> em XMLs do Padrao TISS/ANS.
//
// Algoritmo canonico (definido em conformance/reference.py):
//   1. Parse XML.
//   2. Zerar conteudo de <ans:hash>.
//   3. Concatenar .text de cada elemento-folha (sem filhos estruturados),
//      em ordem de documento. Comentarios XML tambem entram (ver
//      conformance/AMBIGUITY_NOTES.md item #2).
//   4. MD5 dos bytes UTF-8 da string concatenada.
//   5. hex lowercase, 32 chars.
//
// Encoding dos bytes pro MD5 = UTF-8 (NAO ISO-8859-1, apesar do manual).
//
// Licenca: MIT.

#pragma once

#include <cstddef>
#include <filesystem>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>

namespace tiss_hash {

// Namespace XSD do Padrao TISS/ANS. Usado pra localizar o <ans:hash>
// independente do prefixo declarado.
inline constexpr std::string_view kNamespace =
    "http://www.ans.gov.br/padroes/tiss/schemas";

inline constexpr std::string_view kVersion = "0.1.0";

// Tamanho do hash hex (32 chars; sem NUL pois retornamos std::string).
inline constexpr std::size_t kHashHexLen = 32;

// Erro de XML mal-formado ou input invalido (vazio, > INT_MAX bytes,
// erro estrutural). Mensagem em pt-br.
class InvalidTissXml : public std::runtime_error {
 public:
    using std::runtime_error::runtime_error;
};

// Calcula o hash MD5 hex (32 chars lowercase) do XML em bytes UTF-8/ISO-8859-1
// (pugixml detecta encoding pela declaracao XML).
//
// Lanca:
//   - InvalidTissXml se o XML estiver mal-formado, vazio ou > 2 GiB.
//   - std::bad_alloc em OOM.
//
// Thread-safe: a funcao nao mantem estado mutavel global.
[[nodiscard]] std::string HashTiss(std::span<const std::byte> xml);

// Overload pra std::string_view (conveniencia; equivalente ao span de bytes).
[[nodiscard]] std::string HashTiss(std::string_view xml);

// Le o arquivo em `path` e calcula o hash.
//
// Lanca:
//   - InvalidTissXml se XML mal-formado.
//   - std::ios_base::failure se IO falhar (path inexistente, sem permissao etc).
//   - std::bad_alloc em OOM.
[[nodiscard]] std::string HashTissFile(const std::filesystem::path& path);

}  // namespace tiss_hash
