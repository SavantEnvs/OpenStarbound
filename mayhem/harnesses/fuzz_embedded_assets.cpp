// OpenStarbound embedded asset data: asset paths of the form
//   /opensb_data;<text|json|bin|image>;[gzip|zlib|zstd;]<base64>[;frames;<embedded frames>|;framespath;<path>]
// resolved through the public Assets::bytes / Assets::json / Assets::image API (StarAssets.cpp
// loadEmbeddedData: base64 decode, decompression, binary Json, PNG, frames specification). Such
// paths come from mods and from other players over the network (allowRemoteAssets defaults to on).
// The input is the whole asset path (directives after '?' included).
#include "StarAssets.hpp"
#include "StarAssetPath.hpp"
#include "StarRootBase.hpp"
#include "StarConfiguration.hpp"
#include "StarImage.hpp"
#include "StarLogging.hpp"
#include <cstdint>
#include <cstddef>
#include <cstdlib>
#include <cstdio>
#include <string>
#include <unistd.h>
using namespace Star;

namespace {
// Assets' constructor reads safe.allowRemoteAssets from RootBase::singleton().configuration();
// this is the minimal RootBase it needs (the game's Root would need the proprietary base assets).
class FuzzRoot : public RootBase {
public:
  FuzzRoot() {
    m_configuration = make_shared<Configuration>(Json(JsonObject{{"safe", JsonObject{{"allowRemoteAssets", true}}}}),
                                                 Json(JsonObject{{"safe", JsonObject{{"allowRemoteAssets", true}}}}));
    char const* t = getenv("TMPDIR");
    std::string dir = std::string(t && *t ? t : "/tmp") + "/osb_fuzz_assets_XXXXXX";
    if (!mkdtemp(&dir[0]))
      abort();
    // The one file Assets' constructor requires: preload.config, an (empty) list of assets to pin.
    FILE* f = fopen((dir + "/preload.config").c_str(), "w");
    if (!f)
      abort();
    fputs("[]\n", f);
    fclose(f);
    Assets::Settings settings;
    settings.assetTimeToLive = 30;
    settings.audioDecompressLimit = 0;
    settings.workerPoolSize = 1;
    m_assets = make_shared<Assets>(settings, StringList{String(dir)});
  }
  AssetsConstPtr assets() override { return m_assets; }
  ConfigurationPtr configuration() override { return m_configuration; }
  AssetsPtr m_assets;
  ConfigurationPtr m_configuration;
};
FuzzRoot* g_root;
}

extern "C" int LLVMFuzzerInitialize(int*, char***) {
  // Assets::loadAsset logs every rejected path at Error level with a printed backtrace
  // (StarAssets.cpp, outputException(e, true)); on stdout that reads to triage as a crash.
  // Real faults still surface through ASan/UBSan.
  Logger::removeStdoutSink();
  g_root = new FuzzRoot();
  return 0;
}

extern "C" int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
  // Each input starts from an empty asset cache, so its result depends only on itself.
  g_root->m_assets->clearCache();
  String path(std::string((char const*)data, size));
  try { g_root->m_assets->bytes(path, true); } catch (std::exception const&) {}
  try { g_root->m_assets->json(path).repr(); } catch (std::exception const&) {}
  try {
    auto img = g_root->m_assets->image(AssetPath::split(path));
    if (img) img->size();
  } catch (std::exception const&) {}
  return 0;
}
