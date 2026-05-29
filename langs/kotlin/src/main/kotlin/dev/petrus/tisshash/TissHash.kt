/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) Petrus Silva Costa
 */
@file:JvmName("TissHash")

package dev.petrus.tisshash

import java.io.ByteArrayInputStream
import java.io.IOException
import java.nio.file.Files
import java.nio.file.Path
import java.security.MessageDigest
import java.security.NoSuchAlgorithmException
import javax.xml.XMLConstants
import javax.xml.parsers.DocumentBuilder
import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.parsers.ParserConfigurationException
import org.w3c.dom.Comment
import org.w3c.dom.Document
import org.w3c.dom.Element
import org.w3c.dom.Node
import org.xml.sax.ErrorHandler
import org.xml.sax.InputSource
import org.xml.sax.SAXException
import org.xml.sax.SAXParseException

/**
 * URI do namespace do Padrão TISS/ANS. Usado para localizar `<ans:hash>`
 * independente do prefixo declarado no documento.
 */
public const val TISS_NAMESPACE: String = "http://www.ans.gov.br/padroes/tiss/schemas"

/** Versão deste port. */
public const val VERSION: String = "0.1.0"

/** Nome local (sem prefixo) do elemento que carrega o hash no epílogo. */
private const val HASH_LOCAL_NAME = "hash"

/** Bytes do BOM UTF-8 (`EF BB BF`). */
private const val BOM_0 = 0xEF
private const val BOM_1 = 0xBB
private const val BOM_2 = 0xBF

/**
 * Calcula o hash MD5 canônico do epílogo `<ans:hash>` de um XML do
 * **Padrão TISS/ANS** a partir dos bytes do documento.
 *
 * Spec canônica: `docs/SPEC.md` no repositório principal. Implementação de
 * referência: `conformance/reference.py` (Python + lxml). Este port bate
 * byte-a-byte com a referência nos 20 vetores de conformidade em
 * `conformance/vectors.json` e com os demais ports.
 *
 * Algoritmo (resumo):
 *  1. Rejeita BOM UTF-16/UTF-32 (fora de escopo TISS).
 *  2. Strip de BOM UTF-8 se presente.
 *  3. Parse do XML com parser DOM seguro (FEATURE_SECURE_PROCESSING +
 *     DOCTYPE/entidades externas desabilitadas), namespace-aware,
 *     comentários preservados.
 *  4. Zera o conteúdo do único `<ans:hash>` (qualquer prefixo, namespace
 *     TISS). Documento sem `<ans:hash>` é válido; múltiplos `<ans:hash>` é
 *     **rejeitado**.
 *  5. Concatena o texto de cada **nó-folha** ([Element] ou [Comment] cujos
 *     filhos NÃO contêm Element/Comment/PI), em ordem de documento.
 *  6. MD5 dos bytes **UTF-8** da string concatenada, não ISO-8859-1, apesar
 *     do manual TISS dizer o contrário (ver `conformance/AMBIGUITY_NOTES.md`).
 *  7. Hex lowercase, 32 caracteres.
 *
 * Thread-safe: cada chamada cria sua própria [DocumentBuilder] via factory
 * configurada localmente (o JDK não garante thread-safety da factory).
 *
 * @param xmlBytes bytes do documento XML completo
 * @return hash MD5 em hex minúsculo (32 caracteres)
 * @throws InvalidTissXmlException se a entrada for rejeitada
 */
public fun hashTiss(xmlBytes: ByteArray): String {
    rejectUtf16Utf32Bom(xmlBytes)

    val cleaned = stripBomUtf8(xmlBytes)

    val doc = parseSecure(cleaned)
    val root = doc.documentElement
        ?: throw InvalidTissXmlException("XML sem documentElement (raiz ausente)")

    val hashEl = findSingleHash(doc)

    val concat = StringBuilder(estimateInitialCapacity(cleaned.size))
    walkInOrder(root, hashEl, concat)

    return md5HexLowercase(concat.toString().toByteArray(Charsets.UTF_8))
}

/**
 * Atalho conveniente: lê o arquivo do disco e chama [hashTiss].
 *
 * @param path caminho do arquivo XML
 * @return hash MD5 em hex minúsculo (32 caracteres)
 * @throws IOException erro de I/O ao ler o arquivo
 * @throws InvalidTissXmlException se o XML for inválido
 */
@Throws(IOException::class)
public fun hashTissFile(path: Path): String {
    val raw = Files.readAllBytes(path)
    return hashTiss(raw)
}

// -------------------------------------------------------------------------
// Internos: parser, walker, MD5
// -------------------------------------------------------------------------

/**
 * Cria [DocumentBuilder] com features de segurança XXE/DoS habilitadas e
 * preservação de comentários (CRÍTICA pra ambiguidade #2: comentários XML
 * entram no concat).
 *
 * `expandEntityReferences` fica no default `true` para que entidades XML
 * predefinidas (`&amp; &lt; &gt; &quot; &apos;`) sejam decodificadas pelo
 * parser antes de virem como texto (ambiguidade #4). Entidades externas/DTDs
 * ficam desabilitadas pelo `disallow-doctype-decl`.
 */
private fun newSecureBuilder(): DocumentBuilder {
    val factory = DocumentBuilderFactory.newInstance()
    try {
        // Segurança: rejeita DOCTYPE, entidades externas, XInclude, etc.
        factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true)
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
        factory.setFeature("http://xml.org/sax/features/external-general-entities", false)
        factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false)
        factory.setFeature(
            "http://apache.org/xml/features/nonvalidating/load-external-dtd",
            false,
        )
        factory.isXIncludeAware = false

        // Algoritmo: namespace-aware (comparar URI de <ans:hash>) e
        // comentários preservados (ambiguidade #2).
        factory.isNamespaceAware = true
        factory.isIgnoringComments = false
        factory.isIgnoringElementContentWhitespace = false
        factory.isCoalescing = false
        // expandEntityReferences=true (default): decoda &amp; etc.

        val builder = factory.newDocumentBuilder()
        builder.setErrorHandler(FailFastErrorHandler)
        // Sem resolver de entidades externas: bloqueia network/file I/O.
        builder.setEntityResolver { _, _ -> InputSource(ByteArrayInputStream(ByteArray(0))) }
        return builder
    } catch (e: ParserConfigurationException) {
        throw InvalidTissXmlException(
            "falha ao configurar DocumentBuilder com features seguras",
            e,
        )
    }
}

/**
 * Parse seguro dos bytes. Erros de parsing viram [InvalidTissXmlException]
 * preservando a causa raiz.
 *
 * Passamos [InputSource] sobre um [ByteArrayInputStream] (NÃO um Reader) para
 * que o parser respeite a declaração `<?xml encoding="..."?>` e use o encoding
 * declarado (ISO-8859-1 ou UTF-8). Um Reader forçaria nosso encoding.
 */
private fun parseSecure(bytes: ByteArray): Document {
    val builder = newSecureBuilder()
    return try {
        ByteArrayInputStream(bytes).use { input ->
            builder.parse(InputSource(input))
        }
    } catch (e: SAXException) {
        throw InvalidTissXmlException("XML inválido: ${e.message}", e)
    } catch (e: IOException) {
        throw InvalidTissXmlException("erro de I/O lendo XML em memória: ${e.message}", e)
    }
}

/**
 * Rejeita entrada cujo BOM indica UTF-16 ou UTF-32: encodings **fora de
 * escopo** do Padrão TISS (apenas ISO-8859-1 e UTF-8 são suportados).
 *
 * A ordem importa: UTF-32 LE (`FF FE 00 00`) começa com o mesmo par `FF FE`
 * de UTF-16 LE, por isso UTF-32 é testado **antes** de UTF-16.
 *
 * @throws InvalidTissXmlException se o BOM for UTF-16/UTF-32
 */
private fun rejectUtf16Utf32Bom(bytes: ByteArray) {
    // UTF-32 antes de UTF-16: FF FE 00 00 colide com o prefixo FF FE.
    if (bytes.size >= 4) {
        val b0 = bytes[0].toInt() and 0xFF
        val b1 = bytes[1].toInt() and 0xFF
        val b2 = bytes[2].toInt() and 0xFF
        val b3 = bytes[3].toInt() and 0xFF
        val utf32le = b0 == 0xFF && b1 == 0xFE && b2 == 0x00 && b3 == 0x00
        val utf32be = b0 == 0x00 && b1 == 0x00 && b2 == 0xFE && b3 == 0xFF
        if (utf32le || utf32be) {
            throw InvalidTissXmlException(
                "encoding UTF-32 fora de escopo (TISS suporta apenas " +
                    "ISO-8859-1 e UTF-8); BOM UTF-32 detectado",
            )
        }
    }
    if (bytes.size >= 2) {
        val b0 = bytes[0].toInt() and 0xFF
        val b1 = bytes[1].toInt() and 0xFF
        val utf16le = b0 == 0xFF && b1 == 0xFE
        val utf16be = b0 == 0xFE && b1 == 0xFF
        if (utf16le || utf16be) {
            throw InvalidTissXmlException(
                "encoding UTF-16 fora de escopo (TISS suporta apenas " +
                    "ISO-8859-1 e UTF-8); BOM UTF-16 detectado",
            )
        }
    }
}

/**
 * Strip do BOM UTF-8 (3 bytes `EF BB BF`) no início, se presente. Sem BOM,
 * retorna o próprio array (sem cópia).
 */
private fun stripBomUtf8(bytes: ByteArray): ByteArray {
    if (bytes.size >= 3 &&
        (bytes[0].toInt() and 0xFF) == BOM_0 &&
        (bytes[1].toInt() and 0xFF) == BOM_1 &&
        (bytes[2].toInt() and 0xFF) == BOM_2
    ) {
        return bytes.copyOfRange(3, bytes.size)
    }
    return bytes
}

/**
 * Localiza o único `<ans:hash>` do namespace TISS (URI [TISS_NAMESPACE],
 * local name `hash`), casando por **URI** e não por prefixo: assim o
 * namespace TISS como default (`xmlns="..."` sem prefixo `ans:`) também casa.
 *
 * Invariante TISS: no máximo um `<ans:hash>`. Mais de um → entrada inválida e
 * rejeitada (ambiguidade #9 / A-COV2). Documento **sem** hash é válido:
 * retorna `null` e o concat percorre tudo.
 *
 * @return o elemento hash, ou `null` se não houver nenhum
 * @throws InvalidTissXmlException se houver mais de um `<ans:hash>`
 */
private fun findSingleHash(doc: Document): Element? {
    val hashes = doc.getElementsByTagNameNS(TISS_NAMESPACE, HASH_LOCAL_NAME)
    return when (val count = hashes.length) {
        0 -> null
        1 -> hashes.item(0) as Element
        else -> throw InvalidTissXmlException(
            "documento TISS inválido: esperado no máximo um <ans:hash> " +
                "(namespace $TISS_NAMESPACE), encontrados $count",
        )
    }
}

/**
 * Walker recursivo em ordem de documento (depth-first, pre-order). Para cada
 * nó-folha (Element ou Comment sem filhos Element/Comment/PI), acumula o texto
 * em [out]. O nó [hashNode] contribui string vazia (zerar) via early-return.
 */
private fun walkInOrder(node: Node, hashNode: Node?, out: StringBuilder) {
    if (isLeafForHash(node)) {
        if (node === hashNode) {
            // zerar: contribui ""
            return
        }
        val text = textOfLeaf(node)
        if (text.isNotEmpty()) {
            out.append(text)
        }
        return
    }
    // Não-folha (tem filho Element/Comment/PI): apenas desce.
    val kids = node.childNodes
    for (i in 0 until kids.length) {
        walkInOrder(kids.item(i), hashNode, out)
    }
}

/**
 * Decide se um nó é "folha pro hash":
 *  - aceita [Element] (nodeType 1) e [Comment] (nodeType 8);
 *  - "sem filhos" no sentido da referência lxml: sem filhos
 *    Element/Comment/Processing-Instruction. Filhos Text/CDATA NÃO
 *    desclassificam (TISS não tem conteúdo misto, então elemento com só Text
 *    dentro é folha de valor).
 */
private fun isLeafForHash(node: Node): Boolean {
    val nt = node.nodeType
    if (nt != Node.ELEMENT_NODE && nt != Node.COMMENT_NODE) {
        return false
    }
    val kids = node.childNodes
    for (i in 0 until kids.length) {
        when (kids.item(i).nodeType) {
            Node.ELEMENT_NODE,
            Node.COMMENT_NODE,
            Node.PROCESSING_INSTRUCTION_NODE,
            -> return false
        }
    }
    return true
}

/**
 * Texto de um nó-folha. Para Element, concatena Text+CDATA dos filhos
 * (equivalente ao `.text` do lxml em folha). Para Comment, é o conteúdo entre
 * `<!--` e `-->`.
 *
 * Não usa `Node.getTextContent()` de Element para evitar divergência entre
 * implementações DOM: concat explícito dos filhos Text/CDATA.
 */
private fun textOfLeaf(node: Node): String {
    if (node.nodeType == Node.COMMENT_NODE) {
        return (node as Comment).data
    }
    // Element: concat dos filhos Text + CDATA literais.
    val kids = node.childNodes
    val n = kids.length
    if (n == 0) {
        return ""
    }
    if (n == 1) {
        // Caminho rápido: maioria dos casos.
        val only = kids.item(0)
        return when (only.nodeType) {
            Node.TEXT_NODE, Node.CDATA_SECTION_NODE -> only.nodeValue ?: ""
            else -> ""
        }
    }
    val sb = StringBuilder()
    for (i in 0 until n) {
        val c = kids.item(i)
        when (c.nodeType) {
            Node.TEXT_NODE, Node.CDATA_SECTION_NODE -> c.nodeValue?.let { sb.append(it) }
        }
    }
    return sb.toString()
}

/**
 * Capacidade inicial do [StringBuilder] de concat. Heurística: folhas
 * representam grosseiramente 30-60% do tamanho bruto. Inicializar perto disso
 * evita realocações em XMLs de ~600 KB (vetor de performance).
 */
private fun estimateInitialCapacity(rawSize: Int): Int =
    (rawSize / 2).coerceIn(64, 1 shl 20)

/** MD5 hex lowercase (32 chars) sobre os bytes fornecidos. */
private fun md5HexLowercase(data: ByteArray): String {
    val digest = try {
        MessageDigest.getInstance("MD5").digest(data)
    } catch (e: NoSuchAlgorithmException) {
        // MD5 é parte do contrato mínimo do JCA: nunca deveria faltar.
        throw IllegalStateException("MD5 indisponível no provider JCA atual", e)
    }
    val sb = StringBuilder(digest.size * 2)
    for (b in digest) {
        val v = b.toInt() and 0xFF
        sb.append(HEX[v ushr 4])
        sb.append(HEX[v and 0x0F])
    }
    return sb.toString()
}

private val HEX = "0123456789abcdef".toCharArray()

/**
 * Fail-fast: warning é ignorado; error/fatalError viram exceção. Sem isso, o
 * [DocumentBuilder] pode logar o erro em stderr e seguir com árvore parcial,
 * mascarando bug. Sem estado, então singleton.
 */
private object FailFastErrorHandler : ErrorHandler {
    override fun warning(exception: SAXParseException) {
        // ignorar
    }

    override fun error(exception: SAXParseException) {
        throw exception
    }

    override fun fatalError(exception: SAXParseException) {
        throw exception
    }
}
