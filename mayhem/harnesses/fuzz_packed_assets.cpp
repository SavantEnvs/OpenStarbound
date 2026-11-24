// SBAsset6 .pak archive reader (PackedAssetSource): header, metadata, index and entry reads.
// Mods are distributed as .pak files.
#include "StarPackedAssetSource.hpp"
#include "StarFile.hpp"
#include <cstdint>
#include <cstddef>
#include <cstdlib>
#include <unistd.h>
using namespace Star;

extern "C" int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
  static std::string path = [] {
    char const* t = getenv("TMPDIR");
    std::string p = std::string(t && *t ? t : "/tmp") + "/osb_fuzz_pak_XXXXXX";
    int fd = mkstemp(&p[0]);
    if (fd >= 0) close(fd);
    return p;
  }();
  FILE* f = fopen(path.c_str(), "wb");
  if (!f)
    return 0;
  fwrite(data, 1, size, f);
  fclose(f);
  try {
    PackedAssetSource pak{String(path)};
    pak.metadata();
    size_t n = 0;
    for (auto const& p : pak.assetPaths()) {
      pak.read(p);
      if (++n >= 64)
        break;
    }
  } catch (std::exception const&) {}
  return 0;
}
