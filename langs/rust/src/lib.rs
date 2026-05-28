//! # tiss-hash
//!
//! Hash MD5 do epílogo `<ans:hash>` em XMLs do **Padrão TISS/ANS** (Padrão TISS
//! 4.01.00 — Troca de Informações em Saúde Suplementar, regulamentado pela
//! Agência Nacional de Saúde Suplementar).
//!
//! Spec canônica: `docs/SPEC.md` no repositório principal.
//! Implementação de referência: `conformance/reference.py` (Python + lxml).
//! Esta crate **bate byte-a-byte** com a referência nos vetores em
//! `conformance/vectors.json` (positivos comparam `expected_md5`; negativos
//! exigem `Err`, ex.: múltiplos `<ans:hash>` e BOM UTF-16/UTF-32).
//!
//! ## Algoritmo (resumo)
//!
//! 1. Parse do XML.
//! 2. Zerar o conteúdo de `<ans:hash>` (substituir por string vazia).
//! 3. Concatenar o `.text` de cada **nó-folha** (elemento ou comentário sem
//!    filhos elemento/comentário/PI), em ordem de documento.
//! 4. MD5 dos bytes **UTF-8** da string concatenada (não ISO-8859-1, apesar
//!    do manual TISS).
//! 5. Hex lowercase, 32 caracteres.
//!
//! Ver `conformance/AMBIGUITY_NOTES.md` para o catálogo das 15 decisões
//! canônicas (CDATA, entidades, atributos, comentários, etc.).
//!
//! ## Quickstart
//!
//! ```no_run
//! use tiss_hash::{hash_tiss, hash_tiss_file};
//!
//! let raw = std::fs::read("envio.xml").unwrap();
//! let digest = hash_tiss(&raw).unwrap();
//! println!("{digest}"); // 32 chars hex lowercase
//!
//! // ou direto do arquivo
//! let digest = hash_tiss_file("envio.xml").unwrap();
//! ```
//!
//! ## Decisão de parser: roxmltree
//!
//! Avaliadas três opções:
//!
//! - **roxmltree** (escolhida) — parser DOM puro, API próxima do
//!   `ElementTree`/`lxml` do Python. Suporta iteração `descendants()` que
//!   inclui nós `Comment` (semântica idêntica à `lxml.iter()` da
//!   referência). Zero alloc além da árvore. Limitação: aceita só `&str`
//!   UTF-8, exige pré-decodificação ISO-8859-1 manual (feita aqui — mapping
//!   1:1 byte → codepoint).
//! - quick-xml — SAX/streaming, mais rápido em throughput, mas exige
//!   reconstruir manualmente o conceito de "folha" e tracking de pilha.
//!   Descartado por não ser necessário pra performance esperada (XMLs TISS
//!   geralmente < 5 MB).
//! - xmltree — DOM básico, menos manutenção, sem `descendants()` ergonômico.
//!   Descartado.

#![deny(missing_docs)]
#![deny(unsafe_code)]
#![warn(rust_2018_idioms)]

use md5::{Digest, Md5};
use std::fmt;
use std::fs;
use std::io;
use std::path::Path;

/// Namespace XML do Padrão TISS/ANS. Usado para localizar `<ans:hash>`.
///
/// Apesar do prefixo convencional ser `ans:`, o que conta é o **namespace
/// URI**: qualquer prefixo serve, desde que mapeie pra esta URI.
pub const TISS_NAMESPACE: &str = "http://www.ans.gov.br/padroes/tiss/schemas";

/// Erros possíveis no cálculo do hash TISS.
#[derive(Debug)]
pub enum TissHashError {
    /// XML mal-formado, contém DTD malicioso, ou viola política de
    /// segurança (XXE, entidades externas). A mensagem traz o erro do
    /// parser subjacente para diagnóstico.
    InvalidXml(String),
    /// Erro de I/O ao ler arquivo (somente em `hash_tiss_file`).
    Io(io::Error),
}

impl fmt::Display for TissHashError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidXml(msg) => write!(f, "XML inválido para hash TISS: {msg}"),
            Self::Io(err) => write!(f, "erro de I/O ao ler XML TISS: {err}"),
        }
    }
}

impl std::error::Error for TissHashError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::InvalidXml(_) => None,
            Self::Io(err) => Some(err),
        }
    }
}

impl From<io::Error> for TissHashError {
    fn from(err: io::Error) -> Self {
        Self::Io(err)
    }
}

impl From<roxmltree::Error> for TissHashError {
    fn from(err: roxmltree::Error) -> Self {
        Self::InvalidXml(err.to_string())
    }
}

/// Calcula o hash MD5 canônico do epílogo TISS/ANS a partir dos bytes do XML.
///
/// Retorna uma string hex de **32 caracteres minúsculos** (lowercase).
///
/// # Parâmetros
///
/// - `xml`: bytes do arquivo XML completo (pode declarar `encoding="iso-8859-1"`
///   ou `encoding="utf-8"`, e pode começar com BOM UTF-8 — todos suportados).
///
/// # Erros
///
/// - [`TissHashError::InvalidXml`] se o parser rejeitar a entrada.
///
/// # Exemplo
///
/// ```no_run
/// let raw = std::fs::read("envio.xml").unwrap();
/// let digest = tiss_hash::hash_tiss(&raw).unwrap();
/// assert_eq!(digest.len(), 32);
/// ```
pub fn hash_tiss(xml: &[u8]) -> Result<String, TissHashError> {
    // Rejeição por BOM fora de escopo: o escopo é ISO-8859-1 + UTF-8.
    // UTF-32 ANTES de UTF-16, pois o BOM UTF-32 LE (FF FE 00 00) começa
    // com os mesmos 2 bytes do UTF-16 LE (FF FE) — checar o mais longo
    // primeiro evita classificar erroneamente.
    if let Some(enc) = detect_unsupported_bom(xml) {
        return Err(TissHashError::InvalidXml(format!(
            "encoding {enc} fora de escopo (suportado: ISO-8859-1, UTF-8)"
        )));
    }

    let utf8 = decode_to_utf8(xml);
    // ParsingOptions padrão: roxmltree não resolve entidades externas
    // (não suporta), DTDs externos são ignorados — política segura por
    // construção.
    let opts = roxmltree::ParsingOptions {
        allow_dtd: true,
        ..Default::default()
    };
    let doc = roxmltree::Document::parse_with_options(&utf8, opts)?;
    let root = doc.root_element();

    // Localizar o(s) <ans:hash> (qualquer prefixo, namespace TISS).
    // TISS define no máximo 1; >1 é documento inválido e deve ser rejeitado.
    let hash_node_id = find_hash_node(root)?;

    // Concat dos textos de folhas em ordem de documento, zerando <ans:hash>.
    let mut buf = String::new();
    for node in root.descendants() {
        if !is_leaf_for_hash(node) {
            continue;
        }
        // Zerar conteúdo de <ans:hash>: pular o .text (equivale a "").
        if Some(node.id()) == hash_node_id {
            continue;
        }
        if let Some(t) = node.text() {
            buf.push_str(t);
        }
    }

    let mut hasher = Md5::new();
    hasher.update(buf.as_bytes());
    let digest = hasher.finalize();
    Ok(hex_lower(&digest))
}

/// Atalho: lê o arquivo do disco e calcula [`hash_tiss`].
///
/// # Erros
///
/// - [`TissHashError::Io`] em falha de I/O.
/// - [`TissHashError::InvalidXml`] se o parser rejeitar o conteúdo.
pub fn hash_tiss_file<P: AsRef<Path>>(path: P) -> Result<String, TissHashError> {
    let raw = fs::read(path)?;
    hash_tiss(&raw)
}

// -- Internos --------------------------------------------------------------

/// Decide se um nó é "folha pro hash":
///
/// - Aceita nós `Element` e `Comment` (PI, Text, Root são pulados ou
///   tratados naturalmente pela iteração).
/// - "Sem filhos" no sentido da referência `lxml`: sem children
///   `Element`/`Comment`/`PI`. Children `Text` NÃO contam (TISS não tem
///   conteúdo misto, então um elemento com só Text dentro é folha de
///   valor).
fn is_leaf_for_hash(n: roxmltree::Node<'_, '_>) -> bool {
    if !(n.is_element() || n.is_comment()) {
        return false;
    }
    !n.children()
        .any(|c| c.is_element() || c.is_comment() || c.is_pi())
}

/// Localiza o `<ans:hash>` (namespace TISS, qualquer prefixo) por id de nó.
///
/// Casa por **URI de namespace**, não por prefixo literal (`local == "hash"`
/// e `namespace == TISS_NAMESPACE`), então o namespace default casa.
///
/// # Erros
///
/// - [`TissHashError::InvalidXml`] se houver **mais de um** `<ans:hash>`:
///   o Padrão TISS define exatamente um epílogo, então `>1` é documento
///   inválido (ver `AMBIGUITY_NOTES.md` §9). Zero é válido (caminho "hash
///   ausente" — concatena tudo).
fn find_hash_node(
    root: roxmltree::Node<'_, '_>,
) -> Result<Option<roxmltree::NodeId>, TissHashError> {
    let mut found: Option<roxmltree::NodeId> = None;
    let mut count = 0usize;
    for n in root.descendants() {
        if n.is_element()
            && n.tag_name().name() == "hash"
            && n.tag_name().namespace() == Some(TISS_NAMESPACE)
        {
            count += 1;
            if found.is_none() {
                found = Some(n.id());
            }
        }
    }
    if count > 1 {
        return Err(TissHashError::InvalidXml(format!(
            "múltiplos elementos <hash> do namespace TISS (encontrados {count}, esperado no máximo 1)"
        )));
    }
    Ok(found)
}

/// Detecta BOM de encoding fora de escopo (UTF-16 / UTF-32).
///
/// Ordem importa: UTF-32 ANTES de UTF-16, pois o BOM UTF-32 LE
/// (`FF FE 00 00`) começa com os mesmos 2 bytes do UTF-16 LE (`FF FE`).
/// Retorna o rótulo do encoding detectado, ou `None` se nenhum BOM
/// fora de escopo estiver presente (UTF-8 BOM é tratado depois, em
/// `decode_to_utf8`).
fn detect_unsupported_bom(raw: &[u8]) -> Option<&'static str> {
    if raw.starts_with(&[0xFF, 0xFE, 0x00, 0x00]) || raw.starts_with(&[0x00, 0x00, 0xFE, 0xFF]) {
        Some("UTF-32")
    } else if raw.starts_with(&[0xFF, 0xFE]) || raw.starts_with(&[0xFE, 0xFF]) {
        Some("UTF-16")
    } else {
        None
    }
}

/// Decodifica bytes XML para `String` UTF-8 compatível com `roxmltree`.
///
/// Roxmltree exige `&str` UTF-8 (não aceita ISO-8859-1 nativamente). Esta
/// função:
///
/// 1. Strippa BOM UTF-8 (`EF BB BF`) se presente.
/// 2. Detecta declaração `encoding="iso-8859-1"` no prólogo.
/// 3. Se ISO-8859-1: mapeia cada byte para o codepoint Unicode (byte `n`
///    → `U+00n`), que é o mapping correto e bijetivo (ISO-8859-1 é
///    subset de Unicode no range 0x00..=0xFF). Reescreve a declaração
///    para `encoding="utf-8"` para o parser não brigar.
/// 4. Caso contrário: assume UTF-8 e tenta `from_utf8_lossy`. Se houver
///    bytes inválidos, eles viram U+FFFD — o parser provavelmente vai
///    falhar, e nós devolvemos `InvalidXml` no caller.
fn decode_to_utf8(raw: &[u8]) -> String {
    let bytes = if raw.starts_with(&[0xEF, 0xBB, 0xBF]) {
        &raw[3..]
    } else {
        raw
    };

    // Detectar encoding declarado (prólogo, primeiros ~200 bytes ASCII).
    let head_len = bytes.len().min(200);
    let head_lower: String = bytes[..head_len]
        .iter()
        .map(|&b| b.to_ascii_lowercase() as char)
        .collect();
    let is_iso = head_lower.contains("encoding=\"iso-8859-1\"")
        || head_lower.contains("encoding='iso-8859-1'");

    if is_iso {
        // ISO-8859-1 → Unicode: cada byte vira o codepoint correspondente.
        let s: String = bytes.iter().map(|&b| b as char).collect();
        // Reescrever declaração pra UTF-8 (o conteúdo agora é UTF-8 válido).
        s.replacen("encoding='iso-8859-1'", "encoding='utf-8'", 1)
            .replacen("encoding=\"iso-8859-1\"", "encoding=\"utf-8\"", 1)
    } else {
        // Assume UTF-8 (ou ASCII puro). `from_utf8_lossy` cobre o caso de
        // bytes mal-formados sem panic; o parser falhará logo depois com
        // erro tipado.
        String::from_utf8_lossy(bytes).into_owned()
    }
}

/// Serializa 16 bytes do digest MD5 em hex lowercase (32 chars).
fn hex_lower(digest: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(digest.len() * 2);
    for &b in digest {
        out.push(HEX[(b >> 4) as usize] as char);
        out.push(HEX[(b & 0x0F) as usize] as char);
    }
    out
}

// -- Testes unitários ------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hex_lower_zera() {
        assert_eq!(hex_lower(&[0u8; 16]), "00000000000000000000000000000000");
    }

    #[test]
    fn hex_lower_ff() {
        assert_eq!(hex_lower(&[0xFFu8; 16]), "ffffffffffffffffffffffffffffffff");
    }

    #[test]
    fn hex_lower_mix() {
        assert_eq!(hex_lower(&[0xDE, 0xAD, 0xBE, 0xEF]), "deadbeef");
    }

    #[test]
    fn md5_string_vazia() {
        // MD5("") = d41d8cd98f00b204e9800998ecf8427e
        let mut h = Md5::new();
        h.update(b"");
        assert_eq!(hex_lower(&h.finalize()), "d41d8cd98f00b204e9800998ecf8427e");
    }

    #[test]
    fn decode_utf8_strippa_bom() {
        let raw = b"\xEF\xBB\xBF<?xml version='1.0' encoding='utf-8'?><a/>";
        let s = decode_to_utf8(raw);
        assert!(s.starts_with("<?xml"));
    }

    #[test]
    fn decode_iso_reescreve_decl() {
        let mut raw: Vec<u8> = b"<?xml version='1.0' encoding='iso-8859-1'?><a>".to_vec();
        raw.push(0xC9); // É em ISO-8859-1
        raw.extend_from_slice(b"</a>");
        let s = decode_to_utf8(&raw);
        assert!(s.contains("encoding='utf-8'"));
        assert!(s.contains('É')); // U+00C9 (= byte 0xC9 mapeado)
    }

    #[test]
    fn xml_invalido_retorna_erro() {
        let r = hash_tiss(b"<no-encoding><sem-fechar>");
        assert!(matches!(r, Err(TissHashError::InvalidXml(_))));
    }

    #[test]
    fn multiplos_hash_rejeitado() {
        let xml = b"<?xml version='1.0' encoding='utf-8'?>\
            <ans:mensagemTISS xmlns:ans=\"http://www.ans.gov.br/padroes/tiss/schemas\">\
            <ans:epilogo><ans:hash>A</ans:hash><ans:hash>B</ans:hash></ans:epilogo>\
            </ans:mensagemTISS>";
        assert!(matches!(hash_tiss(xml), Err(TissHashError::InvalidXml(_))));
    }

    #[test]
    fn um_hash_aceito() {
        // Sanidade: exatamente 1 <ans:hash> não dispara a rejeição.
        let xml = b"<?xml version='1.0' encoding='utf-8'?>\
            <ans:mensagemTISS xmlns:ans=\"http://www.ans.gov.br/padroes/tiss/schemas\">\
            <ans:epilogo><ans:hash>X</ans:hash></ans:epilogo>\
            </ans:mensagemTISS>";
        assert!(hash_tiss(xml).is_ok());
    }

    #[test]
    fn sem_hash_aceito() {
        // Documento sem <ans:hash> é válido (concatena tudo, sem erro).
        let xml = b"<?xml version='1.0' encoding='utf-8'?>\
            <ans:mensagemTISS xmlns:ans=\"http://www.ans.gov.br/padroes/tiss/schemas\">\
            <ans:guia><ans:valor>42</ans:valor></ans:guia>\
            </ans:mensagemTISS>";
        assert!(hash_tiss(xml).is_ok());
    }

    #[test]
    fn bom_utf16_le_rejeitado() {
        assert_eq!(
            detect_unsupported_bom(&[0xFF, 0xFE, 0x3C, 0x00]),
            Some("UTF-16")
        );
        let r = hash_tiss(&[0xFF, 0xFE, 0x3C, 0x00]);
        assert!(matches!(r, Err(TissHashError::InvalidXml(_))));
    }

    #[test]
    fn bom_utf16_be_rejeitado() {
        assert_eq!(
            detect_unsupported_bom(&[0xFE, 0xFF, 0x00, 0x3C]),
            Some("UTF-16")
        );
        let r = hash_tiss(&[0xFE, 0xFF, 0x00, 0x3C]);
        assert!(matches!(r, Err(TissHashError::InvalidXml(_))));
    }

    #[test]
    fn bom_utf32_le_rejeitado() {
        // FF FE 00 00 deve classificar como UTF-32, não UTF-16 (ordem!).
        assert_eq!(
            detect_unsupported_bom(&[0xFF, 0xFE, 0x00, 0x00]),
            Some("UTF-32")
        );
    }

    #[test]
    fn bom_utf32_be_rejeitado() {
        assert_eq!(
            detect_unsupported_bom(&[0x00, 0x00, 0xFE, 0xFF]),
            Some("UTF-32")
        );
    }

    #[test]
    fn sem_bom_passa() {
        // UTF-8 BOM (EF BB BF) NÃO é fora de escopo; tratado em decode.
        assert_eq!(detect_unsupported_bom(&[0xEF, 0xBB, 0xBF, 0x3C]), None);
        assert_eq!(detect_unsupported_bom(b"<a/>"), None);
    }

    #[test]
    fn hash_mensagem_minima_inline() {
        // XML mínimo: hash zerado + sem texto = MD5("") = d41d8cd9...
        let xml = b"<?xml version='1.0' encoding='utf-8'?>\
            <ans:mensagemTISS xmlns:ans=\"http://www.ans.gov.br/padroes/tiss/schemas\">\
            <ans:epilogo><ans:hash>QUALQUER</ans:hash></ans:epilogo>\
            </ans:mensagemTISS>";
        let h = hash_tiss(xml).unwrap();
        assert_eq!(h, "d41d8cd98f00b204e9800998ecf8427e");
    }
}
