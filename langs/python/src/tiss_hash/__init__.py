"""tiss_hash — geração do hash MD5 do epílogo TISS/ANS.

API pública:
    - :func:`hash_tiss` — calcula o hash a partir dos bytes do XML.
    - :func:`hash_tiss_file` — atalho para arquivos em disco.
    - :class:`InvalidTissXml` — exceção para XML malformado.
    - :data:`__version__` — versão do pacote.

Spec do algoritmo: ver ``docs/SPEC.md`` no repositório e a implementação
de referência em ``conformance/reference.py``.

Exemplo:
    >>> from tiss_hash import hash_tiss
    >>> with open("lote.xml", "rb") as fh:
    ...     hash_tiss(fh.read())  # valor ilustrativo (vetor syn_minimal)
    '3aa0c578c95cdb861a125f480a8a4de5'
"""

from __future__ import annotations

from ._core import InvalidTissXml, hash_tiss, hash_tiss_file

# Versão é resolvida via metadata do pacote instalado (PEP 621 / pyproject).
# Fallback "0.0.0+unknown" cobre execução direta a partir do source tree
# (sem ``pip install``), o que é comum em desenvolvimento.
try:
    from importlib.metadata import PackageNotFoundError
    from importlib.metadata import version as _pkg_version

    try:
        __version__: str = _pkg_version("tiss-hash")
    except PackageNotFoundError:  # pragma: no cover - execução in-tree
        __version__ = "0.0.0+unknown"
except ImportError:  # pragma: no cover - Python <3.8, não suportado
    __version__ = "0.0.0+unknown"


__all__ = [
    "InvalidTissXml",
    "__version__",
    "hash_tiss",
    "hash_tiss_file",
]
