/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) Petrus Silva Costa
 */
package dev.petrus.tisshash;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Carrega {@code conformance/vectors.json} e resolve caminhos dos inputs.
 *
 * <p>Resolução do diretório {@code conformance/}:</p>
 * <ol>
 *   <li>System property {@code tiss.conformance.dir} (override explícito).</li>
 *   <li>Var de ambiente {@code TISS_CONFORMANCE_DIR}.</li>
 *   <li>Heurística relativa ao CWD: tenta {@code ../../conformance}
 *       (rodando de {@code langs/java/} via {@code mvn test}) e
 *       {@code conformance} (rodando da raiz do repo).</li>
 * </ol>
 */
final class VectorsLoader {

    private VectorsLoader() {}

    static Path conformanceDir() {
        String sys = System.getProperty("tiss.conformance.dir");
        if (sys != null && !sys.isBlank()) {
            return Paths.get(sys).toAbsolutePath().normalize();
        }
        String env = System.getenv("TISS_CONFORMANCE_DIR");
        if (env != null && !env.isBlank()) {
            return Paths.get(env).toAbsolutePath().normalize();
        }
        // Heurística: subir de langs/java/ ou estar na raiz.
        Path[] candidates = {
                Paths.get("..", "..", "conformance"),
                Paths.get("conformance"),
                Paths.get("..", "conformance"),
                Paths.get("..", "..", "..", "conformance"),
        };
        for (Path c : candidates) {
            Path abs = c.toAbsolutePath().normalize();
            if (Files.isDirectory(abs)
                    && Files.isRegularFile(abs.resolve("vectors.json"))) {
                return abs;
            }
        }
        throw new IllegalStateException(
                "não consegui localizar diretório conformance/; "
                        + "defina -Dtiss.conformance.dir=/caminho/absoluto");
    }

    static List<Vector> loadAll() throws IOException {
        Path dir = conformanceDir();
        Path manifest = dir.resolve("vectors.json");
        String raw = Files.readString(manifest, StandardCharsets.UTF_8);
        JSONObject root = new JSONObject(raw);
        JSONArray arr = root.getJSONArray("vectors");
        List<Vector> out = new ArrayList<>(arr.length());
        for (int i = 0; i < arr.length(); i++) {
            JSONObject v = arr.getJSONObject(i);
            String id = v.getString("id");
            String inputRel = v.getString("input");
            String expected = v.getString("expected_md5");
            String desc = v.optString("desc", "");
            Path inputPath = dir.resolve(inputRel).normalize();
            out.add(new Vector(id, inputPath, expected, desc));
        }
        return out;
    }

    /** Vetor de conformidade — invariantes validados no construtor. */
    static final class Vector {
        final String id;
        final Path inputPath;
        final String expectedMd5;
        final String desc;

        Vector(String id, Path inputPath, String expectedMd5, String desc) {
            this.id = Objects.requireNonNull(id);
            this.inputPath = Objects.requireNonNull(inputPath);
            this.expectedMd5 = requireMd5Hex(expectedMd5);
            this.desc = desc == null ? "" : desc;
        }

        private static String requireMd5Hex(String s) {
            Objects.requireNonNull(s, "expected_md5 null");
            if (s.length() != 32) {
                throw new IllegalArgumentException(
                        "expected_md5 deve ter 32 chars hex, recebido: " + s);
            }
            for (int i = 0; i < 32; i++) {
                char c = s.charAt(i);
                boolean ok = (c >= '0' && c <= '9')
                        || (c >= 'a' && c <= 'f');
                if (!ok) {
                    throw new IllegalArgumentException(
                            "expected_md5 não é hex minúsculo: " + s);
                }
            }
            return s;
        }

        @Override
        public String toString() {
            return id;
        }
    }
}
