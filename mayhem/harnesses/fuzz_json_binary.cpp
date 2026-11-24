// Binary (DataStream) Json deserializer: the format of save files (VersionedJson payloads),
// .pak metadata and Json carried in network packets.
#include "StarJson.hpp"
#include "StarDataStreamDevices.hpp"
#include <cstdint>
#include <cstddef>
using namespace Star;

extern "C" int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
  try {
    DataStreamBuffer ds(ByteArray((char const*)data, size));
    Json j;
    ds >> j;
    j.repr();
    DataStreamBuffer out;
    out << j;
  } catch (std::exception const&) {}
  return 0;
}
