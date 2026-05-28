/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) Petrus Silva Costa
 */
package dev.petrus.tisshash;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Objects;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;

import org.w3c.dom.Comment;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.ErrorHandler;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;
import org.xml.sax.SAXParseException;

/**
 * Hash MD5 canônico do epílogo {@code <ans:hash>} em XMLs do
 * <strong>Padrão TISS/ANS</strong> (Padrão TISS 4.01.00 — Troca de
 * Informações em Saúde Suplementar, regulamentado pela Agência Nacional
 * de Saúde Suplementar).
 *
 * <p>Spec canônica: {@code docs/SPEC.md} no repositório principal
 * (<a href="https://github.com/petrinhu/TISS_ANS_hash">github.com/petrinhu/TISS_ANS_hash</a>).
 * Implementação de referência: {@code conformance/reference.py}
 * (Python + lxml). Este port <strong>bate byte-a-byte</strong> com a
 * referência nos 15 vetores de conformidade em
 * {@code conformance/vectors.json}.</p>
 *
 * <h2>Decisão de parser: {@code javax.xml.parsers.DocumentBuilder}</h2>
 *
 * <p>Avaliadas três opções para o port Java:</p>
 * <ul>
 *   <li><strong>{@code DocumentBuilder} (DOM W3C) — escolhida.</strong>
 *       Stdlib do JDK (zero dependência runtime), namespace-aware,
 *       suporta comentários via {@code setIgnoringComments(false)}
 *       (essencial pra ambiguidade #2 — comentários XML entram no concat).
 *       Decoda entidades XML predefinidas e CDATA por padrão.</li>
 *   <li><strong>StAX ({@code XMLStreamReader}).</strong> Streaming, exige
 *       reconstrução manual da árvore e da noção de "folha". Sem ganho real
 *       para XMLs TISS (tipicamente &lt; 10&nbsp;MB). Descartado.</li>
 *   <li><strong>JAXB / DOM4J.</strong> Overkill (JAXB foi removido do JDK
 *       e exige dep externa; DOM4J é 3rd party sem ganho sobre o DOM
 *       padrão). Descartado.</li>
 * </ul>
 *
 * <h2>Algoritmo (resumo)</h2>
 * <ol>
 *   <li>Strip de BOM UTF-8 se presente.</li>
 *   <li>Parse do XML com parser DOM seguro (FEATURE_SECURE_PROCESSING +
 *       DTD/entidades externas desabilitadas).</li>
 *   <li>Zerar o conteúdo do primeiro {@code <ans:hash>} (qualquer prefixo,
 *       namespace TISS).</li>
 *   <li>Concatenar o texto de cada <strong>nó-folha</strong> ({@link Element}
 *       ou {@link Comment} cujos filhos NÃO contêm
 *       Element/Comment/Processing-Instruction), em ordem de documento.</li>
 *   <li>MD5 dos bytes <strong>UTF-8</strong> da string concatenada — NÃO
 *       ISO-8859-1, apesar do manual TISS dizer o contrário (ver
 *       {@code conformance/AMBIGUITY_NOTES.md} item #1).</li>
 *   <li>Hex lowercase, 32 caracteres.</li>
 * </ol>
 *
 * <p>Classe sem instâncias. Métodos estáticos thread-safe (cada chamada
 * cria sua própria {@code DocumentBuilder} via factory configurada
 * localmente — o JDK não garante thread-safety da factory).</p>
 */
public final class TissHash {

    /**
     * URI do namespace do Padrão TISS/ANS. Usado para localizar
     * {@code <ans:hash>} independente do prefixo declarado no documento.
     */
    public static final String TISS_NAMESPACE =
            "http://www.ans.gov.br/padroes/tiss/schemas";

    /** Versão deste port. */
    public static final String VERSION = "0.1.0";

    /** Nome do elemento (sem prefixo) que carrega o hash no epílogo. */
    private static final String HASH_LOCAL_NAME = "hash";

    /** Bytes do BOM UTF-8 (sequence {@code EF BB BF}). */
    private static final int BOM_0 = 0xEF;
    private static final int BOM_1 = 0xBB;
    private static final int BOM_2 = 0xBF;

    private TissHash() {
        throw new AssertionError("TissHash não é instanciável");
    }

    /**
     * Calcula o hash MD5 canônico a partir dos bytes do XML.
     *
     * @param xmlBytes bytes do documento XML completo (não-nulo)
     * @return hash MD5 em hex minúsculo (32 caracteres)
     * @throws NullPointerException se {@code xmlBytes} for {@code null}
     * @throws InvalidTissXmlException se o parser rejeitar a entrada
     */
    public static String hashTiss(byte[] xmlBytes) {
        Objects.requireNonNull(xmlBytes, "xmlBytes não pode ser null");

        rejectUtf16Utf32Bom(xmlBytes);

        byte[] cleaned = stripBomUtf8(xmlBytes);

        Document doc = parseSecure(cleaned);
        Element root = doc.getDocumentElement();
        if (root == null) {
            throw new InvalidTissXmlException(
                    "XML sem documentElement (raiz ausente)");
        }

        Element hashEl = findSingleHash(doc);

        StringBuilder concat = new StringBuilder(estimateInitialCapacity(cleaned.length));
        walkInOrder(root, hashEl, concat);

        return md5HexLowercase(concat.toString().getBytes(StandardCharsets.UTF_8));
    }

    /**
     * Atalho conveniente: lê o arquivo do disco e calcula
     * {@link #hashTiss(byte[])}.
     *
     * @param path caminho do arquivo XML (não-nulo)
     * @return hash MD5 em hex minúsculo (32 caracteres)
     * @throws NullPointerException se {@code path} for {@code null}
     * @throws IOException erro de I/O ao ler o arquivo
     * @throws InvalidTissXmlException se o XML for inválido
     */
    public static String hashTissFile(Path path) throws IOException {
        Objects.requireNonNull(path, "path não pode ser null");
        byte[] raw = Files.readAllBytes(path);
        return hashTiss(raw);
    }

    // ---------------------------------------------------------------------
    // Internos — parser, walker, MD5
    // ---------------------------------------------------------------------

    /**
     * Cria DocumentBuilder com features de segurança XXE/DoS habilitadas
     * e preservação de comentários (CRÍTICA pra ambiguidade #2).
     *
     * <p>Importante: {@code setExpandEntityReferences(true)} (default) é
     * mantido pra que entidades XML predefinidas ({@code &amp; &lt; &gt;
     * &quot; &apos;}) sejam decodificadas pelo parser antes de virem como
     * texto — exigência do vetor {@code syn_entidades_xml.xml} (ambiguidade
     * #4). Entidades externas/DTDs ficam desabilitadas pelo
     * {@code disallow-doctype-decl}.</p>
     */
    private static DocumentBuilder newSecureBuilder() {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        try {
            // Segurança: rejeita DOCTYPE, entidades externas, XInclude, etc.
            factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
            factory.setFeature(
                    "http://apache.org/xml/features/disallow-doctype-decl", true);
            factory.setFeature(
                    "http://xml.org/sax/features/external-general-entities", false);
            factory.setFeature(
                    "http://xml.org/sax/features/external-parameter-entities", false);
            factory.setFeature(
                    "http://apache.org/xml/features/nonvalidating/load-external-dtd",
                    false);
            factory.setXIncludeAware(false);

            // Algoritmo: namespace-aware (precisamos comparar namespace URI
            // de <ans:hash>) e comentários preservados (ambiguidade #2).
            factory.setNamespaceAware(true);
            factory.setIgnoringComments(false);
            factory.setIgnoringElementContentWhitespace(false);
            factory.setCoalescing(false);
            // expandEntityReferences=true (default): decoda &amp; etc.

            DocumentBuilder builder = factory.newDocumentBuilder();
            builder.setErrorHandler(new FailFastErrorHandler());
            // Sem resolver de entidades externas: bloqueia network/file I/O.
            builder.setEntityResolver(
                    (publicId, systemId) -> new InputSource(
                            new ByteArrayInputStream(new byte[0])));
            return builder;
        } catch (ParserConfigurationException e) {
            throw new InvalidTissXmlException(
                    "falha ao configurar DocumentBuilder com features seguras",
                    e);
        }
    }

    /**
     * Parse seguro dos bytes. Erros de parsing viram
     * {@link InvalidTissXmlException} preservando a causa raiz.
     */
    private static Document parseSecure(byte[] bytes) {
        DocumentBuilder builder = newSecureBuilder();
        try (InputStream in = new ByteArrayInputStream(bytes)) {
            // InputSource (em InputStream): parser respeita a declaração
            // <?xml encoding="..."?> e usa o encoding declarado (ISO-8859-1
            // ou UTF-8). NÃO passar Reader (que forçaria nosso encoding).
            return builder.parse(new InputSource(in));
        } catch (SAXException e) {
            throw new InvalidTissXmlException(
                    "XML inválido: " + e.getMessage(), e);
        } catch (IOException e) {
            throw new InvalidTissXmlException(
                    "erro de I/O lendo XML em memória: " + e.getMessage(), e);
        }
    }

    /**
     * Rejeita entrada cujo BOM indica UTF-16 ou UTF-32 — encodings
     * <strong>fora de escopo</strong> do Padrão TISS (apenas ISO-8859-1 e
     * UTF-8 são suportados; ver {@code conformance/AMBIGUITY_NOTES.md} §11b).
     *
     * <p>A ordem de checagem importa: UTF-32 LE ({@code FF FE 00 00}) começa
     * com o mesmo par {@code FF FE} de UTF-16 LE — por isso UTF-32 é testado
     * <strong>antes</strong> de UTF-16 para não classificar errado.</p>
     *
     * <p>BOMs detectados:</p>
     * <ul>
     *   <li>UTF-32 LE: {@code FF FE 00 00}</li>
     *   <li>UTF-32 BE: {@code 00 00 FE FF}</li>
     *   <li>UTF-16 LE: {@code FF FE}</li>
     *   <li>UTF-16 BE: {@code FE FF}</li>
     * </ul>
     *
     * @throws InvalidTissXmlException se o BOM for UTF-16/UTF-32
     */
    private static void rejectUtf16Utf32Bom(byte[] bytes) {
        // UTF-32 antes de UTF-16: FF FE 00 00 colide com o prefixo FF FE.
        if (bytes.length >= 4) {
            int b0 = bytes[0] & 0xFF;
            int b1 = bytes[1] & 0xFF;
            int b2 = bytes[2] & 0xFF;
            int b3 = bytes[3] & 0xFF;
            boolean utf32le = b0 == 0xFF && b1 == 0xFE && b2 == 0x00 && b3 == 0x00;
            boolean utf32be = b0 == 0x00 && b1 == 0x00 && b2 == 0xFE && b3 == 0xFF;
            if (utf32le || utf32be) {
                throw new InvalidTissXmlException(
                        "encoding UTF-32 fora de escopo (TISS suporta apenas "
                                + "ISO-8859-1 e UTF-8); BOM UTF-32 detectado");
            }
        }
        if (bytes.length >= 2) {
            int b0 = bytes[0] & 0xFF;
            int b1 = bytes[1] & 0xFF;
            boolean utf16le = b0 == 0xFF && b1 == 0xFE;
            boolean utf16be = b0 == 0xFE && b1 == 0xFF;
            if (utf16le || utf16be) {
                throw new InvalidTissXmlException(
                        "encoding UTF-16 fora de escopo (TISS suporta apenas "
                                + "ISO-8859-1 e UTF-8); BOM UTF-16 detectado");
            }
        }
    }

    /**
     * Strip do BOM UTF-8 (3 bytes {@code EF BB BF}) no início, se presente.
     * Operação O(1) na maioria dos casos (sem BOM = retorna o próprio array).
     */
    private static byte[] stripBomUtf8(byte[] bytes) {
        if (bytes.length >= 3
                && (bytes[0] & 0xFF) == BOM_0
                && (bytes[1] & 0xFF) == BOM_1
                && (bytes[2] & 0xFF) == BOM_2) {
            byte[] out = new byte[bytes.length - 3];
            System.arraycopy(bytes, 3, out, 0, out.length);
            return out;
        }
        return bytes;
    }

    /**
     * Localiza o único {@code <ans:hash>} do namespace TISS (URI
     * {@link #TISS_NAMESPACE}, local name {@code "hash"}), casando por
     * <strong>URI</strong> e não por prefixo — assim o namespace TISS como
     * default ({@code xmlns="..."} sem prefixo {@code ans:}) também casa.
     *
     * <p>Invariante TISS: o documento tem <strong>no máximo um</strong>
     * {@code <ans:hash>}. Se houver mais de um, a entrada é inválida e
     * rejeitada (ambiguidade #9 / A-COV2). Documento <strong>sem</strong>
     * hash é válido: retorna {@code null} e o concat percorre tudo.</p>
     *
     * @return o elemento hash, ou {@code null} se não houver nenhum
     * @throws InvalidTissXmlException se houver mais de um {@code <ans:hash>}
     */
    private static Element findSingleHash(Document doc) {
        NodeList hashes =
                doc.getElementsByTagNameNS(TISS_NAMESPACE, HASH_LOCAL_NAME);
        int count = hashes.getLength();
        if (count == 0) {
            return null;
        }
        if (count > 1) {
            throw new InvalidTissXmlException(
                    "documento TISS inválido: esperado no máximo um "
                            + "<ans:hash> (namespace " + TISS_NAMESPACE
                            + "), encontrados " + count);
        }
        return (Element) hashes.item(0);
    }

    /**
     * Walker recursivo em ordem de documento (depth-first, pre-order).
     * Para cada nó-folha (Element ou Comment sem filhos
     * Element/Comment/PI), acumula o texto no {@code out}.
     *
     * <p>Para o nó {@code hashNode}, contribui string vazia (zerar) —
     * implementado via early-return sem acumular textContent.</p>
     */
    private static void walkInOrder(Node node, Node hashNode, StringBuilder out) {
        if (isLeafForHash(node)) {
            if (node == hashNode) {
                // zerar: contribui ""
                return;
            }
            String t = textOfLeaf(node);
            if (t != null && !t.isEmpty()) {
                out.append(t);
            }
            return;
        }
        // Não-folha (tem filho Element/Comment/PI): apenas desce.
        NodeList kids = node.getChildNodes();
        for (int i = 0; i < kids.getLength(); i++) {
            walkInOrder(kids.item(i), hashNode, out);
        }
    }

    /**
     * Decide se um nó é "folha pro hash":
     * <ul>
     *   <li>aceita {@link Element} (nodeType 1) e {@link Comment} (nodeType 8);</li>
     *   <li>"sem filhos" no sentido da referência {@code lxml}: sem filhos
     *       Element/Comment/Processing-Instruction. Filhos Text/CDATA
     *       <strong>não</strong> desclassificam (TISS não tem conteúdo
     *       misto, então um elemento com só Text dentro é folha de valor).</li>
     * </ul>
     */
    private static boolean isLeafForHash(Node node) {
        short nt = node.getNodeType();
        if (nt != Node.ELEMENT_NODE && nt != Node.COMMENT_NODE) {
            return false;
        }
        NodeList kids = node.getChildNodes();
        for (int i = 0; i < kids.getLength(); i++) {
            short ct = kids.item(i).getNodeType();
            if (ct == Node.ELEMENT_NODE
                    || ct == Node.COMMENT_NODE
                    || ct == Node.PROCESSING_INSTRUCTION_NODE) {
                return false;
            }
        }
        return true;
    }

    /**
     * Texto de um nó-folha. Para Element, concatena Text+CDATA dos filhos
     * (equivalente a {@code .text} do lxml em folha). Para Comment, é o
     * conteúdo entre {@code <!--} e {@code -->}.
     *
     * <p>Não usa {@code Node.getTextContent()} de Element para evitar
     * comportamentos divergentes em implementações DOM diversas — fazemos
     * concat explícito dos filhos Text/CDATA.</p>
     */
    private static String textOfLeaf(Node node) {
        if (node.getNodeType() == Node.COMMENT_NODE) {
            return ((Comment) node).getData();
        }
        // Element: concat dos filhos Text + CDATA literais.
        NodeList kids = node.getChildNodes();
        int n = kids.getLength();
        if (n == 0) {
            return "";
        }
        if (n == 1) {
            // Caminho rápido: 90% dos casos.
            Node only = kids.item(0);
            short t = only.getNodeType();
            if (t == Node.TEXT_NODE || t == Node.CDATA_SECTION_NODE) {
                String d = only.getNodeValue();
                return d == null ? "" : d;
            }
            return "";
        }
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < n; i++) {
            Node c = kids.item(i);
            short t = c.getNodeType();
            if (t == Node.TEXT_NODE || t == Node.CDATA_SECTION_NODE) {
                String d = c.getNodeValue();
                if (d != null) {
                    sb.append(d);
                }
            }
        }
        return sb.toString();
    }

    /**
     * Capacidade inicial do {@link StringBuilder} de concat. Heurística:
     * folhas representam grosseiramente 30-60% do tamanho bruto do XML.
     * Inicializar perto disso evita realocações em XMLs de ~600&nbsp;KB
     * (vetor de performance).
     */
    private static int estimateInitialCapacity(int rawSize) {
        // Limita pra não estourar memória em XMLs gigantes;
        // StringBuilder cresce sob demanda.
        return Math.min(Math.max(rawSize / 2, 64), 1 << 20);
    }

    /**
     * MD5 hex lowercase (32 chars) sobre os bytes fornecidos.
     */
    private static String md5HexLowercase(byte[] data) {
        try {
            MessageDigest md = MessageDigest.getInstance("MD5");
            byte[] digest = md.digest(data);
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            // MD5 é parte do contrato mínimo do JCA: nunca deveria faltar.
            throw new IllegalStateException(
                    "MD5 indisponível no provider JCA atual", e);
        }
    }

    /**
     * Fail-fast: warning é ignorado; error/fatalError viram exceção. Sem
     * isso, {@code DocumentBuilder} pode logar o erro em stderr e seguir
     * com árvore parcial — mascarando bug.
     */
    private static final class FailFastErrorHandler implements ErrorHandler {
        @Override
        public void warning(SAXParseException e) {
            // ignorar
        }

        @Override
        public void error(SAXParseException e) throws SAXException {
            throw e;
        }

        @Override
        public void fatalError(SAXParseException e) throws SAXException {
            throw e;
        }
    }
}
