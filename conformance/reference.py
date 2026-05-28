#!/usr/bin/env python3
"""
Implementação de REFERÊNCIA do hash MD5 do epílogo TISS/ANS.

Definição canônica portável (validada contra 3 goldens reais):
  1. Parse do XML (parser padrão).
  2. Zerar o conteúdo de <ans:hash>.
  3. Concatenar o .text de cada elemento-FOLHA (sem filhos), em ordem de documento.
     - sem nomes de tag, sem atributos.
     - TISS não tem conteúdo misto -> folha == valor.
  4. MD5 dos bytes UTF-8 da string concatenada.
  5. hexdigest -> 32 hex minúsculo.

ATENÇÃO: o encoding dos bytes passados ao MD5 é UTF-8, NÃO ISO-8859-1.
O arquivo é lido/decodificado conforme sua declaração (normalmente ISO-8859-1),
mas os valores extraídos são re-encodados em UTF-8 antes do MD5.
(A prosa do manual TISS diz "ISO-8859-1" — está errada na prática.)
"""
import hashlib
import io
from lxml import etree

NS = {"ans": "http://www.ans.gov.br/padroes/tiss/schemas"}


def hash_tiss_bytes(raw: bytes) -> str:
    parser = etree.XMLParser(resolve_entities=False, recover=False)
    root = etree.parse(io.BytesIO(raw), parser).getroot()

    hash_el = root.find(".//ans:hash", NS)
    if hash_el is not None:
        hash_el.text = ""

    partes = [(el.text or "") for el in root.iter() if len(el) == 0]
    valores = "".join(partes)
    return hashlib.md5(valores.encode("utf-8")).hexdigest()


def hash_tiss_file(path: str) -> str:
    with open(path, "rb") as fh:
        return hash_tiss_bytes(fh.read())


if __name__ == "__main__":
    import sys
    for p in sys.argv[1:]:
        print(f"{hash_tiss_file(p)}  {p}")
