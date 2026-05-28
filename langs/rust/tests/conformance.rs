//! Teste de conformidade: roda os vetores sintéticos em
//! `conformance/vectors.json` e compara com `expected_md5` da referência
//! Python.
//!
//! Cada vetor tem um campo opcional `expect`:
//! - ausente ou `"hash"` → POSITIVO: `hash_tiss` deve `Ok` e bater com
//!   `expected_md5`.
//! - `"error"` → NEGATIVO: `hash_tiss` deve `Err` (e `expected_md5` é
//!   `null`).
//!
//! Localização dos artefatos: `../../conformance/` (relativo a este arquivo,
//! que vive em `langs/rust/tests/`). Resolução é feita via
//! `CARGO_MANIFEST_DIR` para garantir robustez independente do CWD do
//! runner.

use serde::Deserialize;
use std::path::{Path, PathBuf};

#[derive(Deserialize)]
struct Manifest {
    vectors: Vec<Vector>,
}

#[derive(Deserialize)]
struct Vector {
    id: String,
    input: String,
    /// `null` em vetores negativos (`expect == "error"`).
    #[serde(default)]
    expected_md5: Option<String>,
    /// Ausente/`"hash"` = positivo; `"error"` = negativo.
    #[serde(default)]
    expect: Option<String>,
    #[serde(default)]
    #[allow(dead_code)]
    desc: String,
}

impl Vector {
    /// `true` se o vetor é negativo (port deve rejeitar com `Err`).
    fn is_error(&self) -> bool {
        self.expect.as_deref() == Some("error")
    }
}

fn conformance_dir() -> PathBuf {
    // CARGO_MANIFEST_DIR = .../langs/rust → .../conformance
    let manifest = Path::new(env!("CARGO_MANIFEST_DIR"));
    manifest
        .parent() // langs/
        .and_then(|p| p.parent()) // raiz do repo
        .map(|p| p.join("conformance"))
        .expect("não foi possível resolver conformance/ a partir de CARGO_MANIFEST_DIR")
}

fn load_manifest() -> Manifest {
    let path = conformance_dir().join("vectors.json");
    let raw =
        std::fs::read(&path).unwrap_or_else(|e| panic!("falha ao ler {}: {e}", path.display()));
    serde_json::from_slice(&raw)
        .unwrap_or_else(|e| panic!("vectors.json mal-formado em {}: {e}", path.display()))
}

#[test]
fn todos_vetores_passam() {
    let manifest = load_manifest();
    let dir = conformance_dir();
    let mut fails: Vec<String> = Vec::new();

    for v in &manifest.vectors {
        let input_path = dir.join(&v.input);
        let raw = match std::fs::read(&input_path) {
            Ok(b) => b,
            Err(e) => {
                fails.push(format!("[IO] {}: {} ({e})", v.id, input_path.display()));
                continue;
            }
        };
        let result = tiss_hash::hash_tiss(&raw);

        if v.is_error() {
            // NEGATIVO: deve rejeitar.
            match result {
                Err(e) => println!("[OK-ERR] {:33} rejeitado: {e}", v.id),
                Ok(got) => fails.push(format!(
                    "[SHOULD-ERR] {:29} esperado Err, obteve Ok({got})",
                    v.id
                )),
            }
            continue;
        }

        // POSITIVO: deve casar com expected_md5.
        let expected = match v.expected_md5.as_deref() {
            Some(e) => e,
            None => {
                fails.push(format!(
                    "[BAD-VEC] {:32} vetor positivo sem expected_md5",
                    v.id
                ));
                continue;
            }
        };
        match result {
            Ok(got) if got == expected => {
                println!("[OK]   {:35} {got}", v.id);
            }
            Ok(got) => {
                fails.push(format!("[DIFF] {:35} got={got} expected={expected}", v.id));
            }
            Err(e) => {
                fails.push(format!("[ERR]  {:35} {e}", v.id));
            }
        }
    }

    assert!(
        fails.is_empty(),
        "{}/{} vetores falharam:\n{}",
        fails.len(),
        manifest.vectors.len(),
        fails.join("\n")
    );
}

#[test]
fn vetor_minimal_isolado() {
    // Sanidade: garante que a função básica funciona mesmo se o JSON for
    // alterado por engano. Hash colado fixo da referência.
    let dir = conformance_dir();
    let raw = std::fs::read(dir.join("inputs/syn_minimal.xml")).unwrap();
    let got = tiss_hash::hash_tiss(&raw).unwrap();
    assert_eq!(got, "3aa0c578c95cdb861a125f480a8a4de5");
}

#[test]
fn hash_tiss_file_funciona() {
    // hash_tiss_file deve produzir o mesmo resultado de hash_tiss(read).
    let dir = conformance_dir();
    let path = dir.join("inputs/syn_acento.xml");
    let h1 = tiss_hash::hash_tiss_file(&path).unwrap();
    let h2 = tiss_hash::hash_tiss(&std::fs::read(&path).unwrap()).unwrap();
    assert_eq!(h1, h2);
    assert_eq!(h1, "a20afc9a89aadaa2179d03d225337662");
}
