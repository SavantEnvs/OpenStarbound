// Json text parser (Json::parse / Json::parseJson / Json::parseSequence) and its printers.
// Mod and save JSON, .patch files and network-supplied JSON all go through this parser.
#include "StarJson.hpp"
#include "StarFormattedJson.hpp"
#include <cstdint>
#include <cstddef>
using namespace Star;

extern "C" int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
  String s(std::string((char const*)data, size));
  try {
    Json j = Json::parse(s);
    String r = j.repr(1, true);
    Json::parse(r);
  } catch (std::exception const&) {}
  try {
    Json::parseJson(s).printJson(0);
  } catch (std::exception const&) {}
  try {
    Json::parseSequence(s).repr();
  } catch (std::exception const&) {}
  try {
    FormattedJson::parse(s).repr();
  } catch (std::exception const&) {}
  return 0;
}
