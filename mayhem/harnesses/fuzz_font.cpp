// Font loading (FreeType wrapper) and glyph rendering into Images.
#include "StarFont.hpp"
#include <cstdint>
#include <cstddef>
using namespace Star;

extern "C" int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
  try {
    auto font = Font::loadFont(make_shared<ByteArray>((char const*)data, size), 12);
    for (String::Char c : {(String::Char)'A', (String::Char)'g', (String::Char)0x4e2d}) {
      font->width(c);
      font->render(c);
    }
  } catch (std::exception const&) {}
  return 0;
}
