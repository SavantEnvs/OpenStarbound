# mayhem/star.mk — builds upstream's star_extern + star_core + star_base object libraries (the same
# source lists as source/extern, source/core and source/base CMakeLists.txt, unix branch) into
# static archives, without the vcpkg/GUI/cpr dependencies the top-level CMake project requires.
# Run from the repo root:  make -f mayhem/star.mk OUT=<dir> EXTRA_CFLAGS="..."
# The archives only pull in the objects a binary references, so StarHttpClient.cpp (cpr) is the
# only source left out.

OUT ?= mayhem/build/fuzz
EXTRA_CFLAGS ?=
ZLIBNG ?= /opt/toolchains/deps/zlib-ng-2.2.4
S := source

DEFS := -D_REENTRANT -DSTAR_LITTLE_ENDIAN -DSTAR_ARCHITECTURE_X86_64 -DSTAR_SYSTEM_LINUX \
        -DSTAR_SYSTEM_FAMILY_UNIX -DSTAR_COMPILER_CLANG -DLUA_USE_LINUX -DWITH_GZFILEOP
INCS := -isystem $(S)/extern -I$(S)/extern/fmt -I$(S)/extern/lua -I$(S)/core -I$(S)/core/scripting \
        -I$(S)/base -I$(S)/base/scripting -I$(ZLIBNG)/include -isystem /usr/include/freetype2
CFLAGS_ALL   := -pthread -O1 $(DEFS) $(INCS) $(EXTRA_CFLAGS)
CXXFLAGS_ALL := -std=c++17 -Wno-everything $(CFLAGS_ALL)

EXTERN_C := $(wildcard $(S)/extern/lua/*.c) $(S)/extern/xxhash.c \
            $(addprefix $(S)/extern/curve25519/source/,sha512.c curve25519_dh.c curve25519_mehdi.c \
              curve25519_order.c curve25519_utils.c custom_blind.c ed25519_sign.c ed25519_verify.c)
EXTERN_CXX := $(S)/extern/fmt/format.cc
CORE_CXX := $(filter-out %_windows.cpp $(S)/core/StarHttpClient.cpp,$(wildcard $(S)/core/*.cpp)) \
            $(wildcard $(S)/core/scripting/*.cpp)
BASE_CXX := $(wildcard $(S)/base/*.cpp) $(wildcard $(S)/base/scripting/*.cpp)

obj = $(patsubst $(S)/%,$(OUT)/obj/%.o,$(1))

CORE_OBJS := $(call obj,$(EXTERN_C) $(EXTERN_CXX) $(CORE_CXX)) $(OUT)/obj/StarVersion.cpp.o
BASE_OBJS := $(call obj,$(BASE_CXX))

all: $(OUT)/libstar_core.a $(OUT)/libstar_base.a

$(OUT)/libstar_core.a: $(CORE_OBJS)
	rm -f $@ && ar rcs $@ $^

$(OUT)/libstar_base.a: $(BASE_OBJS)
	rm -f $@ && ar rcs $@ $^

$(OUT)/obj/%.c.o: $(S)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS_ALL) -c $< -o $@

$(OUT)/obj/%.cc.o: $(S)/%.cc
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS_ALL) -c $< -o $@

$(OUT)/obj/%.cpp.o: $(S)/%.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS_ALL) -c $< -o $@

$(OUT)/StarVersion.cpp: $(S)/core/StarVersion.cpp.in
	@mkdir -p $(dir $@)
	sed -e 's/$${STAR_SOURCE_IDENTIFIER}/mayhem/' -e 's/$${STAR_SYSTEM} $${STAR_ARCHITECTURE}/linux x86_64/' $< > $@

$(OUT)/obj/StarVersion.cpp.o: $(OUT)/StarVersion.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS_ALL) -c $< -o $@

.PHONY: all
