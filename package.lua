
local lfs = require("lfs")

local ignored = {
	"Build",
	"hooks",
}

local function usage()
print([[
================ Roblox Script Package Tool ================
Combine files in (sub)directories to a single .rbxmx
	Only (supposed to) work(s) with .lua files
	Files ending on .client.lua become LocalScripts
	Files ending on .server.lua become normal Scripts
	Other files (e.g. ending on .lua) becme ModuleScripts
Created by einsteinK
Requires lfs (Lua File System) to be installed (require"fs")
============================================================
usage/help: See this message
package <directory>...: Package the given directories
	You specify which (sub)directories get packaged
	Folder Abc/def/ results in Build/Abc-def.rbxmx
	(Forward slashes become dashes, basically)
package all: Package all directories
	All folders (except Build) get packaged
combine <directory>...: Package the given directories
	Packages the given folders, as if 'package' was used
	Then combines all packages into Build/Combined.rbxmx
	Each directory gets its own folder in the resulting file
	Folder name is calculated as for all/<directory>...
combine all: Package all directories
	All folders (except Build) get combined
]])
end

local function filterMode(paths,mode,strict)
	local res = {}
	for k,v in pairs(paths) do
		if lfs.attributes(v,"mode") == mode then
			res[#res+1] = v
		elseif strict then
			error(v.." isn't a "..mode,0)
		end
	end
	return res
end

local function getFiles(path)
	local dirs = {}
	for dir in lfs.dir(path) do
		if dir:sub(1,1) ~= "." then
			dirs[#dirs+1] = dir
		end
	end
	return dirs
end

local function getFilesRecursive(path,dirs)
	dirs = dirs or {}
	for dir in lfs.dir(path) do
		if dir:sub(1,1) ~= "." then
			local p = path.."/"..dir
			dirs[#dirs+1] = p
			getFilesRecursive(p,dirs)
		end
	end
	return dirs
end

local function splitPath(path)
	if not path:find("/") then return ".",path end
	return path:match("^(.*)/([^/]+)$")
end
local function split(path)
	local res = {}
	for v in path:gmatch("[^/]+") do
		res[#res+1] = v
	end return res
end

for k,v in pairs(ignored) do
	ignored[k] = v:gsub("^/",""):gsub("/$",""):lower()
end
local function ignore(path)
	local parent,file = splitPath(path)
	parent,file = parent:lower(),file:lower()
	parent = "/"..parent.."/"
	for k,v in pairs(ignored) do
		if v == file then return true end
		if parent:find("/"..v.."/") then return true end
	end return false
end

local function removeIgnored(dirs)
	local res = {}
	for k,v in pairs(dirs) do
		if not ignore(v) then
			res[#res+1] = v
		end
	end
	return res
end

local function relativeTo(file,to)
	file,to = split(file),split(to)
	return table.concat(file,"/",#to+1)
end

local itemFormat = '<Item class="%s">\n'
local propTemplate = '<P name="%s">%s</P>\n'
local chars = {["<"] = "&lt;",[">"] = "&gt;"}

local function writeInstance(out,inst,t)
	out:write(("\t"):rep(t),itemFormat:format(inst.ClassName))
	out:write(("\t"):rep(t+1),"<Properties>\n")
	out:write(("\t"):rep(t+2),propTemplate:format("Name",inst.Name))
	if inst.File then
		out:write(("\t"):rep(t+2),'<P name="Source">')
		local f = io.open(inst.File,"r")
		for line in f:lines() do
			out:write(line:gsub("[<>]",chars),"\n")
		end
		out:write('</P>\n')
	end
	out:write(("\t"):rep(t+1),"</Properties>\n")
	for k,v in pairs(inst.Children) do
		writeInstance(out,v,t+1)
	end
	out:write(("\t"):rep(t),"</Item>\n")
end

local function writeTree(file,tree)
	--[[require("./json")
	print(json.encode(tree))
	print(file)--]]
	local out = io.open(file,"w")
	out:write('<roblox version="4">\n')
	for k,v in pairs(tree) do
		writeInstance(out,v,1)
	end
	out:write("</roblox>")
	out:close()
end

local function cleanName(path,rel)
	return (rel and rel:gsub("/$","").."/" or "")
		..path:gsub("%.client%.lua$","")
		:gsub("%.server%.lua$","")
		:gsub("%.lua$","")
end

local function getClassname(path)
	if path:find("%.server%.lua$") then
		return "Script"
	elseif path:find("%.client%.lua$") then
		return "LocalScript"
	end return "ModuleScript"
end

local function packagePaths(folder,paths,rel)
	paths = filterMode(paths,"file")
	for k,v in pairs(paths) do
		paths[k] = relativeTo(v,folder)
	end
	local tree = {Children={},Name="ROOT"}
	for k,v in pairs(paths) do
		print("\tAdding file",v)
		local parent,file = splitPath(v)
		local parents = split(parent)
		parent = tree
		for i=1,#parents do
			local p = cleanName(parents[i])
			local par = parent.Children[p]
			if p == "." then par = tree end
			if not par then
				par = {Name=p,Children={},ClassName="Folder"}
				parent.Children[p] = par
			end parent = par
		end
		local f = folder.."/"..v
		file = cleanName(file)
		local t = parent.Children[file]
		if not t then
			t = {
				Name = file,
				Children = {},
			}
			parent.Children[file] = t
		end t.File = f
		t.ClassName = getClassname(v)
	end tree = tree.Children
	if rel then
		local paths = split(rel)
		for i=#paths,1,-1 do
			tree = {{
				Name = paths[i],
				Children = tree,
				ClassName = "Folder"
			}}
		end
	end
	folder = table.concat(split(folder),"-")
	local output = "Build/"..folder..".rbxmx"
	writeTree(output,tree)
	print("\tPackaged to",output)
	return output
end

local function combinePackages(files)
	print("Combining packages")
	local out = io.open("Build/Combined.rbxmx","w")
	out:write('<roblox version="4">\n')
	for k,v in pairs(files) do
		local a,b = splitPath(v)
		print("\tAdding package",b)
		local f = io.open(v,"r")
		for line in f:lines() do
			if not line:find("^</?roblox") then
				out:write(line,"\n")
			end
		end f:close()
	end
	out:write("</roblox>")
	out:close()
	print("Combined package written to","Build/Combined.rbxmx")
end

local function packageCombined(dirs)
	lfs.mkdir("Build")
	dirs = filterMode(dirs,"directory",true)
	print("Packaging before creating a combined package...")
	local files = {}
	for k,v in pairs(dirs) do
		v = v:gsub("^%./","")
		print("Packaging directory",v)
		local all = getFilesRecursive(v)
		local rel = table.concat(split(v),"-")
		local path = packagePaths(v,all,rel)
		files[#files+1] = path
	end
	combinePackages(files)
end

local function packageDirectories(dirs)
	lfs.mkdir("Build")
	dirs = filterMode(dirs,"directory",true)
	for k,v in pairs(dirs) do
		v = v:gsub("^%./","")
		print("Packaging directory",v)
		local all = getFilesRecursive(v)
		packagePaths(v,all)
	end
end

local args = {...}
local cmd = table.remove(args,1)
cmd = cmd and cmd:lower() or "help"
if cmd == "usage" or cmd == "help" then
	usage()
elseif cmd == "package" then
	local arg = args[1]
	arg = arg and arg:lower()
	if arg == "all" then
		local dirs = getFiles(".")
		dirs = filterMode(dirs,"directory")
		dirs = removeIgnored(dirs)
		return packageDirectories(dirs)
	elseif arg then
		return packageDirectories(args)
	end usage()
elseif cmd == "combine" then
	local arg = args[1]
	arg = arg and arg:lower()
	if arg == "all" then
		local dirs = getFiles(".")
		dirs = filterMode(dirs,"directory")
		dirs = removeIgnored(dirs)
		return packageCombined(dirs)
	elseif arg then
		return packageCombined(args)
	end usage()
else
	usage()
end