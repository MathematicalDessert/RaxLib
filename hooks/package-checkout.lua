
--for p in io.stdin:lines() do end

local pack,err = loadfile("package.lua")
if pack then return pack("combine","all") end
io.stdout:write("Couldn't run package.lua: ",err,"\n")
os.exit(1)
