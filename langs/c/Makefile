# Makefile alternativo (simples) - port C da tiss-hash.
#
# Para uso direto sem CMake. Assume `pkg-config` resolvendo libxml-2.0
# e libcrypto. Targets:
#
#   make            (= all)
#   make all        compila libtiss_hash.so + libtiss_hash.a + test_conformance
#   make test       compila e roda a suite (15 vetores)
#   make install    instala em $(PREFIX) (default /usr/local)
#   make uninstall  remove o que foi instalado
#   make clean      remove build/
#   make valgrind   roda test_conformance sob valgrind --leak-check=full
#
# Variaveis de ambiente uteis:
#   CC=clang make
#   PREFIX=/opt/tiss make install

CC          ?= cc
PREFIX      ?= /usr/local
LIBDIR      ?= $(PREFIX)/lib
INCLUDEDIR  ?= $(PREFIX)/include
PKGCONFDIR  ?= $(LIBDIR)/pkgconfig

VERSION     := 0.1.0
SOVERSION   := 0

PKG_CFLAGS  := $(shell pkg-config --cflags libxml-2.0 libcrypto)
PKG_LIBS    := $(shell pkg-config --libs   libxml-2.0 libcrypto)

CFLAGS_BASE := -std=c11 -O2 -fPIC -Iinclude \
               -Wall -Wextra -Wpedantic -Werror \
               -Wstrict-prototypes -Wmissing-prototypes \
               -Wshadow -Wpointer-arith -Wcast-qual \
               -Wwrite-strings -Wundef \
               -Wno-deprecated-declarations
CFLAGS_LIB  := $(CFLAGS_BASE) $(PKG_CFLAGS)
LDFLAGS_LIB := $(PKG_LIBS) -lpthread

BUILD       := build
LIB_SHARED  := $(BUILD)/libtiss_hash.so.$(VERSION)
LIB_SONAME  := $(BUILD)/libtiss_hash.so.$(SOVERSION)
LIB_LINK    := $(BUILD)/libtiss_hash.so
LIB_STATIC  := $(BUILD)/libtiss_hash.a
TEST_BIN    := $(BUILD)/test_conformance

SRC         := src/tiss_hash.c
OBJ         := $(BUILD)/tiss_hash.o
HDR         := include/tiss_hash.h

VEC_HEADER  := tests/test_vectors.h
VEC_JSON    := ../../conformance/vectors.json
GEN_PY      := tools/gen_test_vectors.py

INPUTS_DIR  := ../../conformance/inputs

.PHONY: all test clean install uninstall valgrind regen-vectors

all: $(LIB_STATIC) $(LIB_LINK) $(TEST_BIN)

$(BUILD):
	@mkdir -p $(BUILD)

$(VEC_HEADER): $(VEC_JSON) $(GEN_PY)
	python3 $(GEN_PY) --out $(VEC_HEADER)

regen-vectors: $(VEC_HEADER)

$(OBJ): $(SRC) $(HDR) | $(BUILD)
	$(CC) $(CFLAGS_LIB) -c $(SRC) -o $@

$(LIB_STATIC): $(OBJ)
	ar rcs $@ $<

$(LIB_SHARED): $(OBJ)
	$(CC) -shared -Wl,-soname,libtiss_hash.so.$(SOVERSION) -o $@ $(OBJ) $(LDFLAGS_LIB)

$(LIB_SONAME): $(LIB_SHARED)
	ln -sf $(notdir $(LIB_SHARED)) $@

$(LIB_LINK): $(LIB_SONAME)
	ln -sf $(notdir $(LIB_SHARED)) $@

$(TEST_BIN): tests/test_conformance.c $(VEC_HEADER) $(LIB_STATIC) $(HDR) | $(BUILD)
	$(CC) $(CFLAGS_BASE) -Itests -Iinclude tests/test_conformance.c \
		$(LIB_STATIC) $(LDFLAGS_LIB) -o $@

test: $(TEST_BIN)
	$(TEST_BIN) $(INPUTS_DIR)

valgrind: $(TEST_BIN)
	valgrind --error-exitcode=23 --leak-check=full --show-leak-kinds=all \
		--errors-for-leak-kinds=definite,indirect \
		$(TEST_BIN) $(INPUTS_DIR)

install: all
	install -d $(DESTDIR)$(INCLUDEDIR)
	install -m 644 $(HDR) $(DESTDIR)$(INCLUDEDIR)/tiss_hash.h
	install -d $(DESTDIR)$(LIBDIR)
	install -m 644 $(LIB_STATIC) $(DESTDIR)$(LIBDIR)/libtiss_hash.a
	install -m 755 $(LIB_SHARED) $(DESTDIR)$(LIBDIR)/libtiss_hash.so.$(VERSION)
	ln -sf libtiss_hash.so.$(VERSION) $(DESTDIR)$(LIBDIR)/libtiss_hash.so.$(SOVERSION)
	ln -sf libtiss_hash.so.$(VERSION) $(DESTDIR)$(LIBDIR)/libtiss_hash.so
	install -d $(DESTDIR)$(PKGCONFDIR)
	sed -e 's|@CMAKE_INSTALL_PREFIX@|$(PREFIX)|g' \
	    -e 's|@CMAKE_INSTALL_LIBDIR@|lib|g' \
	    -e 's|@CMAKE_INSTALL_INCLUDEDIR@|include|g' \
	    -e 's|@PROJECT_VERSION@|$(VERSION)|g' \
	    -e 's|@PROJECT_DESCRIPTION@|Hash MD5 do epilogo XML TISS/ANS|g' \
	    -e 's|@PROJECT_HOMEPAGE_URL@|https://github.com/petrinhu/TISS_ANS_hash|g' \
	    tiss-hash.pc.in > $(DESTDIR)$(PKGCONFDIR)/tiss-hash.pc

uninstall:
	rm -f $(DESTDIR)$(INCLUDEDIR)/tiss_hash.h
	rm -f $(DESTDIR)$(LIBDIR)/libtiss_hash.a
	rm -f $(DESTDIR)$(LIBDIR)/libtiss_hash.so
	rm -f $(DESTDIR)$(LIBDIR)/libtiss_hash.so.$(SOVERSION)
	rm -f $(DESTDIR)$(LIBDIR)/libtiss_hash.so.$(VERSION)
	rm -f $(DESTDIR)$(PKGCONFDIR)/tiss-hash.pc

clean:
	rm -rf $(BUILD)
