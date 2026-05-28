#!/usr/bin/env python3
"""
Gera a fixture de conformidade do hash TISS:
  - copia os 3 XMLs reais (goldens validados pelo usuário) para inputs/
  - gera XMLs sintéticos (casos de borda) em ISO-8859-1
  - calcula o hash de cada um com a referência (reference.py)
  - escreve vectors.json (contrato que TODO port deve passar)

Roda: python3 build_fixture.py
"""
import json
import os
import shutil

from reference import hash_tiss_bytes

AQUI = os.path.dirname(os.path.abspath(__file__))
INPUTS = os.path.join(AQUI, "inputs")
LEGACY = os.path.abspath(os.path.join(AQUI, "..", "legacy", "padrao_gama_envio"))

# Diretório privado dos XMLs reais (contêm PII de pacientes, NÃO distribuídos).
# Padrão: `_private_tiss_real_xmls/` em sibling de lib_hash_ans.
# Override: variável de ambiente TISS_PRIVATE_XMLS.
# Se o diretório não existir, o build pula os vetores reais e gera só sintéticos.
PRIVATE = os.environ.get(
    "TISS_PRIVATE_XMLS",
    os.path.abspath(os.path.join(AQUI, "..", "..", "_private_tiss_real_xmls")),
)

# Goldens REAIS — mapeamento destino -> origem (nome legado). Os hashes esperados
# NÃO ficam neste script público (são PII indireta; ver política LGPD do projeto).
# Vivem em `<PRIVATE>/expected_hashes.json` (fora do repo, junto dos XMLs reais):
#   { "real_envio1.xml": "<hash>", "real_envio2.xml": "<hash>", ... }
# Sem esse arquivo, os reais são só calculados (sem assert de golden).
REAIS = {
    "real_envio1.xml": "padrao_gama_Lote_envio1.xml",
    "real_envio2.xml": "padrao_gama_Lote_envio2.xml",
    "real_envio3.xml": "padrao_gama_Lote_envio3.xml",
}

# Sintéticos: (nome, descrição do caso de borda, conteúdo unicode).
# Gravados em ISO-8859-1. O <hash> é preenchido com lixo de propósito,
# pra provar que o passo de zeragem funciona.
NS = 'xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas"'

SINTETICOS = [
    ("syn_minimal.xml", "minimo: cabecalho + epilogo, poucos valores",
     f"""<?xml version='1.0' encoding='iso-8859-1'?>
<ans:mensagemTISS {NS}>
  <ans:cabecalho>
    <ans:tipoTransacao>ENVIO_LOTE_GUIAS</ans:tipoTransacao>
    <ans:sequencialTransacao>1</ans:sequencialTransacao>
  </ans:cabecalho>
  <ans:epilogo>
    <ans:hash>LIXO_DEVE_SER_IGNORADO</ans:hash>
  </ans:epilogo>
</ans:mensagemTISS>"""),

    ("syn_acento.xml", "acentuacao: testa encoding UTF-8 dos bytes do MD5",
     f"""<?xml version='1.0' encoding='iso-8859-1'?>
<ans:mensagemTISS {NS}>
  <ans:cabecalho>
    <ans:nomeProfissional>JOSÉ DA CONCEIÇÃO ÁÉÍÓÚ ÀÂÃ ÇÑ</ans:nomeProfissional>
  </ans:cabecalho>
  <ans:epilogo>
    <ans:hash></ans:hash>
  </ans:epilogo>
</ans:mensagemTISS>"""),

    ("syn_empty.xml", "campos vazios: <x></x> e self-closing <y/> contribuem string vazia",
     f"""<?xml version='1.0' encoding='iso-8859-1'?>
<ans:mensagemTISS {NS}>
  <ans:cabecalho>
    <ans:campoA></ans:campoA>
    <ans:campoB/>
    <ans:campoC>valorC</ans:campoC>
  </ans:cabecalho>
  <ans:epilogo>
    <ans:hash></ans:hash>
  </ans:epilogo>
</ans:mensagemTISS>"""),

    ("syn_crlf_value.xml", "CR/LF dentro de um valor deve ser preservado literalmente",
     "<?xml version='1.0' encoding='iso-8859-1'?>\r\n"
     f"<ans:mensagemTISS {NS}>\r\n"
     "  <ans:cabecalho>\r\n"
     "    <ans:observacao>linha1\r\nlinha2\tcom_tab</ans:observacao>\r\n"
     "  </ans:cabecalho>\r\n"
     "  <ans:epilogo>\r\n"
     "    <ans:hash></ans:hash>\r\n"
     "  </ans:epilogo>\r\n"
     "</ans:mensagemTISS>"),

    ("syn_multi_guia.xml", "multiplas guias: concatenacao em ordem de documento",
     f"""<?xml version='1.0' encoding='iso-8859-1'?>
<ans:mensagemTISS {NS}>
  <ans:loteGuias>
    <ans:guia>
      <ans:numeroGuia>111</ans:numeroGuia>
      <ans:valor>10.00</ans:valor>
    </ans:guia>
    <ans:guia>
      <ans:numeroGuia>222</ans:numeroGuia>
      <ans:valor>20.50</ans:valor>
    </ans:guia>
  </ans:loteGuias>
  <ans:epilogo>
    <ans:hash></ans:hash>
  </ans:epilogo>
</ans:mensagemTISS>"""),

    # ---- Cobertura XML / parser ----
    ("syn_entidades_xml.xml",
     "entidades XML predefinidas (&amp; &lt; &gt; &quot; &apos;) devem ser DEcodificadas pelo parser antes do concat",
     f"""<?xml version='1.0' encoding='iso-8859-1'?>
<ans:mensagemTISS {NS}>
  <ans:cabecalho>
    <ans:observacao>a&amp;b&lt;c&gt;d&quot;e&apos;f</ans:observacao>
  </ans:cabecalho>
  <ans:epilogo>
    <ans:hash></ans:hash>
  </ans:epilogo>
</ans:mensagemTISS>"""),

    ("syn_cdata.xml",
     "secao CDATA deve ser entregue como texto literal (parser remove os delimitadores)",
     f"""<?xml version='1.0' encoding='iso-8859-1'?>
<ans:mensagemTISS {NS}>
  <ans:cabecalho>
    <ans:observacao><![CDATA[a < b & c]]></ans:observacao>
  </ans:cabecalho>
  <ans:epilogo>
    <ans:hash></ans:hash>
  </ans:epilogo>
</ans:mensagemTISS>"""),

    ("syn_comentario.xml",
     "AMBIGUIDADE FIXADA: comentario XML <!--...--> ENTRA no concat na referencia atual (lxml Comment satisfaz len(el)==0); ver AMBIGUITY_NOTES.md",
     f"""<?xml version='1.0' encoding='iso-8859-1'?>
<ans:mensagemTISS {NS}>
  <ans:cabecalho>
    <!-- COMENTARIO_QUE_ENTRA -->
    <ans:campo>valor1</ans:campo>
  </ans:cabecalho>
  <ans:epilogo>
    <ans:hash></ans:hash>
  </ans:epilogo>
</ans:mensagemTISS>"""),

    ("syn_atributo_folha.xml",
     "atributos em elemento-folha NAO entram no concat; apenas o .text do elemento entra",
     f"""<?xml version='1.0' encoding='iso-8859-1'?>
<ans:mensagemTISS {NS}>
  <ans:cabecalho>
    <ans:campo attr="IGNORE_ME_PLEASE" outro="TAMBEM_IGNORADO">VALOR_DO_ELEMENTO</ans:campo>
  </ans:cabecalho>
  <ans:epilogo>
    <ans:hash></ans:hash>
  </ans:epilogo>
</ans:mensagemTISS>"""),

    ("syn_namespace_xsi.xml",
     "namespace diferente em atributo (xsi:type) NAO altera o concat; ports devem ignorar prefixo de namespace",
     f"""<?xml version='1.0' encoding='iso-8859-1'?>
<ans:mensagemTISS {NS} xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <ans:cabecalho>
    <ans:campo xsi:type="xs:string">VALOR_XSI</ans:campo>
  </ans:cabecalho>
  <ans:epilogo>
    <ans:hash></ans:hash>
  </ans:epilogo>
</ans:mensagemTISS>"""),

    ("syn_whitespace_puro.xml",
     "valor contendo apenas espacos (<x>   </x>) deve preservar os 3 espacos literais no concat",
     f"""<?xml version='1.0' encoding='iso-8859-1'?>
<ans:mensagemTISS {NS}>
  <ans:cabecalho>
    <ans:campoA>   </ans:campoA>
    <ans:campoB>antes</ans:campoB>
  </ans:cabecalho>
  <ans:epilogo>
    <ans:hash></ans:hash>
  </ans:epilogo>
</ans:mensagemTISS>"""),

    ("syn_leading_zero.xml",
     "valor numerico com zeros a esquerda (00123) NAO deve ser normalizado: string literal entra no concat",
     f"""<?xml version='1.0' encoding='iso-8859-1'?>
<ans:mensagemTISS {NS}>
  <ans:cabecalho>
    <ans:numero>00123</ans:numero>
    <ans:codigo>0000</ans:codigo>
  </ans:cabecalho>
  <ans:epilogo>
    <ans:hash></ans:hash>
  </ans:epilogo>
</ans:mensagemTISS>"""),

    ("syn_iso8859_simbolos.xml",
     "simbolos ISO-8859-1 puros (grau, paragrafo, meio, micro) — todos validos no encoding declarado",
     f"""<?xml version='1.0' encoding='iso-8859-1'?>
<ans:mensagemTISS {NS}>
  <ans:cabecalho>
    <ans:observacao>temperatura 36°C - secao § 2 - dose ½ comprimido - tensao 220µV</ans:observacao>
  </ans:cabecalho>
  <ans:epilogo>
    <ans:hash></ans:hash>
  </ans:epilogo>
</ans:mensagemTISS>"""),
]


def _gera_perf_grande_xml(num_guias: int = 1500) -> str:
    """Gera XML sintetico grande (~500KB-1MB) com muitas guias para teste de performance."""
    linhas = [
        "<?xml version='1.0' encoding='iso-8859-1'?>",
        f"<ans:mensagemTISS {NS}>",
        "  <ans:cabecalho>",
        "    <ans:tipoTransacao>ENVIO_LOTE_GUIAS</ans:tipoTransacao>",
        "    <ans:sequencialTransacao>999</ans:sequencialTransacao>",
        "  </ans:cabecalho>",
        "  <ans:loteGuias>",
    ]
    for i in range(num_guias):
        linhas.append("    <ans:guia>")
        linhas.append(f"      <ans:numeroGuia>{i:08d}</ans:numeroGuia>")
        linhas.append(f"      <ans:beneficiario>BENEFICIARIO NUMERO {i} - ÇÃO</ans:beneficiario>")
        linhas.append(f"      <ans:codigoProcedimento>{(i*7) % 99999:05d}</ans:codigoProcedimento>")
        linhas.append(f"      <ans:valor>{(i * 1.37):.2f}</ans:valor>")
        linhas.append(f"      <ans:dataExecucao>2026-05-{(i % 28) + 1:02d}</ans:dataExecucao>")
        linhas.append("    </ans:guia>")
    linhas.extend([
        "  </ans:loteGuias>",
        "  <ans:epilogo>",
        "    <ans:hash>LIXO_IGNORADO</ans:hash>",
        "  </ans:epilogo>",
        "</ans:mensagemTISS>",
    ])
    return "\n".join(linhas)


SINTETICOS.append((
    "syn_perf_grande.xml",
    "performance: documento sintetico ~600KB, ~1500 guias, multi-folha em ordem de documento",
    _gera_perf_grande_xml(1500),
))


# Sinteticos especiais: bytes brutos (nao codificados via iso-8859-1).
# Lista de (nome, descricao, raw_bytes).
SINTETICOS_RAW = [
    (
        "syn_bom_utf8.xml",
        "BOM UTF-8 + declaracao encoding='utf-8': TISS proibe BOM, mas a referencia aceita; valor extraido normal",
        b"\xef\xbb\xbf<?xml version='1.0' encoding='utf-8'?>\n"
        + (
            f"<ans:mensagemTISS {NS}>\n"
            "  <ans:cabecalho>\n"
            "    <ans:observacao>JOSÉ Ção</ans:observacao>\n"
            "  </ans:cabecalho>\n"
            "  <ans:epilogo>\n"
            "    <ans:hash></ans:hash>\n"
            "  </ans:epilogo>\n"
            "</ans:mensagemTISS>\n"
        ).encode("utf-8"),
    ),
]


def main():
    os.makedirs(INPUTS, exist_ok=True)
    vetores = []

    # Reais — contêm PII de pacientes; só processados se o diretório privado existir.
    # NUNCA são copiados para `inputs/` (que é distribuído). O build privado valida em memória.
    if os.path.isdir(PRIVATE):
        expected_path = os.path.join(PRIVATE, "expected_hashes.json")
        reais_expected = {}
        if os.path.isfile(expected_path):
            with open(expected_path, encoding="utf-8") as fh:
                reais_expected = json.load(fh)
        else:
            print(f"AVISO: {expected_path} ausente; goldens reais sem assert (só cálculo).")
        for destino, origem in REAIS.items():
            src_priv = os.path.join(PRIVATE, destino)
            src_legacy = os.path.join(LEGACY, origem)
            src = src_priv if os.path.exists(src_priv) else src_legacy
            if not os.path.exists(src):
                print(f"AVISO: REAL {destino} não encontrado em {PRIVATE} nem em {LEGACY}; pulando.")
                continue
            with open(src, "rb") as fh:
                calc = hash_tiss_bytes(fh.read())
            esperado = reais_expected.get(destino)
            if esperado is None:
                print(f"PRIVADO: {destino} hash calculado (sem golden em expected_hashes.json)")
                continue
            assert calc == esperado, (
                f"REAL {destino}: referencia diverge do golden esperado "
                f"(validação privada — não distribuída)"
            )
            print(f"PRIVADO OK: {destino} valida contra golden (não vai pro vectors.json público)")
    else:
        print(f"INFO: dir privado {PRIVATE} ausente; build público (só sintéticos).")

    # sinteticos (texto unicode -> bytes ISO-8859-1)
    for nome, desc, conteudo in SINTETICOS:
        dst = os.path.join(INPUTS, nome)
        raw = conteudo.encode("iso-8859-1")
        with open(dst, "wb") as fh:
            fh.write(raw)
        calc = hash_tiss_bytes(raw)
        vetores.append({
            "id": nome,
            "input": f"inputs/{nome}",
            "expected_md5": calc,
            "source": "derived",
            "desc": desc,
        })

    # sinteticos raw (bytes brutos, encoding nao-padrao TISS, intencionalmente)
    for nome, desc, raw in SINTETICOS_RAW:
        dst = os.path.join(INPUTS, nome)
        with open(dst, "wb") as fh:
            fh.write(raw)
        calc = hash_tiss_bytes(raw)
        vetores.append({
            "id": nome,
            "input": f"inputs/{nome}",
            "expected_md5": calc,
            "source": "derived",
            "desc": desc,
        })

    manifesto = {
        "algorithm": {
            "name": "TISS/ANS epilogo MD5",
            "steps": [
                "parse XML",
                "zerar conteudo de <ans:hash>",
                "concatenar .text de cada elemento-folha (sem filhos) em ordem de documento",
                "MD5 dos bytes UTF-8 da string concatenada",
                "hexdigest minusculo (32 chars)",
            ],
            "encoding_bytes_md5": "utf-8",
            "namespace": "http://www.ans.gov.br/padroes/tiss/schemas",
            "note": "encoding dos bytes do MD5 e UTF-8, NAO ISO-8859-1 (apesar do manual)",
        },
        "vectors": vetores,
    }
    with open(os.path.join(AQUI, "vectors.json"), "w", encoding="utf-8") as fh:
        json.dump(manifesto, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    print(f"OK: {len(vetores)} vetores ({sum(v['source']=='real' for v in vetores)} reais, "
          f"{sum(v['source']=='derived' for v in vetores)} sinteticos)")
    for v in vetores:
        print(f"  {v['expected_md5']}  {v['id']}  [{v['source']}]")


if __name__ == "__main__":
    main()
