// Chat / name text: escape-code (^color;) processing and String utf8 operations.
#include "StarText.hpp"
#include "StarString.hpp"
#include <cstdint>
#include <cstddef>
using namespace Star;

extern "C" int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
  String s(std::string((char const*)data, size));
  try {
    Text::stripEscapeCodes(s);
    size_t n = 0;
    Text::processText(s, [&](StringView t) { n += t.size(); return true; },
                      [&](StringView c) { n += c.size(); return true; }, true);
    s.toUpper();
    s.splitAny(" ;,");
    s.trim();
  } catch (std::exception const&) {}
  return 0;
}
