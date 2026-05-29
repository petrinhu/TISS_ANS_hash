/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) Petrus Silva Costa
 */
@file:JvmName("ConformanceHarness")

package dev.petrus.tisshash

import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import org.json.JSONObject

/**
 * Harness standalone de conformidade do port Kotlin. Roda:
 *
 *  1. Os 20 vetores sintéticos de `conformance/vectors.json` (18 positivos +
 *     2 negativos), comparando byte-a-byte com `expected_md5` da referência
 *     Python; vetores `expect == "error"` exigem [InvalidTissXmlException].
 *  2. Os 3 goldens reais (`real_envio{1,2,3}.xml`) contra `expected_hashes.json`.
 *
 * PRIVACIDADE (LGPD): para os goldens reais NUNCA imprime o hash, o nome do
 * arquivo de operadora, nem qualquer conteúdo do XML: apenas PASS/FAIL e um
 * índice anônimo. Os sintéticos podem ter id impresso (são públicos no repo).
 *
 * Exit code 0 = tudo passou; != 0 = ao menos uma falha.
 */
fun main() {
    var failures = 0

    failures += runVectors()
    failures += runRealGoldens()

    if (failures == 0) {
        println("\nRESULTADO: TODOS OS TESTES PASSARAM")
    } else {
        println("\nRESULTADO: $failures FALHA(S)")
    }
    kotlin.system.exitProcess(if (failures == 0) 0 else 1)
}

// -------------------------------------------------------------------------
// Vetores sintéticos (públicos)
// -------------------------------------------------------------------------

private fun runVectors(): Int {
    val dir = conformanceDir()
    val vectors = loadVectors(dir)
    var pass = 0
    var fail = 0

    println("== Vetores de conformidade (conformance/vectors.json) ==")
    for (v in vectors) {
        val bytes = Files.readAllBytes(v.inputPath)
        val ok = if (v.isNegative) {
            try {
                hashTiss(bytes)
                false // deveria ter lançado
            } catch (_: InvalidTissXmlException) {
                true
            }
        } else {
            try {
                hashTiss(bytes) == v.expectedMd5
            } catch (_: Throwable) {
                false
            }
        }

        val tag = if (v.isNegative) " (negativo: deve rejeitar)" else ""
        if (ok) {
            pass++
            println("  PASS  ${v.id}$tag")
        } else {
            fail++
            // Em positivo, mostrar got/expected ajuda debug (sintético, sem PII).
            val detail = if (v.isNegative) {
                "deveria lançar InvalidTissXmlException"
            } else {
                val got = runCatching { hashTiss(bytes) }.getOrElse { "<exceção: ${it.message}>" }
                "got=$got expected=${v.expectedMd5}"
            }
            println("  FAIL  ${v.id}$tag :: $detail")
        }
    }
    println("  -> $pass/${vectors.size} PASS (${vectors.count { !it.isNegative }} positivos + " +
        "${vectors.count { it.isNegative }} negativos)")
    return fail
}

// -------------------------------------------------------------------------
// Goldens reais (PRIVADOS: sem expor hash/nome/conteúdo)
// -------------------------------------------------------------------------

private fun runRealGoldens(): Int {
    val privateDir = realXmlsDir()
    println("\n== Goldens reais (XMLs privados, validação cega LGPD) ==")
    if (privateDir == null) {
        println("  SKIP  diretório de XMLs reais não encontrado " +
            "(defina TISS_PRIVATE_XMLS); goldens não validados")
        // Não conta como falha: os reais ficam fora do repo por design.
        return 0
    }

    val expectedPath = privateDir.resolve("expected_hashes.json")
    if (!Files.isRegularFile(expectedPath)) {
        println("  SKIP  expected_hashes.json ausente em diretório privado")
        return 0
    }

    val expected = JSONObject(Files.readString(expectedPath))
    val names = listOf("real_envio1.xml", "real_envio2.xml", "real_envio3.xml")
    var pass = 0
    var fail = 0

    names.forEachIndexed { idx, name ->
        val anon = "golden #${idx + 1}"
        val xmlPath = privateDir.resolve(name)
        if (!Files.isRegularFile(xmlPath) || !expected.has(name)) {
            fail++
            println("  FAIL  $anon (arquivo ou hash esperado ausente)")
            return@forEachIndexed
        }
        val want = expected.getString(name)
        val ok = try {
            // Comparação cega: nunca imprime got nem want.
            hashTissFile(xmlPath) == want
        } catch (_: Throwable) {
            false
        }
        if (ok) {
            pass++
            println("  PASS  $anon")
        } else {
            fail++
            println("  FAIL  $anon (hash divergente; valor omitido por LGPD)")
        }
    }
    println("  -> $pass/${names.size} PASS")
    return fail
}

// -------------------------------------------------------------------------
// Carga de vetores e resolução de diretórios
// -------------------------------------------------------------------------

private data class Vector(
    val id: String,
    val inputPath: Path,
    val isNegative: Boolean,
    val expectedMd5: String?,
    val desc: String,
)

private fun loadVectors(dir: Path): List<Vector> {
    val manifest = dir.resolve("vectors.json")
    val root = JSONObject(Files.readString(manifest))
    val arr = root.getJSONArray("vectors")
    val out = ArrayList<Vector>(arr.length())
    for (i in 0 until arr.length()) {
        val v = arr.getJSONObject(i)
        val id = v.getString("id")
        val inputRel = v.getString("input")
        val expect = v.optString("expect", "hash")
        val negative = expect == "error"
        val expected = if (v.isNull("expected_md5")) null else v.getString("expected_md5")
        val desc = v.optString("desc", "")
        // Invariante: positivo deve ter md5 de 32 hex; negativo deve ter md5 null.
        if (negative) {
            require(expected == null) { "vetor negativo $id não deveria ter expected_md5" }
        } else {
            requireNotNull(expected) { "vetor positivo $id sem expected_md5" }
            require(expected.length == 32 && expected.all { it in '0'..'9' || it in 'a'..'f' }) {
                "expected_md5 de $id não é hex minúsculo de 32 chars"
            }
        }
        out.add(Vector(id, dir.resolve(inputRel).normalize(), negative, expected, desc))
    }
    return out
}

/**
 * Localiza o diretório `conformance/`:
 *  1. System property `tiss.conformance.dir`.
 *  2. Var de ambiente `TISS_CONFORMANCE_DIR`.
 *  3. Heurística relativa ao CWD.
 */
private fun conformanceDir(): Path {
    System.getProperty("tiss.conformance.dir")?.takeIf { it.isNotBlank() }?.let {
        return Paths.get(it).toAbsolutePath().normalize()
    }
    System.getenv("TISS_CONFORMANCE_DIR")?.takeIf { it.isNotBlank() }?.let {
        return Paths.get(it).toAbsolutePath().normalize()
    }
    val candidates = listOf(
        Paths.get("..", "..", "conformance"),
        Paths.get("conformance"),
        Paths.get("..", "conformance"),
        Paths.get("..", "..", "..", "conformance"),
    )
    for (c in candidates) {
        val abs = c.toAbsolutePath().normalize()
        if (Files.isDirectory(abs) && Files.isRegularFile(abs.resolve("vectors.json"))) {
            return abs
        }
    }
    error(
        "não consegui localizar diretório conformance/; " +
            "defina -Dtiss.conformance.dir=/caminho/absoluto",
    )
}

/**
 * Localiza o diretório dos XMLs reais (privados, fora do repo):
 *  1. Var de ambiente `TISS_PRIVATE_XMLS`.
 *  2. Path default `../../../_private_tiss_real_xmls` (irmão de `Projects/`).
 *
 * Retorna `null` se não encontrar (goldens são opcionais por design LGPD).
 */
private fun realXmlsDir(): Path? {
    System.getenv("TISS_PRIVATE_XMLS")?.takeIf { it.isNotBlank() }?.let {
        val p = Paths.get(it).toAbsolutePath().normalize()
        if (Files.isDirectory(p)) return p
    }
    val candidates = listOf(
        // de langs/kotlin/ -> Projects/_private_tiss_real_xmls
        Paths.get("..", "..", "..", "_private_tiss_real_xmls"),
        Paths.get("..", "..", "..", "..", "_private_tiss_real_xmls"),
    )
    for (c in candidates) {
        val abs = c.toAbsolutePath().normalize()
        if (Files.isDirectory(abs)) return abs
    }
    return null
}
