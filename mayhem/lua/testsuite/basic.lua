local t = {1,2,3}
local s = 0
for i,v in ipairs(t) do s = s + v end
return string.format("%d", s) .. ("x"):rep(3)
