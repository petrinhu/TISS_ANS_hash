/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) Petrus Silva Costa
 *
 * Manifesto Gradle do port Kotlin da lib tiss-hash. Preparado para publicação
 * futura em Maven Central com as coordenadas dev.petrus:tiss-hash-kotlin.
 *
 * NOTA: o build de referência hoje roda via ./build.sh (kotlinc + java puros),
 * porque o ambiente alvo tem JDK 25, e o kotlinc 2.1.0 só compila SOB JDK 25
 * com o workaround `-no-jdk` (ver build.sh). Quando o toolchain Gradle/Kotlin
 * suportar JDK 25 nativamente, este arquivo passa a ser o caminho padrão.
 * Para construir com Gradle hoje, use um JDK 17/21 LTS como toolchain.
 */
plugins {
    kotlin("jvm") version "2.1.0"
    `java-library`
    `maven-publish`
}

group = "dev.petrus"
version = "0.1.0"

repositories {
    mavenCentral()
}

kotlin {
    jvmToolchain(17) // mínimo suportado; estável em ambientes enterprise BR
    explicitApi()    // API pública precisa de visibilidade explícita
}

dependencies {
    // Zero dependência de runtime além do kotlin-stdlib (incluído pelo plugin).
    // O parser XML e o MD5 vêm da própria JDK (javax.xml, java.security).

    // org.json: usado APENAS pelo harness de teste (carrega vectors.json).
    testImplementation("org.json:json:20240303")
    testImplementation(kotlin("test"))
}

// Diretórios não-convencionais? Não: src/main/kotlin e src/test/kotlin são
// os defaults do plugin. O harness em src/test é executável (fun main) e
// também pode rodar como teste; aqui exponho uma task de conveniência.
sourceSets {
    test {
        kotlin.srcDir("src/test/kotlin")
    }
}

tasks.register<JavaExec>("conformance") {
    group = "verification"
    description = "Roda os 20 vetores de conformidade + goldens reais (se disponíveis)."
    dependsOn("testClasses")
    mainClass.set("dev.petrus.tisshash.ConformanceHarness")
    classpath = sourceSets["test"].runtimeClasspath
    // Caminhos do conformance/ e dos XMLs reais resolvidos por env/heurística.
}

tasks.test {
    useJUnitPlatform()
}

java {
    withSourcesJar()
    // withJavadocJar(): Dokka geraria o KDoc; habilitar ao publicar.
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            artifactId = "tiss-hash-kotlin"
            from(components["java"])
            pom {
                name.set("tiss-hash (Kotlin)")
                description.set(
                    "Hash MD5 canônico do epílogo <ans:hash> de documentos do " +
                        "Padrão TISS/ANS. Port Kotlin/JVM da lib multi-linguagem.",
                )
                url.set("https://github.com/petrinhu/TISS_ANS_hash")
                licenses {
                    license {
                        name.set("MIT License")
                        url.set("https://opensource.org/licenses/MIT")
                    }
                }
                developers {
                    developer {
                        id.set("petrinhu")
                        name.set("Petrus Silva Costa")
                    }
                }
                scm {
                    url.set("https://github.com/petrinhu/TISS_ANS_hash")
                    connection.set("scm:git:https://github.com/petrinhu/TISS_ANS_hash.git")
                }
            }
        }
    }
}
