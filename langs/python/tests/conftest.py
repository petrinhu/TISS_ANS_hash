"""Fixtures compartilhadas pela suíte de conformidade da lib ``tiss_hash``.

Resolve o diretório ``conformance/`` na raiz do repositório (independente
de onde o pytest seja invocado) e expõe-o como fixture, junto com o
manifesto ``vectors.json`` carregado.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

# tests/conftest.py -> tests/ -> python/ -> langs/ -> repo_root
_REPO_ROOT = Path(__file__).resolve().parents[3]
_CONFORMANCE_DIR = _REPO_ROOT / "conformance"
_VECTORS_PATH = _CONFORMANCE_DIR / "vectors.json"


@pytest.fixture(scope="session")
def conformance_dir() -> Path:
    """Caminho absoluto do diretório ``conformance/`` na raiz do repo."""
    if not _CONFORMANCE_DIR.is_dir():
        pytest.fail(
            f"diretório conformance/ não encontrado em {_CONFORMANCE_DIR}; "
            "esta suíte deve rodar dentro do checkout completo do repo "
            "lib_hash_ans, não a partir do wheel instalado."
        )
    return _CONFORMANCE_DIR


@pytest.fixture(scope="session")
def vectors_manifest(conformance_dir: Path) -> dict[str, Any]:
    """Conteúdo parseado de ``conformance/vectors.json``."""
    if not _VECTORS_PATH.is_file():
        pytest.fail(f"vectors.json ausente: {_VECTORS_PATH}")
    with _VECTORS_PATH.open("r", encoding="utf-8") as fh:
        return json.load(fh)
