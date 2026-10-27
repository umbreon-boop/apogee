--[=[
	Loads icon image bytes from embedded or repository-hosted Zstandard packs and resolves icon names to local assets.

	@class AssetManager
	@location internals/assets
]=]
local Path = require("@aria/path")
local Vec = require("@aria/vec")

local Manager = {
	Repository = "https://github.com/umbreon-boop/packs/releases/latest/download/",
}
local MAGIC = "APGPK3"
local EMBEDDED = {core = base64decode(require("./core"))}
local PACK_NAMES = {
	core = true,
	feather = true,
	gravity = true,
	["heroicons-outline"] = true,
	["heroicons-solid"] = true,
	lucide = true,
	["material-design"] = true,
	sfsymbols = true,
	["tabler-filled"] = true,
	["tabler-outline"] = true,
}
local loaded = {}
local loading = {}
local loadCallbacks = {}
local RunService = game:GetService("RunService")

local function imageFolder(pack)
	return "packs/" .. string.gsub(pack, "[^%w_-]", "_")
end

local function download(pack)
	local archive = Path.Read(pack .. ".zst", "packs")
	if archive then
		return archive
	end
	local url = Manager.Repository .. pack .. ".zst"
	local result
	if RunService:IsStudio() then
		result = game:GetService("HttpService"):GetAsync(url)
	else
		-- selene: allow(incorrect_standard_library_use)
		result = game:HttpGet(url)
	end
	Path.Write(result, pack .. ".zst", "packs")
	return result
end

local function validEntry(filename)
	return string.match(filename, "^[%w_.-]+%.png$") ~= nil
end

local function extract(pack)
	local folder = imageFolder(pack)
	-- Tests provide the same local PNG entries through a deterministic local source.
	-- Roblox runtimes use the embedded core archive or fetch the sidecar below.
	-- selene: allow(undefined_variable)
	if getassetpack then
		-- selene: allow(undefined_variable)
		local source = getassetpack(pack)
		if source then
			if type(source.images) ~= "table" then
				error("Invalid local asset pack source: " .. pack)
			end
			for filename, contents in source.images do
				if not validEntry(filename) or type(contents) ~= "string" then
					error("Invalid local asset pack entry in " .. pack)
				end
				Path.Write(contents, filename, folder)
			end
			Path.Write(MAGIC, ".ready", folder)
			return true
		end
	end

	local marker = Path.Read(".ready", folder)
	if marker == MAGIC then
		return true
	end

	local archive = EMBEDDED[pack] or download(pack)
	if not archive then
		return false
	end
	local data = Vec.Decompress(buffer.fromstring(archive), 524288000).inner
	if buffer.readstring(data, 0, 6) ~= MAGIC then
		error("Invalid asset pack archive: " .. pack)
	end

	local count = buffer.readu32(data, 6)
	local offset = 10
	for _ = 1, count do
		local nameLength = buffer.readu16(data, offset)
		local contentLength = buffer.readu32(data, offset + 2)
		offset += 6
		local filename = buffer.readstring(data, offset, nameLength)
		offset += nameLength
		local contents = buffer.readstring(data, offset, contentLength)
		offset += contentLength

		if not validEntry(filename) then
			error("Invalid asset pack entry in " .. pack)
		end
		if getcustomasset then
			Path.Write(contents, filename, folder)
		end
	end
	if getcustomasset then
		Path.Write(MAGIC, ".ready", folder)
	end
	return true
end

local function imagePath(pack, name)
	local filename = string.gsub(tostring(name), "[^%w_.-]", "_") .. ".png"
	if Path.Read(filename, imageFolder(pack)) then
		return getcustomasset(imageFolder(pack) .. "/" .. filename)
	end
end

function Manager.Load(pack)
	if loaded[pack] ~= nil then
		return loaded[pack]
	end
	if not PACK_NAMES[pack] or not getcustomasset then
		return false
	end
	local ok, result = pcall(extract, pack)
	loaded[pack] = ok and result == true
	if not ok then
		warn("AssetManager: unable to load pack '" .. pack .. "': " .. tostring(result))
	end
	return loaded[pack]
end

function Manager.LoadAsync(pack, callback)
	if loaded[pack] ~= nil then
		if callback then
			task.spawn(callback, loaded[pack])
		end
		return loaded[pack]
	end
	if not PACK_NAMES[pack] or not getcustomasset then
		if callback then
			task.spawn(callback, false)
		end
		return false
	end
	if callback then
		local callbacks = loadCallbacks[pack]
		if not callbacks then
			callbacks = {}
			loadCallbacks[pack] = callbacks
		end
		table.insert(callbacks, callback)
	end
	if loading[pack] then
		return true
	end
	loading[pack] = true
	task.spawn(function()
		local succeeded = Manager.Load(pack)
		loading[pack] = nil
		local callbacks = loadCallbacks[pack]
		loadCallbacks[pack] = nil
		for _, entry in callbacks or {} do
			pcall(entry, succeeded)
		end
	end)
	return true
end

function Manager.Register(pack, _)
	assert(type(pack) == "string", "AssetManager.Register expects a pack name")
	PACK_NAMES[pack] = true
end

function Manager.Resolve(pack, name, callback)
	if not getcustomasset or not PACK_NAMES[pack] then
		return nil
	end
	if loaded[pack] == true then
		return imagePath(pack, name)
	end
	if loaded[pack] == false then
		return nil
	end
	if pack == "core" then
		if not Manager.Load("core") then
			return nil
		end
		return imagePath(pack, name)
	end
	if callback then
		Manager.LoadAsync(pack, function(succeeded)
			callback(if succeeded then imagePath(pack, name) else nil)
		end)
	else
		Manager.LoadAsync(pack)
	end
	return nil
end

function Manager.ResolveById()
	return nil
end

return Manager
