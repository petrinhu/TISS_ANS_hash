/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) Petrus Silva Costa
 */
package dev.petrus.tisshash;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.List;
import java.util.stream.Stream;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

/**
 * Suite de conformidade do port Java — roda os 15 vetores de
 * {@code conformance/vectors.json} e compara byte-a-byte com
 * {@code expected_md5} produzido pela referência Python
 * ({@code conformance/reference.py}).
 *
 * <p>Cada vetor vira um caso parametrizado; falha individual aparece
 * no relatório com o id do vetor.</p>
 */
class ConformanceTest {

    static Stream<Arguments> vectors() throws IOException {
        List<VectorsLoader.Vector> all = VectorsLoader.loadAll();
        return all.stream().map(v -> Arguments.of(v.id, v));
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("vectors")
    void conformance(String id, VectorsLoader.Vector v) throws IOException {
        byte[] bytes = Files.readAllBytes(v.inputPath);
        String got = TissHash.hashTiss(bytes);
        assertEquals(
                v.expectedMd5,
                got,
                () -> "hash divergente para " + id
                        + " (" + v.desc + ")"
                        + " — got=" + got
                        + " expected=" + v.expectedMd5);
    }

    @Test
    @DisplayName("TISS_NAMESPACE expõe a URI correta")
    void namespaceConstant() {
        assertEquals(
                "http://www.ans.gov.br/padroes/tiss/schemas",
                TissHash.TISS_NAMESPACE);
    }

    @Test
    @DisplayName("hashTissFile bate com hashTiss(readAllBytes)")
    void hashTissFileEqualsBytes() throws IOException {
        var dir = VectorsLoader.conformanceDir();
        var path = dir.resolve("inputs/syn_acento.xml");
        String fromFile = TissHash.hashTissFile(path);
        String fromBytes = TissHash.hashTiss(Files.readAllBytes(path));
        assertEquals(fromBytes, fromFile);
        // Hash conhecido da referência — prova UTF-8 nos bytes do MD5.
        assertEquals("a20afc9a89aadaa2179d03d225337662", fromFile);
    }

    @Test
    @DisplayName("hashTiss(null) lança NullPointerException")
    void rejectsNullBytes() {
        assertThrows(
                NullPointerException.class,
                () -> TissHash.hashTiss((byte[]) null));
    }

    @Test
    @DisplayName("hashTissFile(null) lança NullPointerException")
    void rejectsNullPath() {
        assertThrows(
                NullPointerException.class,
                () -> TissHash.hashTissFile(null));
    }

    @Test
    @DisplayName("XML malformado lança InvalidTissXmlException com causa")
    void malformedXmlThrows() {
        byte[] malformed = "<root><sem-fechar>".getBytes(StandardCharsets.UTF_8);
        InvalidTissXmlException ex = assertThrows(
                InvalidTissXmlException.class,
                () -> TissHash.hashTiss(malformed));
        assertNotNull(ex.getCause(), "deveria preservar causa raiz (SAXException)");
    }

    @Test
    @DisplayName("DOCTYPE/DTD embutido é REJEITADO (proteção XXE)")
    void doctypeRejected() {
        // disallow-doctype-decl=true: parser lança SAXException ao encontrar DOCTYPE.
        String xml = "<?xml version='1.0' encoding='utf-8'?>"
                + "<!DOCTYPE foo [<!ENTITY xxe SYSTEM 'file:///etc/passwd'>]>"
                + "<ans:mensagemTISS xmlns:ans=\"" + TissHash.TISS_NAMESPACE + "\">"
                + "<ans:epilogo><ans:hash>&xxe;</ans:hash></ans:epilogo>"
                + "</ans:mensagemTISS>";
        assertThrows(
                InvalidTissXmlException.class,
                () -> TissHash.hashTiss(xml.getBytes(StandardCharsets.UTF_8)));
    }

    @Test
    @DisplayName("Comentário XML contribui texto ao concat (ambiguidade #2)")
    void commentParticipatesInConcat() {
        // Documento com hash zerado e nenhum elemento-folha não-comentário:
        // sem comentário, concat = "" e MD5 = d41d8cd9...
        // Com comentário, concat = " COMENTARIO " e MD5 muda.
        String xml = "<?xml version='1.0' encoding='utf-8'?>"
                + "<ans:mensagemTISS xmlns:ans=\"" + TissHash.TISS_NAMESPACE + "\">"
                + "<ans:cabecalho><!-- COMENTARIO --></ans:cabecalho>"
                + "<ans:epilogo><ans:hash></ans:hash></ans:epilogo>"
                + "</ans:mensagemTISS>";
        String got = TissHash.hashTiss(xml.getBytes(StandardCharsets.UTF_8));
        assertNotEquals(
                "d41d8cd98f00b204e9800998ecf8427e",
                got,
                "comentário deveria contribuir conteúdo ao concat");
    }

    @Test
    @DisplayName("Documento sem nenhuma folha não-vazia tem hash MD5(\"\")")
    void emptyConcatProducesMd5OfEmptyString() {
        String xml = "<?xml version='1.0' encoding='utf-8'?>"
                + "<ans:mensagemTISS xmlns:ans=\"" + TissHash.TISS_NAMESPACE + "\">"
                + "<ans:epilogo><ans:hash>LIXO</ans:hash></ans:epilogo>"
                + "</ans:mensagemTISS>";
        // Único folha-elemento é <ans:hash>, que é zerado.
        // Não há nenhum filho Text no <ans:mensagemTISS> ou <ans:epilogo>
        // (sem indentação) — todos não-folha por terem filho Element.
        // Resultado: concat = "" => MD5("") = d41d8cd9...
        assertEquals(
                "d41d8cd98f00b204e9800998ecf8427e",
                TissHash.hashTiss(xml.getBytes(StandardCharsets.UTF_8)));
    }
}
