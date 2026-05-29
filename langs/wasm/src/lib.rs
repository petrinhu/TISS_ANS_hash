//! # tiss-hash-wasm
//!
//! Port **WebAssembly** do hash MD5 do epílogo `<ans:hash>` em XMLs do
//! **Padrão TISS/ANS** (Troca de Informações em Saúde Suplementar,
//! regulamentado pela Agência Nacional de Saúde Suplementar).
//!
//! ## Motivo de existir (LGPD)
//!
//! Roda **100% client-side no browser**: o XML TISS (que carrega PII de
//! paciente) é hasheado dentro da aba do navegador (ou de um worker), e
//! **nada trafega**. Sem upload, sem servidor. Ver ADR-0006.
//!
//! ## Como funciona
//!
//! Esta crate é uma **casca fina** sobre o core nativo Rust `tiss_hash`
//! (`langs/rust/`). Não reimplementa nada: recebe os bytes do JS, chama
//! [`tiss_hash::hash_tiss`], e converte o erro tipado em exceção JS. As
//! **mesmas rejeições** do core são preservadas:
//!
//! - múltiplos `<ans:hash>` → erro;
//! - BOM UTF-16 / UTF-32 (fora de escopo) → erro;
//! - XML mal-formado → erro.
//!
//! O encoding dos bytes do MD5 é **UTF-8** (regra canônica do projeto),
//! herdado do core sem alteração.

#![deny(unsafe_code)]
#![warn(rust_2018_idioms)]

use wasm_bindgen::prelude::*;

/// URI do namespace XML do Padrão TISS/ANS.
///
/// Exposta ao JS como constante (`tissNamespace()`), reusando a definição
/// canônica do core nativo, sem string mágica duplicada.
#[wasm_bindgen(js_name = tissNamespace)]
pub fn tiss_namespace() -> String {
    tiss_hash::TISS_NAMESPACE.to_string()
}

/// Calcula o hash MD5 canônico do epílogo TISS/ANS a partir dos bytes do XML.
///
/// Recebe um `Uint8Array` (ou qualquer fonte de bytes do JS) e devolve a
/// string hex de **32 caracteres minúsculos**.
///
/// # Erros
///
/// Lança uma exceção JS (`Error`) se o XML for rejeitado pelo core:
/// mal-formado, múltiplos `<ans:hash>`, ou BOM UTF-16/UTF-32 fora de escopo.
/// A mensagem do erro vem do core (diagnóstico do parser), **sem PII**.
#[wasm_bindgen(js_name = hashTiss)]
pub fn hash_tiss(xml: &[u8]) -> Result<String, JsError> {
    tiss_hash::hash_tiss(xml).map_err(|e| JsError::new(&e.to_string()))
}
