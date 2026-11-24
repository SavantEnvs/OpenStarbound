// Audio decoder (WAV header parser + Ogg Vorbis via vorbisfile), used for every sound asset.
#include "StarAudio.hpp"
#include "StarBuffer.hpp"
#include <cstdint>
#include <cstddef>
using namespace Star;

extern "C" int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
  try {
    Audio a(make_shared<Buffer>(ByteArray((char const*)data, size)), "fuzz");
    a.totalTime();
    a.channels();
    int16_t buf[4096];
    for (int i = 0; i < 64; ++i)
      if (a.read(buf, 4096) == 0)
        break;
  } catch (std::exception const&) {}
  return 0;
}
