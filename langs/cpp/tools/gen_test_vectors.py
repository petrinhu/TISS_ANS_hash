#!/usr/bin/env python3
"""
gen_test_vectors.py - gera tests/test_vectors.hpp a partir de
conformance/vectors.json.

Le o manifesto canonico de vetores e emite um header C++ com std::array
de structs {id, expected_md5} pra incluir em tests/test_conformance.cpp.

Uso:
    python3 tools/gen_test_vectors.py                 # gera tests/test_vectors.hpp
    python3 tools/gen_test_vectors.py --check         # falha se output != atual
    python3 tools/gen_test_vectors.py <vectors.json> <output.hpp>  # explicito
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
LANG_DIR = HERE.parent                              # langs/cpp
REPO_ROOT = LANG_DIR.parent.parent                  # raiz do repo
DEFAULT_VECTORS_JSON = REPO_ROOT / "conformance" / "vectors.json"
DEFAULT_OUT = LANG_DIR / "tests" / "test_vectors.hpp"


HEADER_TEMPLATE = """\
// GERADO AUTOMATICAMENTE - NAO EDITAR.
// Fonte: conformance/vectors.json
// Gerador: langs/cpp/tools/gen_test_vectors.py
//
// Re-gerar:
//   python3 langs/cpp/tools/gen_test_vectors.py

#pragma once

#include <array>
#include <string_view>

struct TissVector {{
    std::string_view id;
    std::string_view expected_md5;
}};

inline constexpr std::array<TissVector, {count}> kTissVectors {{{{
{rows}
}}}};
"""


def render(vectors_json: Path) -> str:
    with vectors_json.open("r", encoding="utf-8") as fh:
        manifest = json.load(fh)
    vectors = manifest["vectors"]
    rows = []
    for v in vectors:
        vid = v["id"].replace('"', '\\"')
        exp = v["expected_md5"].replace('"', '\\"')
        rows.append(f'    TissVector{{"{vid}", "{exp}"}},')
    body = "\n".join(rows)
    return HEADER_TEMPLATE.format(count=len(vectors), rows=body)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("vectors_json", nargs="?", type=Path,
                    default=DEFAULT_VECTORS_JSON,
                    help=f"path para vectors.json (default: {DEFAULT_VECTORS_JSON})")
    ap.add_argument("out", nargs="?", type=Path, default=DEFAULT_OUT,
                    help=f"path de saida (default: {DEFAULT_OUT})")
    ap.add_argument("--check", action="store_true",
                    help="nao reescrever; exit 1 se conteudo divergir do atual")
    args = ap.parse_args()

    content = render(args.vectors_json)

    if args.check:
        try:
            current = args.out.read_text(encoding="utf-8")
        except FileNotFoundError:
            print(f"[gen_test_vectors] FALTA: {args.out}", file=sys.stderr)
            return 1
        if current != content:
            print(
                f"[gen_test_vectors] DIVERGE: {args.out} fora de sync com "
                f"{args.vectors_json}",
                file=sys.stderr,
            )
            return 1
        print(f"[gen_test_vectors] OK: {args.out} esta sincronizado")
        return 0

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(content, encoding="utf-8")
    print(f"[gen_test_vectors] escrito: {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
