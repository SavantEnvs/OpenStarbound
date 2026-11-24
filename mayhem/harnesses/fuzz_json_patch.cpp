// .patch application (RFC 6902 + OpenStarbound extensions) and JSON path queries.
// Input: <base json> NUL <patch json array>.
#include "StarJson.hpp"
#include "StarJsonPatch.hpp"
#include "StarJsonPath.hpp"
#include <cstdint>
#include <cstddef>
#include <cstring>
using namespace Star;

extern "C" int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
  char const* p = (char const*)data;
  char const* nul = (char const*)memchr(p, 0, size);
  if (!nul)
    return -1;
  String a(std::string(p, nul - p));
  String b(std::string(nul + 1, size - (nul - p) - 1));
  Json base;
  try {
    base = Json::parse(a);
  } catch (std::exception const&) {
    return 0;
  }
  try {
    Json patch = Json::parse(b);
    if (patch.isType(Json::Type::Array))
      jsonPatch(base, patch.toArray()).repr();
  } catch (std::exception const&) {}
  try { JsonPath::Pointer(b).get(base); } catch (std::exception const&) {}
  try { JsonPath::QueryPath(b).get(base); } catch (std::exception const&) {}
  try { base.query(b); } catch (std::exception const&) {}
  return 0;
}
