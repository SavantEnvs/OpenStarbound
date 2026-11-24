// Image directive mini-language ("?replace;..?crop;..?scale=..") parsed by Directives and
// applied by processImageOperations. Directive strings arrive from mods, players and the network.
#include "StarDirectives.hpp"
#include "StarImage.hpp"
#include "StarImageProcessing.hpp"
#include <cstdint>
#include <cstddef>
using namespace Star;

extern "C" int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
  static Image refImage = [] {
    Image r(4, 4, PixelFormat::RGBA32);
    r.fill(Vec4B(10, 20, 30, 255));
    return r;
  }();
  String s(std::string((char const*)data, size));
  try {
    Directives d(s);
    d.loadOperations();
    d.buildString();
    List<ImageOperation> ops;
    for (auto const& e : d->entries)
      ops.append(e.loadOperation(*d));
    Image img(8, 8, PixelFormat::RGBA32);
    img.fill(Vec4B(200, 100, 50, 255));
    processImageOperations(ops, img, [](String const&) -> Image const* { return &refImage; });
  } catch (std::exception const&) {}
  return 0;
}
