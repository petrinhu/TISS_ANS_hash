#!/usr/bin/env python3
"""
gen_test_vectors.py - gera tests/test_vectors.h a partir de conformance/vectors.json.

Le o manifesto canonico de vetores em ../../../conformance/vectors.json
(relativo a langs/c/tools/) e emite um header C com array estatico de structs
{id, expected_md5, expect_error} pronto pra incluir em tests/test_conformance.c.

Campo `expect` do manifesto: ausente/"hash" = vetor POSITIVO (compara
expected_md5); "error" = vetor NEGATIVO (o port deve sinalizar erro). Para
negativos, expected_md5 e null e vira NULL no header (expect_error=1).

Uso:
    python3 tools/gen_test_vectors.py            # gera tests/test_vectors.h
    python3 tools/gen_test_vectors.py --check    # falha se output != atual
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
LANG_DIR = HERE.parent                              # langs/c
REPO_ROOT = LANG_DIR.parent.parent                  # raiz do repo
VECTORS_JSON = REPO_ROOT / "conformance" / "vectors.json"
OUT_HEADER = LANG_DIR / "tests" / "test_vectors.h"


HEADER_TEMPLATE = """\
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

#include <stddef.h> /* NULL */

typedef struct {{
    const char *id;
    const char *expected_md5; /* NULL em vetores negativos (expect_error=1) */
    int         expect_error; /* 0 = positivo (compara hash); 1 = deve rejeitar */
}} tiss_vector_t;

static const tiss_vector_t TISS_VECTORS[] = {{
{rows}
}};

#define TISS_VECTORS_COUNT (sizeof(TISS_VECTORS) / sizeof(TISS_VECTORS[0]))

#endif /* TISS_TEST_VECTORS_H */
"""


def render() -> str:
    with VECTORS_JSON.open("r", encoding="utf-8") as fh:
        manifest = json.load(fh)

    vectors = manifest["vectors"]
    rows = []
    for v in vectors:
        vid = v["id"].replace('"', '\\"')
        # expect: ausente ou "hash" = positivo; "error" = negativo.
        expect_error = 1 if v.get("expect") == "error" else 0
        exp_raw = v.get("expected_md5")
        if expect_error:
            # Negativo: expected_md5 e null no manifesto -> NULL no C.
            rows.append(f'    {{ "{vid}", NULL, 1 }},')
        else:
            if exp_raw is None:
                raise ValueError(
                    f"vetor positivo '{vid}' sem expected_md5 no manifesto"
                )
            exp = exp_raw.replace('"', '\\"')
            rows.append(f'    {{ "{vid}", "{exp}", 0 }},')
    body = "\n".join(rows)
    return HEADER_TEMPLATE.format(rows=body)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--check",
        action="store_true",
        help="nao reescrever; exit 1 se conteudo divergir do atual",
    )
    ap.add_argument(
        "--out",
        type=Path,
        default=OUT_HEADER,
        help=f"caminho de saida (default: {OUT_HEADER})",
    )
    args = ap.parse_args()

    content = render()

    if args.check:
        try:
            current = args.out.read_text(encoding="utf-8")
        except FileNotFoundError:
            print(f"[gen_test_vectors] FALTA: {args.out}", file=sys.stderr)
            return 1
        if current != content:
            print(
                f"[gen_test_vectors] DIVERGE: {args.out} fora de sync com "
                f"{VECTORS_JSON}",
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
