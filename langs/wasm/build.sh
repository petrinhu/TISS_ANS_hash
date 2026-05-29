#!/usr/bin/env bash
# Build do port WASM: compila o crate para wasm32-unknown-unknown e gera os
# bindings JS (pkg/web + pkg/node) com wasm-bindgen.
#
# Pré-requisitos:
#   - cargo + rustc (Fedora system, sem rustup) com target wasm32-unknown-unknown
#       rustc --print target-list | grep wasm32-unknown-unknown
#   - wasm-bindgen-cli na versão que CASA com a dep `wasm-bindgen` do Cargo.toml:
#       cargo install wasm-bindgen-cli --version 0.2.122
#     (binário fica em ~/.cargo/bin; garanta que está no PATH)
#
# Uso: bash build.sh
set -euo pipefail

cd "$(dirname "$0")"
export PATH="$HOME/.cargo/bin:$PATH"

WASM_OUT="target/wasm32-unknown-unknown/release/tiss_hash_wasm.wasm"

echo "==> cargo build --release --target wasm32-unknown-unknown"
cargo build --release --target wasm32-unknown-unknown

echo "==> wasm-bindgen (version $(wasm-bindgen --version))"
wasm-bindgen --target web    --out-dir pkg/web  --out-name tiss_hash_wasm "$WASM_OUT"
wasm-bindgen --target nodejs --out-dir pkg/node --out-name tiss_hash_wasm "$WASM_OUT"

# O binding target=nodejs é CommonJS (exports.x = ...). Como o package.json
# raiz declara "type": "module", o Node trataria pkg/node/*.js como ESM e
# quebraria. Um package.json local em pkg/node sobrescreve isso para aquela
# pasta. Idem pkg/web é ESM explícito. wasm-bindgen não gera esses arquivos,
# então recriamos a cada build.
printf '{\n  "type": "commonjs"\n}\n' > pkg/node/package.json
printf '{\n  "type": "module"\n}\n'    > pkg/web/package.json

echo "==> artefatos:"
ls -la pkg/web pkg/node

# wasm-opt (opcional, binaryen): reduz mais o tamanho do .wasm se disponível.
if command -v wasm-opt >/dev/null 2>&1; then
  echo "==> wasm-opt -Oz (otimização de tamanho)"
  for d in web node; do
    wasm-opt -Oz "pkg/$d/tiss_hash_wasm_bg.wasm" -o "pkg/$d/tiss_hash_wasm_bg.wasm"
  done
  ls -la pkg/web/tiss_hash_wasm_bg.wasm pkg/node/tiss_hash_wasm_bg.wasm
else
  echo "==> wasm-opt não encontrado (opcional); pulei a otimização extra de tamanho."
fi

echo "==> OK. Rode 'npm test' (ou 'node test/conformance.mjs') para validar."
