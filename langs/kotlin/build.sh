#!/usr/bin/env bash
#
# SPDX-License-Identifier: MIT
# Copyright (c) Petrus Silva Costa
#
# Build + teste do port Kotlin SEM Gradle, usando apenas `kotlinc` + `java`.
#
# Por que este script existe (em vez de só `gradle build`):
#   - Nem todo ambiente tem Gradle instalado.
#   - kotlinc 2.1.0 tem um bug ao rodar SOB JDK 25 (falha ao parsear a versão
#     "25.0.3" do runtime no IntelliJ embarcado -> IllegalArgumentException).
#     O workaround é compilar com `-no-jdk` (desliga o jrt-fs problemático) e
#     fornecer as classes do JDK no classpath, extraídas via `jimage`.
#
# Uso:
#   ./build.sh            # compila lib + harness e roda os 20 vetores + goldens
#   ./build.sh jar        # idem + gera build/tiss-hash-kotlin-0.1.0.jar
#   ./build.sh clean      # remove artefatos de build
#
# Pré-requisitos no PATH: kotlinc (2.1.x) e um JDK (17+; testado em OpenJDK 25).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

BUILD="$HERE/build"
LIBS="$HERE/.libs"
VERSION="0.1.0"
JSON_JAR="$LIBS/json.jar"
JSON_URL="https://repo1.maven.org/maven2/org/json/json/20240303/json-20240303.jar"

log() { printf '\033[1;34m[build]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[erro]\033[0m %s\n' "$*" >&2; }

require_tool() {
  command -v "$1" >/dev/null 2>&1 || { err "'$1' não está no PATH"; exit 127; }
}

# Remoção segura: prefere a lixeira (gio trash) quando disponível, senão rm -rf.
safe_rm() {
  [[ -e "$1" ]] || return 0
  if command -v gio >/dev/null 2>&1 && gio trash "$1" 2>/dev/null; then
    return 0
  fi
  rm -rf "$1"
}

if [[ "${1:-}" == "clean" ]]; then
  log "removendo $BUILD"
  safe_rm "$BUILD"
  exit 0
fi

require_tool kotlinc
require_tool java

# --- localizar kotlin-stdlib.jar (vem com a instalação do kotlinc) ----------
# Resolução PORTÁVEL: o jar tem que ser achado tanto com o kotlinc 2.1.0 de
# ~/sdks (binário real, bin/ irmão de lib/) quanto com um kotlinc instalado
# via apt/sdkman/setup-kotlin no CI — onde `command -v kotlinc` quase sempre
# devolve um SYMLINK (ex.: /usr/bin/kotlinc -> /usr/share/kotlin/bin/kotlinc).
# Por isso seguimos o symlink com `readlink -f` antes de derivar o KOTLIN_HOME,
# e ainda assim caímos em fallbacks (locais comuns + find) se a heurística
# falhar para algum layout exótico. Nunca caminho FIXO.
find_kotlin_stdlib() {
  local bin home cand
  local -a candidates=()

  # 1) A partir do binário real do kotlinc (resolve symlinks).
  bin="$(command -v kotlinc)"
  bin="$(readlink -f "$bin" 2>/dev/null || readlink -f -- "$bin")"
  if [[ -n "$bin" ]]; then
    home="$(cd "$(dirname "$bin")/.." && pwd)"   # .../kotlinc (bin/ -> ..)
    candidates+=("$home/lib/kotlin-stdlib.jar")
  fi

  # 2) Respeita KOTLIN_HOME se o ambiente o exportou.
  [[ -n "${KOTLIN_HOME:-}" ]] && candidates+=("$KOTLIN_HOME/lib/kotlin-stdlib.jar")

  # 3) Locais comuns por gerenciador de pacote / distribuição.
  candidates+=(
    /usr/share/kotlin/lib/kotlin-stdlib.jar
    /usr/local/share/kotlin/lib/kotlin-stdlib.jar
    /opt/kotlinc/lib/kotlin-stdlib.jar
    "$HOME/.sdkman/candidates/kotlin/current/lib/kotlin-stdlib.jar"
    "$HOME/.kotlin-compiler/kotlinc/lib/kotlin-stdlib.jar"
  )

  for cand in "${candidates[@]}"; do
    [[ -f "$cand" ]] && { printf '%s\n' "$cand"; return 0; }
  done

  # 4) Último recurso: varrer KOTLIN_HOME derivado e raízes comuns com find.
  #    (versões variadas, ex. 2.3.x, podem ter layout diferente).
  local root
  for root in "$home" "${KOTLIN_HOME:-}" /usr/share /usr/local/share /opt \
              "$HOME/.sdkman/candidates/kotlin" "$HOME/.kotlin-compiler"; do
    [[ -n "$root" && -d "$root" ]] || continue
    cand="$(find "$root" -maxdepth 4 -name 'kotlin-stdlib.jar' -print -quit 2>/dev/null)"
    [[ -n "$cand" && -f "$cand" ]] && { printf '%s\n' "$cand"; return 0; }
  done

  return 1
}

STDLIB="$(find_kotlin_stdlib)" || {
  err "kotlin-stdlib.jar não encontrado (kotlinc=$(command -v kotlinc); procurei a partir do binário real, KOTLIN_HOME, locais comuns e find)"
  exit 1
}
log "kotlin-stdlib resolvido: $STDLIB"

# --- localizar JAVA_HOME (para extrair as classes do JDK) -------------------
if [[ -z "${JAVA_HOME:-}" ]]; then
  JAVA_BIN="$(command -v java)"
  JAVA_REAL="$(readlink -f "$JAVA_BIN")"
  JAVA_HOME="$(cd "$(dirname "$JAVA_REAL")/.." && pwd)"
fi
log "JAVA_HOME=$JAVA_HOME"

# --- extrair classes do JDK (java.base + java.xml) p/ classpath -------------
# Cacheado em .libs/jdk-classes; só extrai se ainda não existe.
JDK_CLASSES="$LIBS/jdk-classes"
JDK_CP="$JDK_CLASSES/java.base:$JDK_CLASSES/java.xml"
if [[ ! -d "$JDK_CLASSES/java.base" || ! -d "$JDK_CLASSES/java.xml" ]]; then
  if [[ -f "$JAVA_HOME/lib/modules" && -x "$JAVA_HOME/bin/jimage" ]]; then
    log "extraindo classes do JDK via jimage (cache em $JDK_CLASSES)"
    mkdir -p "$JDK_CLASSES"
    "$JAVA_HOME/bin/jimage" extract --dir "$JDK_CLASSES" "$JAVA_HOME/lib/modules"
  else
    err "não achei jimage/lib/modules em \$JAVA_HOME; defina JAVA_HOME para um JDK completo (não JRE)"
    exit 1
  fi
fi

# --- baixar json.jar se necessário (apenas para o harness de teste) ---------
if [[ ! -f "$JSON_JAR" ]]; then
  require_tool curl
  log "baixando json.jar (org.json, dep de teste)"
  mkdir -p "$LIBS"
  curl -fsSLo "$JSON_JAR" "$JSON_URL"
fi

KOTLINC_FLAGS=(-no-jdk -jvm-target 17 -Werror)

# --- compilar a lib (main) --------------------------------------------------
# -Xexplicit-api=strict: API pública exige visibilidade/tipo explícitos
# (disciplina de lib publicável; espelha explicitApi() do build.gradle.kts).
log "compilando lib (src/main)"
mkdir -p "$BUILD/main"
kotlinc "${KOTLINC_FLAGS[@]}" -Xexplicit-api=strict -cp "$JDK_CP" \
  src/main/kotlin/dev/petrus/tisshash/InvalidTissXmlException.kt \
  src/main/kotlin/dev/petrus/tisshash/TissHash.kt \
  -d "$BUILD/main"

# --- compilar o harness (test) ----------------------------------------------
log "compilando harness (src/test)"
mkdir -p "$BUILD/test"
kotlinc "${KOTLINC_FLAGS[@]}" -cp "$JDK_CP:$BUILD/main:$JSON_JAR" \
  src/test/kotlin/dev/petrus/tisshash/ConformanceHarness.kt \
  -d "$BUILD/test"

# --- empacotar jar da lib (opcional) ----------------------------------------
if [[ "${1:-}" == "jar" ]]; then
  JAR="$BUILD/tiss-hash-kotlin-$VERSION.jar"
  log "gerando $JAR"
  ( cd "$BUILD/main" && "$JAVA_HOME/bin/jar" --create --file "$JAR" . )
  log "jar pronto: $JAR (requer kotlin-stdlib em runtime)"
fi

# --- rodar conformidade -----------------------------------------------------
log "rodando conformidade (20 vetores + goldens reais)"
set +e
java -cp "$BUILD/test:$BUILD/main:$JSON_JAR:$STDLIB" \
  dev.petrus.tisshash.ConformanceHarness
RC=$?
set -e

if [[ $RC -eq 0 ]]; then
  log "OK: conformidade passou"
else
  err "conformidade FALHOU (exit $RC)"
fi
exit $RC
