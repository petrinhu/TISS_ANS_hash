"""Implementação portável do hash MD5 do epílogo TISS/ANS.

Módulo interno; a API pública é exposta por ``tiss_hash`` (ver ``__init__``).

Algoritmo canônico (validado contra goldens reais em ``conformance/``):

1. Parse do XML.
2. Zerar o conteúdo de ``<ans:hash>`` (não entra no cálculo).
3. Concatenar o ``.text`` de cada elemento-FOLHA (sem filhos), em ordem
   de documento. Sem nomes de tag, sem atributos. TISS não tem conteúdo
   misto, portanto folha = valor.
4. Calcular MD5 sobre os bytes **UTF-8** da string concatenada.
5. ``hexdigest()`` minúsculo (32 chars).

Atenção: o encoding dos bytes passados ao MD5 é **UTF-8**, NÃO ISO-8859-1
(apesar do que diz a prosa do manual TISS). Os arquivos são lidos respeitando
sua declaração XML (geralmente ISO-8859-1), mas os valores extraídos são
re-encodados em UTF-8 antes do MD5.
"""

from __future__ import annotations

import hashlib
import io
import os
from xml.etree.ElementTree import ParseError, TreeBuilder

from defusedxml.common import DefusedXmlException

# defusedxml é usado em vez de xml.etree.ElementTree.parse porque os
# parsers da stdlib são vulneráveis a XXE (XML External Entity) e
# "billion laughs" / quadratic blowup. Como esta lib pode receber XMLs
# vindos de operadoras / parceiros externos, parsing seguro é mandatório.
# defusedxml.ElementTree é drop-in compatível com xml.etree e desabilita
# por padrão DOCTYPE, entidades externas e expansion de entidades.
from defusedxml.ElementTree import DefusedXMLParser
from defusedxml.ElementTree import parse as _safe_parse

__all__ = ["InvalidTissXml", "hash_tiss", "hash_tiss_file"]

# Namespace oficial do padrão TISS/ANS.
_TISS_NS = "http://www.ans.gov.br/padroes/tiss/schemas"

# Tag do elemento de hash já expandida em notação Clark (``{uri}localname``),
# que é a forma como ``xml.etree.ElementTree`` representa elementos namespaced.
_HASH_TAG = f"{{{_TISS_NS}}}hash"


class InvalidTissXml(ValueError):
    """XML de entrada inválido ou não parseável.

    Subclasse de :class:`ValueError` para preservar idiomatismo Python ao
    mesmo tempo em que permite tratamento específico.
    """


def hash_tiss(xml: bytes) -> str:
    """Calcula o hash MD5 do epílogo TISS/ANS a partir dos bytes do XML.

    Recebe os bytes brutos do arquivo (a declaração XML interna define o
    encoding original, geralmente ISO-8859-1) e devolve o hash em hex
    minúsculo, exatamente como gravado no elemento ``<ans:hash>``.

    Args:
        xml: bytes do documento XML completo.

    Returns:
        Hash MD5 em hexadecimal minúsculo, 32 caracteres.

    Raises:
        InvalidTissXml: se o XML estiver malformado, contiver construções
            inseguras (DOCTYPE, entidades externas, billion-laughs) ou não
            puder ser parseado.
        TypeError: se ``xml`` não for ``bytes``/``bytearray``/``memoryview``.
    """
    if not isinstance(xml, (bytes, bytearray, memoryview)):
        raise TypeError(
            f"hash_tiss espera bytes-like, recebeu {type(xml).__name__}"
        )

    # Parser configurado com ``insert_comments=True`` no TreeBuilder para
    # reproduzir o comportamento da implementação de referência (lxml),
    # onde nós-comentário são filhos do elemento pai, têm ``len(el) == 0``
    # e portanto contribuem seu ``.text`` para o concat de folhas.
    # Ver ``conformance/vectors.json`` vetor ``syn_comentario.xml`` e a
    # nota ``conformance/AMBIGUITY_NOTES.md``.
    try:
        parser = DefusedXMLParser(
            target=TreeBuilder(insert_comments=True),
        )
        tree = _safe_parse(io.BytesIO(bytes(xml)), parser=parser)
    except DefusedXmlException as exc:
        # XXE / DTD externo / entidade proibida / billion-laughs.
        raise InvalidTissXml(
            f"XML rejeitado por política de segurança: {exc}"
        ) from exc
    except ParseError as exc:
        raise InvalidTissXml(f"XML inválido: {exc}") from exc

    root = tree.getroot()

    # Zera o conteúdo do elemento <ans:hash> antes de calcular.
    hash_el = root.find(f".//{_HASH_TAG}")
    if hash_el is not None:
        hash_el.text = ""

    # Concatena .text de cada elemento-folha (len(el) == 0) em ordem documental.
    partes = [(el.text or "") for el in root.iter() if len(el) == 0]
    payload = "".join(partes)

    return hashlib.md5(payload.encode("utf-8")).hexdigest()


def hash_tiss_file(path: str | os.PathLike[str]) -> str:
    """Atalho conveniente que lê o arquivo do disco e calcula o hash.

    Args:
        path: caminho do arquivo XML (str ou path-like).

    Returns:
        Hash MD5 em hexadecimal minúsculo, 32 caracteres.

    Raises:
        InvalidTissXml: se o XML estiver malformado.
        OSError: se o arquivo não puder ser aberto/lido.
    """
    with open(os.fspath(path), "rb") as fh:
        return hash_tiss(fh.read())
