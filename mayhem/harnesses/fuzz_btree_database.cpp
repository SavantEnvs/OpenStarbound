// BTreeDB5 database reader (world / universe saves): header, index and leaf node parsing.
#include "StarBTreeDatabase.hpp"
#include "StarBuffer.hpp"
#include "StarLogging.hpp"
#include <cstdint>
#include <cstddef>
using namespace Star;

extern "C" int LLVMFuzzerInitialize(int*, char***) {
  // close() logs "flattening" at Info level for every input with free blocks.
  Logger::removeStdoutSink();
  return 0;
}

extern "C" int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
  // An empty device makes open() create a fresh database instead of reading one.
  if (size == 0)
    return -1;
  auto buf = make_shared<Buffer>(ByteArray((char const*)data, size));
  BTreeDatabase db;
  try {
    db.setAutoCommit(false);
    db.setIODevice(buf);
    db.open();
    uint32_t ks = db.keySize();
    if (ks > 0 && ks <= 256) {
      ByteArray lo(ks, 0), hi(ks, (char)0xff);
      size_t n = 0;
      db.forEach(lo, hi, [&](ByteArray, ByteArray) { ++n; });
      db.find(lo);
      db.recordCount();
    }
    // close() flattens/commits the free-block list read from the file (tryFlatten, doCommit);
    // run it here so a corrupt image's IOException is caught like any other parse error.
    db.close();
  } catch (std::exception const&) {
    // A failed open/close leaves the db open with a partial commit pending, and ~BTreeDatabase
    // would retry close() and throw from a noexcept destructor. Make the device read-only and
    // drop the pending state so the destructor's close() has nothing left to write.
    buf->open(IOMode::Read);
    try { db.rollback(); } catch (std::exception const&) {}
  }
  return 0;
}
