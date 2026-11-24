#!/usr/bin/env bash
#
# mayhem/build.sh — build this repo's fuzz harness(es). EDIT per repo.
#
# Runs inside the commit image (mayhem/Dockerfile) as `mayhem` in /mayhem. The base image
# (ghcr.io/savantenvs/base) already exports the build contract — use these, don't redefine:
#   CC, CXX             stock clang / clang++
#   LIB_FUZZING_ENGINE  -fsanitize=fuzzer   (link into each harness that has a LLVMFuzzer entry)
#   SANITIZER_FLAGS     -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer
#                       (ASan + UBSan, both set to HALT — so Mayhem catches memory AND UB defects)
#   DEBUG_FLAGS         -g -gdwarf-3   (DWARF debug info — always on for fuzz/standalone builds,
#                       independent of the sanitizer off-switch; DWARF version must be < 4)
#   RUST_DEBUG_FLAGS    -C debuginfo=2 -C force-frame-pointers=yes -C llvm-args=-gdwarf-3
#                       (thread through RUSTFLAGS on every cargo-fuzz build)
#   GO_DEBUG_FLAGS      -gcflags=all=-N -l
#                       (thread through go build / go-fuzz-build so the linked ELF keeps symbols)
#   SRC                 /mayhem (the repo source)
#
# Contract: build EVERYTHING here — one runnable binary per fuzz harness, AND the project's test
# suite (so mayhem/test.sh only has to RUN it, never compile). Keep it ADDITIVE (build upstream as
# upstream documents; don't edit upstream files). IMPORTANT: build the PROJECT ITSELF with
# $SANITIZER_FLAGS and $DEBUG_FLAGS (not just the harness) so the fuzzed code is instrumented
# AND carries DWARF < 4 symbols — otherwise ASan/UBSan only see the harness, not the library
# you're trying to find bugs in, and backtraces won't resolve project source lines. Build the TEST
# suite with the project's NORMAL flags (a clean, independent build) so test.sh stays an honest
# functional oracle and won't false-fail on benign UB. Leave the test binary/runner where test.sh
# expects it.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — it must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

# Build knobs come from the ENVIRONMENT (overridable), with sane defaults — no if-statements,
# just parameter-expansion fallbacks. Default sanitizers are the base's ASan+UBSan (halting); override
# per build via the Dockerfile's `--build-arg SANITIZER_FLAGS="..."`.
# NB: SANITIZER_FLAGS uses `=` (no colon) on purpose — `=` only fills when the var is UNSET, so an
# explicit EMPTY value (`--build-arg SANITIZER_FLAGS=`) is honored and builds with NO sanitizers
# (useful when you want the program's natural crash / full backtrace, not an ASan report). The other
# knobs use `:=` (default on empty too). MAYHEM_JOBS sets build parallelism (falls back to nproc).
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
# DEBUG_FLAGS carries DWARF debug info INDEPENDENTLY of the sanitizer off-switch (so an empty
# SANITIZER_FLAGS still yields DWARF symbols). DWARF MUST be < 4 (Mayhem triage can't read >=4); clang-19's
# plain `-g` emits DWARF-5, so `-gdwarf-3` is explicit. Apply $DEBUG_FLAGS to the fuzz/harness/standalone
# builds (NOT the test/oracle build). Rust/Go carry the same intent via their language flags below.
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${RUST_DEBUG_FLAGS:=-C debuginfo=2 -C force-frame-pointers=yes -C llvm-args=-gdwarf-3}"
: "${GO_DEBUG_FLAGS:=-gcflags=all=-N -l}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
# COVERAGE_FLAGS: empty by default → no effect on the normal oracle build. Set it via the Dockerfile's
# `--build-arg COVERAGE_FLAGS="-fprofile-instr-generate -fcoverage-mapping"` to instrument the TEST
# build for source-coverage measurement (how much of the project the test suite actually exercises —
# a quality signal for the oracle; complements the anti-reward-hack sabotage check). APPEND it to the
# test build's compile+link flags in step 3 (NOT the fuzz build); after `test.sh` runs, merge with
# `llvm-profdata` and report with `llvm-cov`. Empty value is honored (`=`, not `:=`).
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS RUST_DEBUG_FLAGS GO_DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

# UBSan relaxations (ASan and every other UBSan check stay on and halting): upstream's ByteArray
# memcpy()s from a null pointer with length 0 (StarByteArray.hpp, nonnull-attribute) and its
# FlatHashTable does iterator arithmetic on a null bucket array (StarFlatHashTable.hpp,
# pointer-overflow) on every empty container, so without this every target aborts on its first input.
if [ -n "$SANITIZER_FLAGS" ]; then SANITIZER_FLAGS="$SANITIZER_FLAGS -fno-sanitize=pointer-overflow,nonnull-attribute"; fi

ZLIBNG=/opt/toolchains/deps/zlib-ng-2.2.4
EXT_LIBS="-L$ZLIBNG/lib -lz-ng -lpng -lfreetype -lvorbisfile -lvorbis -logg -lzstd -lre2 -lpthread -ldl -lrt"
TARGETS="embedded_assets json_parse json_binary png directives btree_database decompress lua json_patch text audio font packed_assets"
BIN="$SRC/mayhem/build/bin"
mkdir -p "$BIN"

# build_variant <dir> <flags>: upstream's star_extern + star_core + star_base (mayhem/star.mk mirrors
# their CMake source lists; upstream's top-level CMake needs vcpkg + SDL/GL/cpr, which an air-gapped
# image can't fetch). A flags change wipes the variant's objects so the archives never mix flags.
build_variant() {
  local out="$1" flags="$2"
  if [ -f "$out/flags" ] && [ "$(cat "$out/flags")" != "$flags" ]; then rm -rf "$out"; fi
  mkdir -p "$out" && printf '%s' "$flags" > "$out/flags"
  make -f mayhem/star.mk -j"$MAYHEM_JOBS" OUT="$out" ZLIBNG="$ZLIBNG" EXTRA_CFLAGS="$flags"
}

# 1) The project, instrumented (ASan+UBSan halting, SanCov for libFuzzer, DWARF 3).
FUZZ_OUT="$SRC/mayhem/build/fuzz"
build_variant "$FUZZ_OUT" "$SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link"

# 2) Harnesses: libFuzzer binary + standalone reproducer each, LeakSanitizer turned off.
INCS="-isystem source/extern -Isource/extern/fmt -Isource/extern/lua -Isource/core -Isource/core/scripting -Isource/base -Isource/base/scripting"
HFLAGS="-std=c++17 -pthread -D_REENTRANT -DSTAR_LITTLE_ENDIAN -DSTAR_ARCHITECTURE_X86_64 -DSTAR_SYSTEM_LINUX -DSTAR_SYSTEM_FAMILY_UNIX -DSTAR_COMPILER_CLANG $INCS"
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c mayhem/lsan_off.cc -o "$FUZZ_OUT/lsan_off.o"
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c mayhem/imgui_stub.cc -o "$FUZZ_OUT/imgui_stub.o"
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$FUZZ_OUT/standalone_main.o"
LIBS="$FUZZ_OUT/libstar_base.a $FUZZ_OUT/libstar_core.a $EXT_LIBS"
for t in $TARGETS; do
  $CXX $SANITIZER_FLAGS $DEBUG_FLAGS $HFLAGS -fsanitize=fuzzer-no-link -c "mayhem/harnesses/fuzz_$t.cpp" -o "$FUZZ_OUT/fuzz_$t.o"
  $CXX $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE "$FUZZ_OUT/fuzz_$t.o" "$FUZZ_OUT/lsan_off.o" "$FUZZ_OUT/imgui_stub.o" $LIBS -o "$BIN/fuzz_$t"
  $CXX $SANITIZER_FLAGS $DEBUG_FLAGS "$FUZZ_OUT/standalone_main.o" "$FUZZ_OUT/fuzz_$t.o" "$FUZZ_OUT/lsan_off.o" "$FUZZ_OUT/imgui_stub.o" $LIBS -o "$BIN/fuzz_$t-standalone"
done

# 3) Upstream's core_tests (source/test, bundled gtest) with normal flags, for mayhem/test.sh.
TEST_OUT="$SRC/mayhem/build/test"
build_variant "$TEST_OUT" "-g $COVERAGE_FLAGS"
CORE_TESTS="$(sed -n '/SET (star_core_tests_SOURCES/,/)/p' source/test/CMakeLists.txt | grep -oE '[A-Za-z0-9_/.-]+\.(cc|cpp)')"
mkdir -p "$TEST_OUT/tests"
TOBJS=""
for s in $CORE_TESTS; do
  o="$TEST_OUT/tests/$(echo "$s" | tr / _).o"
  if [ ! -f "$o" ] || [ "source/test/$s" -nt "$o" ]; then
    $CXX -g -O1 $COVERAGE_FLAGS $HFLAGS -Isource/test -c "source/test/$s" -o "$o" &
  fi
  TOBJS="$TOBJS $o"
done
wait
$CXX -g $COVERAGE_FLAGS -c mayhem/imgui_stub.cc -o "$TEST_OUT/imgui_stub.o"
$CXX -g $COVERAGE_FLAGS $TOBJS "$TEST_OUT/imgui_stub.o" "$TEST_OUT/libstar_base.a" "$TEST_OUT/libstar_core.a" $EXT_LIBS -o "$BIN/core_tests"
echo "built: $(ls "$BIN" | tr '\n' ' ')"
