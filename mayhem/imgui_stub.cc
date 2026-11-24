// source/extern/imgui_lua_bindings.cpp needs Dear ImGui (vcpkg's, newer than Debian's 1.90) and is
// only reached through LuaEngine::addImGui(), which only the graphical client (UniverseClient) calls.
// StarLua.cpp still references it, so the headless fuzz/test builds link this stand-in instead.
#include <cstdlib>
struct lua_State;
void pushImguiBindings(lua_State*) { abort(); }
