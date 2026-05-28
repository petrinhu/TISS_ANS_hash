// tiss_hash.cpp - Implementacao do port C++ da tiss-hash.
//
// -----------------------------------------------------------------------------
// Decisao de parser: pugixml
// -----------------------------------------------------------------------------
// Avaliadas:
//
// - pugixml (ESCOLHIDA): header + 1 .cpp, popular no ecossistema C++ (pacote
//   nativo em Fedora/Debian/Arch). Vantagens:
//     - DOM completo com traversal in-document-order trivial.
//     - parse_comments expoe nodos de comentario (necessario pra
//       ambiguidade #2; default e descartar).
//     - parse_ws_pcdata preserva whitespace dentro de PCDATA (ambiguidade #7).
//     - Suporta encoding ISO-8859-1 e converte pra UTF-8 internamente
//       (xml_node::child_value devolve const char* UTF-8).
//     - Cross-validacao com o port C (libxml2) — engine totalmente diferente.
//   Limitacao tratada manualmente: pugixml NAO tem resolucao de namespace
//   W3C nativa. xml_node::name() devolve o nome com prefixo literal
//   ("ans:hash"). Identificamos <ans:hash> resolvendo xmlns:<prefix> pelos
//   ancestrais.
//
// - libxml2: descartado para nao replicar o port C (perde valor de
//   cross-parser).
// - TinyXML2: descartado (sem suporte real a namespaces / declaracoes xmlns).
// - Xerces-C++: descartado (overkill, build pesado).
// - Boost.PropertyTree: descartado (perde estrutura DOM e comentarios).
//
// -----------------------------------------------------------------------------
// Decisao de MD5: OpenSSL EVP (libcrypto)
// -----------------------------------------------------------------------------
// - OpenSSL EVP (ESCOLHIDA): mesma escolha do port C; API moderna (MD5_*
//   foi deprecada em OpenSSL 3.0). Disponivel em qualquer Linux.
//
// - Bundle RFC 1321 reference impl: viavel pra eliminar dep de libcrypto.
//   Nao escolhido pra simplicidade; quem precisar pode trocar este arquivo.
//
// Licenca: MIT.

#include "tiss_hash/tiss_hash.hpp"

#include <algorithm>
#include <array>
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <ios>
#include <memory>
#include <string>
#include <string_view>
#include <system_error>
#include <vector>

#include <pugixml.hpp>

// Em OpenSSL 3.x as macros legacy emitem deprecation; o EVP nao usa nada
// deprecado mas alguns headers herdam o aviso.
#define OPENSSL_NO_DEPRECATED 1
#include <openssl/evp.h>

namespace tiss_hash {

namespace {

// ----------------------------------------------------------------------------
// Strip de BOM UTF-8 (EF BB BF) — pugixml aceita, mas explicitamos pra
// alinhar com a referencia em qualquer cenario.
// ----------------------------------------------------------------------------
std::span<const std::byte> StripUtf8Bom(std::span<const std::byte> in) {
    constexpr std::array<std::byte, 3> kBom = {
        std::byte{0xEF}, std::byte{0xBB}, std::byte{0xBF}};
    if (in.size() >= kBom.size() &&
        std::equal(kBom.begin(), kBom.end(), in.begin())) {
        return in.subspan(kBom.size());
    }
    return in;
}

// ----------------------------------------------------------------------------
// Resolucao manual de namespace pra elementos pugixml.
//
// pugixml entrega node.name() como "prefix:local" (ou apenas "local" pra
// namespace default). Para identificar <ans:hash> independente do prefixo:
//
//   1. Quebrar name em (prefix, local).
//   2. Walk dos ancestrais (inclusive o proprio nodo) procurando o atributo
//      xmlns:<prefix> (ou xmlns="..." pra default ns). Primeiro match vence.
//   3. Comparar a URI resolvida com kNamespace E local com "hash".
// ----------------------------------------------------------------------------

// Quebra "prefix:local" em (prefix, local). Sem ':' -> prefix vazio.
std::pair<std::string_view, std::string_view> SplitQName(std::string_view qname) {
    const auto colon = qname.find(':');
    if (colon == std::string_view::npos) {
        return {std::string_view{}, qname};
    }
    return {qname.substr(0, colon), qname.substr(colon + 1)};
}

// Devolve a URI declarada no escopo do node pra um dado prefixo (vazio =
// default ns). std::nullopt-like via empty string_view ausente -> caller
// trata. Usamos string_view vazia como "nao encontrado".
std::string_view ResolveNamespaceUri(const pugi::xml_node& node,
                                     std::string_view prefix) {
    const std::string attr_name = prefix.empty()
                                      ? std::string{"xmlns"}
                                      : "xmlns:" + std::string{prefix};
    for (pugi::xml_node ancestor = node; ancestor;
         ancestor = ancestor.parent()) {
        if (ancestor.type() != pugi::node_element) {
            continue;
        }
        const pugi::xml_attribute attr = ancestor.attribute(attr_name.c_str());
        if (attr) {
            return std::string_view{attr.value()};
        }
    }
    return {};
}

// True se este elemento e <ans:hash> do namespace TISS, independente do
// prefixo declarado.
bool IsTissHashElement(const pugi::xml_node& node) {
    if (node.type() != pugi::node_element) {
        return false;
    }
    const auto [prefix, local] = SplitQName(std::string_view{node.name()});
    if (local != "hash") {
        return false;
    }
    return ResolveNamespaceUri(node, prefix) == kNamespace;
}

// ----------------------------------------------------------------------------
// Classificacao de folha
//
// "Folha pro hash" = node_element OU node_comment, sem filhos do tipo
// element/comment/pi. Text/CDATA NAO desclassificam.
// ----------------------------------------------------------------------------
bool IsStructuredChild(const pugi::xml_node& child) {
    switch (child.type()) {
        case pugi::node_element:
        case pugi::node_comment:
        case pugi::node_pi:
            return true;
        default:
            return false;
    }
}

bool IsLeafForHash(const pugi::xml_node& node) {
    if (node.type() != pugi::node_element &&
        node.type() != pugi::node_comment) {
        return false;
    }
    for (pugi::xml_node c = node.first_child(); c; c = c.next_sibling()) {
        if (IsStructuredChild(c)) {
            return false;
        }
    }
    return true;
}

// ----------------------------------------------------------------------------
// Acha o primeiro <ans:hash> em ordem de documento (DFS pre-order).
// ----------------------------------------------------------------------------
pugi::xml_node FindFirstTissHash(pugi::xml_node node) {
    for (pugi::xml_node n = node; n; n = n.next_sibling()) {
        if (IsTissHashElement(n)) {
            return n;
        }
        if (pugi::xml_node found = FindFirstTissHash(n.first_child()); found) {
            return found;
        }
    }
    return pugi::xml_node{};
}

// ----------------------------------------------------------------------------
// Apend do texto da folha. Para elemento-folha usamos child_value(), que
// concatena os Text/CDATA filhos (ja decodificados em UTF-8 pelo pugixml).
// Para comment-folha usamos value() (conteudo entre <!-- e -->).
// ----------------------------------------------------------------------------
void AppendLeafText(std::string& buf, const pugi::xml_node& leaf) {
    if (leaf.type() == pugi::node_comment) {
        const char* v = leaf.value();
        if (v) {
            buf.append(v);
        }
        return;
    }

    // Elemento-folha: child_value() devolve o primeiro PCDATA/CDATA filho.
    // Mas se existirem multiplos text children (raro em TISS, mas possivel
    // com CDATA + texto), precisamos concatenar todos.
    bool any_text = false;
    for (pugi::xml_node c = leaf.first_child(); c; c = c.next_sibling()) {
        if (c.type() == pugi::node_pcdata || c.type() == pugi::node_cdata) {
            const char* v = c.value();
            if (v) {
                buf.append(v);
                any_text = true;
            }
        }
    }
    (void)any_text;  // intencional: elemento vazio contribui "".
}

// ----------------------------------------------------------------------------
// Walker recursivo: emite folhas em ordem de documento (DFS pre-order).
// Pula o <ans:hash> (que ja foi "zerado" externamente; defensivo).
// ----------------------------------------------------------------------------
void Walk(pugi::xml_node node, std::string& buf,
          const pugi::xml_node& hash_node) {
    for (pugi::xml_node n = node; n; n = n.next_sibling()) {
        if (n.type() != pugi::node_element &&
            n.type() != pugi::node_comment) {
            // Text/CDATA/PI/etc. no topo nao iteram como folhas — text/CDATA
            // ja foram capturados via child_value() do pai-folha. PI e DTD
            // sao descartados (alinha com referencia, que itera so Element
            // e Comment via lxml).
            continue;
        }
        if (IsLeafForHash(n)) {
            if (n == hash_node) {
                continue;  // <ans:hash> contribui "" ao concat.
            }
            AppendLeafText(buf, n);
        } else if (pugi::xml_node first = n.first_child(); first) {
            Walk(first, buf, hash_node);
        }
    }
}

// ----------------------------------------------------------------------------
// "Zerar" o <ans:hash>: remover todos os filhos. Pos isso ele vira folha
// vazia; Walk pula explicitamente como defesa em profundidade.
// ----------------------------------------------------------------------------
void ClearNodeChildren(pugi::xml_node& node) {
    while (pugi::xml_node c = node.first_child()) {
        node.remove_child(c);
    }
}

// ----------------------------------------------------------------------------
// MD5 via OpenSSL EVP. RAII pra EVP_MD_CTX.
// ----------------------------------------------------------------------------
struct EvpMdCtxDeleter {
    void operator()(EVP_MD_CTX* p) const noexcept {
        if (p) {
            EVP_MD_CTX_free(p);
        }
    }
};
using EvpMdCtxPtr = std::unique_ptr<EVP_MD_CTX, EvpMdCtxDeleter>;

std::string Md5HexLower(const std::string& data) {
    EvpMdCtxPtr ctx{EVP_MD_CTX_new()};
    if (!ctx) {
        throw std::bad_alloc{};
    }

    if (EVP_DigestInit_ex(ctx.get(), EVP_md5(), nullptr) != 1) {
        throw InvalidTissXml{"OpenSSL: falha em EVP_DigestInit_ex"};
    }
    if (!data.empty()) {
        if (EVP_DigestUpdate(ctx.get(), data.data(), data.size()) != 1) {
            throw InvalidTissXml{"OpenSSL: falha em EVP_DigestUpdate"};
        }
    }

    std::array<unsigned char, EVP_MAX_MD_SIZE> raw{};
    unsigned int raw_len = 0;
    if (EVP_DigestFinal_ex(ctx.get(), raw.data(), &raw_len) != 1) {
        throw InvalidTissXml{"OpenSSL: falha em EVP_DigestFinal_ex"};
    }
    if (raw_len != 16U) {
        throw InvalidTissXml{"OpenSSL: digest MD5 com tamanho inesperado"};
    }

    static constexpr char kHex[] = "0123456789abcdef";
    std::string out(kHashHexLen, '\0');
    for (unsigned int i = 0; i < raw_len; ++i) {
        const auto b = raw[i];
        out[i * 2U]     = kHex[(b >> 4U) & 0x0FU];
        out[i * 2U + 1] = kHex[ b        & 0x0FU];
    }
    return out;
}

}  // namespace

// ----------------------------------------------------------------------------
// API publica
// ----------------------------------------------------------------------------

std::string HashTiss(std::span<const std::byte> xml) {
    if (xml.empty()) {
        throw InvalidTissXml{"XML vazio"};
    }
    // pugixml usa size_t mas a impl interna roda em buffers que precisam
    // caber em memoria; impomos limite pratico de 2 GiB.
    if (xml.size() > static_cast<std::size_t>(INT32_MAX)) {
        throw InvalidTissXml{"XML excede limite de 2 GiB"};
    }

    const auto stripped = StripUtf8Bom(xml);

    pugi::xml_document doc;
    // Flags:
    //  - parse_default: defaults sensatos (sem entidades externas, ja
    //    decodifica entidades predefinidas como &amp;).
    //  - parse_ws_pcdata: preserva whitespace puro dentro de PCDATA
    //    (necessario pra ambiguidade #7; sem isso <x>   </x> perderia
    //    os 3 espacos).
    //  - parse_comments: inclui comentarios no DOM (default e descartar;
    //    necessario pra ambiguidade #2).
    //
    // Seguranca: por default pugixml NAO resolve DTD externa nem entidades
    // externas. Nenhuma flag adicional necessaria pra hardening contra XXE.
    constexpr unsigned int kParseFlags =
        pugi::parse_default | pugi::parse_ws_pcdata | pugi::parse_comments;

    const pugi::xml_parse_result result =
        doc.load_buffer(stripped.data(), stripped.size(), kParseFlags);
    if (result.status != pugi::status_ok) {
        std::string msg = "XML invalido: ";
        msg += result.description();
        msg += " (offset=";
        msg += std::to_string(result.offset);
        msg += ")";
        throw InvalidTissXml{msg};
    }

    pugi::xml_node root = doc.document_element();
    if (!root) {
        throw InvalidTissXml{"XML sem elemento raiz"};
    }

    // 1) Localizar e zerar o primeiro <ans:hash> (DFS pre-order).
    //    Multiplos <ans:hash> = comportamento NAO fixado (ambiguidade #9);
    //    seguimos a referencia e zeramos apenas o primeiro.
    pugi::xml_node hash_node = FindFirstTissHash(root);
    if (hash_node) {
        ClearNodeChildren(hash_node);
    }

    // 2) Walker em ordem de documento, acumulando texto das folhas em UTF-8.
    std::string concat;
    concat.reserve(8192);  // capacidade inicial confortavel (~8 KiB).
    Walk(root, concat, hash_node);

    // 3) MD5 dos bytes UTF-8 (pugixml ja entregou em UTF-8).
    return Md5HexLower(concat);
}

std::string HashTiss(std::string_view xml) {
    const auto* p = reinterpret_cast<const std::byte*>(xml.data());
    return HashTiss(std::span<const std::byte>{p, xml.size()});
}

std::string HashTissFile(const std::filesystem::path& path) {
    std::ifstream fh(path, std::ios::binary | std::ios::ate);
    if (!fh) {
        throw std::ios_base::failure(
            "tiss_hash: falha ao abrir arquivo: " + path.string(),
            std::error_code{errno, std::generic_category()});
    }
    const std::streamsize size = fh.tellg();
    if (size < 0) {
        throw std::ios_base::failure(
            "tiss_hash: falha ao consultar tamanho: " + path.string());
    }
    fh.seekg(0, std::ios::beg);

    std::string buf(static_cast<std::size_t>(size), '\0');
    if (size > 0 && !fh.read(buf.data(), size)) {
        throw std::ios_base::failure(
            "tiss_hash: falha ao ler arquivo: " + path.string());
    }

    const auto* p = reinterpret_cast<const std::byte*>(buf.data());
    return HashTiss(std::span<const std::byte>{p, buf.size()});
}

}  // namespace tiss_hash
