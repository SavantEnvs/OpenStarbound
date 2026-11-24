// PNG image decoder (Image::readPng / readPngMetadata), used for every image asset in a mod.
#include "StarImage.hpp"
#include "StarBuffer.hpp"
#include <cstdint>
#include <cstddef>
using namespace Star;

extern "C" int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
  auto buf = make_shared<Buffer>(ByteArray((char const*)data, size));
  try {
    Image::isPng(buf);
    buf->seek(0);
    Image::readPngMetadata(buf);
  } catch (std::exception const&) {}
  try {
    buf->seek(0);
    Image img = Image::readPng(buf);
    img.size();
  } catch (std::exception const&) {}
  return 0;
}
