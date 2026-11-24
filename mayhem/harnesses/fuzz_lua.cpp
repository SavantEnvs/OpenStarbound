// Lua source loading in the sandboxed (safe) engine, as used for mod scripts.
#include "StarLua.hpp"
#include <cstdint>
#include <cstddef>
#include <cstring>
using namespace Star;

extern "C" int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
  // Lua's manual: "maliciously crafted binary chunks can crash the interpreter" — precompiled
  // bytecode is unverified by design, so only source text is a meaningful input.
  if (size >= 1 && data[0] == 0x1b)
    return -1;
  try {
    auto engine = LuaEngine::create(true);
    engine->setInstructionLimit(200000);
    engine->setRecursionLimit(64);
    LuaContext ctx = engine->createContext();
    ctx.load((char const*)data, size, "fuzz");
  } catch (std::exception const&) {}
  return 0;
}
