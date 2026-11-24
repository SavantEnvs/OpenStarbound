// zlib / gzip / zstd decompression wrappers used for network packets, embedded asset data and saves.
#include "StarCompression.hpp"
#include "StarZSTDCompression.hpp"
#include <cstdint>
#include <cstddef>
using namespace Star;

extern "C" int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
  char const* p = (char const*)data;
  size_t const limit = 1 << 22;
  try { uncompressData(p, size, limit); } catch (std::exception const&) {}
  try { uncompressDataGzip(p, size, limit); } catch (std::exception const&) {}
  try { ZstdCompression::decompress(p, size); } catch (std::exception const&) {}
  try {
    DecompressionStream ds;
    ByteArray out;
    size_t half = size / 2;
    ds.decompress(p, half, out);
    ds.decompress(p + half, size - half, out);
  } catch (std::exception const&) {}
  return 0;
}
