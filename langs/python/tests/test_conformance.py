"""Suíte de conformidade: a lib ``tiss_hash`` deve bater os 8 vetores
canônicos definidos em ``conformance/vectors.json``.

Cada vetor vira um teste parametrizado nomeado com o ``id`` do vetor,
facilitando ler a saída do ``pytest -v``.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest
from tiss_hash import InvalidTissXml, hash_tiss, hash_tiss_file

# Carregamento do manifesto em import-time para alimentar @parametrize.
# Replicamos a lógica do conftest aqui porque parametrize precisa dos
# valores antes da fase de fixtures.
_REPO_ROOT = Path(__file__).resolve().parents[3]
_CONFORMANCE_DIR = _REPO_ROOT / "conformance"
_VECTORS_PATH = _CONFORMANCE_DIR / "vectors.json"

if _VECTORS_PATH.is_file():
    with _VECTORS_PATH.open("r", encoding="utf-8") as _fh:
        _MANIFEST: dict[str, Any] = json.load(_fh)
    _VECTORS: list[dict[str, Any]] = _MANIFEST.get("vectors", [])
else:
    _VECTORS = []


@pytest.mark.skipif(not _VECTORS, reason="vectors.json ausente ou vazio")
@pytest.mark.parametrize(
    "vector",
    _VECTORS,
    ids=[v["id"] for v in _VECTORS],
)
def test_vector_matches_expected(
    vector: dict[str, Any],
    conformance_dir: Path,
) -> None:
    """Cada vetor: lê o XML do disco, calcula o hash, compara."""
    input_path = conformance_dir / vector["input"]
    assert input_path.is_file(), f"input ausente: {input_path}"

    raw = input_path.read_bytes()
    got = hash_tiss(raw)

    assert got == vector["expected_md5"], (
        f"hash divergente para {vector['id']}: "
        f"obtido {got!r}, esperado {vector['expected_md5']!r}"
    )


@pytest.mark.skipif(not _VECTORS, reason="vectors.json ausente ou vazio")
def test_manifest_contains_core_vectors() -> None:
    """Garante que o manifesto contém os vetores núcleo originais.

    O manifesto cresce ao longo do tempo (vetores sintéticos novos),
    mas estes 8 são considerados o conjunto mínimo de conformidade.
    """
    # Vetores reais (real_envio*.xml) NÃO entram no manifesto público
    # porque contêm PII de pacientes — vivem em diretório privado fora do
    # repo (ver build_fixture.py: TISS_PRIVATE_XMLS). A validação contra
    # eles roda apenas em ambiente privado do mantenedor.
    nucleo = {
        "syn_minimal.xml",
        "syn_acento.xml",
        "syn_empty.xml",
        "syn_crlf_value.xml",
        "syn_multi_guia.xml",
    }
    presentes = {v["id"] for v in _VECTORS}
    faltando = nucleo - presentes
    assert not faltando, (
        f"vetores núcleo ausentes do manifesto: {sorted(faltando)}"
    )
    assert len(_VECTORS) >= 5, (
        f"esperados ao menos 5 vetores núcleo no manifesto, encontrados {len(_VECTORS)}"
    )


@pytest.mark.skipif(not _VECTORS, reason="vectors.json ausente ou vazio")
def test_hash_tiss_file_matches_hash_tiss(conformance_dir: Path) -> None:
    """``hash_tiss_file`` deve produzir o mesmo resultado de ``hash_tiss``."""
    vec = _VECTORS[0]
    input_path = conformance_dir / vec["input"]
    assert hash_tiss_file(str(input_path)) == hash_tiss(input_path.read_bytes())
    # Também aceita PathLike.
    assert hash_tiss_file(input_path) == vec["expected_md5"]


def test_invalid_xml_raises_invalid_tiss_xml() -> None:
    """XML malformado deve disparar ``InvalidTissXml`` (subclasse de ValueError)."""
    with pytest.raises(InvalidTissXml):
        hash_tiss(b"<isto-nao-fecha>")
    # Compatibilidade idiomática: também é capturável como ValueError.
    with pytest.raises(ValueError):
        hash_tiss(b"<isto-nao-fecha>")


def test_non_bytes_input_raises_type_error() -> None:
    """Input com tipo errado deve falhar cedo com TypeError, não confundir
    com erro de parsing."""
    with pytest.raises(TypeError):
        hash_tiss("string-em-vez-de-bytes")  # type: ignore[arg-type]
