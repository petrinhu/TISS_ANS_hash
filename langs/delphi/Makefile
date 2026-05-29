# Makefile - port Object Pascal (Free Pascal / compat Delphi) da lib tiss-hash.
#
# Alvos:
#   make            -> compila lib + CLI + testes (em build/)
#   make test       -> roda os 20 vetores de conformidade (exit != 0 se falhar)
#   make goldens    -> roda os 3 goldens reais (PASS/FAIL apenas; privados)
#   make check      -> test + goldens
#   make clean      -> manda artefatos de build pra lixeira (gio trash)
#
# Requer: fpc (Free Pascal Compiler) 3.2+ no PATH.
#
# Licenca: MIT.

FPC      ?= fpc
SRC      := src
BUILD    := build
# -O2: otimizacao; -Fu: unit path; -FE/-FU: saida de binarios/units.
FPCFLAGS := -O2 -Mdelphi -Fu$(SRC) -FE$(BUILD) -FU$(BUILD)

CONF_DIR ?= ../../conformance

.PHONY: all test goldens check clean dirs

all: dirs $(BUILD)/tisshash_cli $(BUILD)/conformance_test $(BUILD)/golden_test

dirs:
	@mkdir -p $(BUILD)

$(BUILD)/tisshash_cli: $(SRC)/tisshash_cli.pas $(SRC)/TissHash.pas | dirs
	$(FPC) $(FPCFLAGS) $(SRC)/tisshash_cli.pas

$(BUILD)/conformance_test: $(SRC)/conformance_test.pas $(SRC)/TissHash.pas | dirs
	$(FPC) $(FPCFLAGS) $(SRC)/conformance_test.pas

$(BUILD)/golden_test: $(SRC)/golden_test.pas $(SRC)/TissHash.pas | dirs
	$(FPC) $(FPCFLAGS) $(SRC)/golden_test.pas

test: $(BUILD)/conformance_test
	$(BUILD)/conformance_test $(CONF_DIR)

# Goldens: privados, fora do repo. Passe TISS_PRIVATE_XMLS ou deixe o default.
goldens: $(BUILD)/golden_test
	$(BUILD)/golden_test

check: test goldens

clean:
	@gio trash $(BUILD) 2>/dev/null || true
