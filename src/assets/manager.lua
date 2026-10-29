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
local CACHE_FOLDER = "packs/raw"
local CACHE_EXTENSION = ".bin"
local MAX_DECOMPRESSED = 524288000
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
local extracted = {}
local loading = {}
local loadCallbacks = {}
local RunService = game:GetService("RunService")

--@inline
local function imageFolder(pack)
	return "packs/" .. string.gsub(pack, "[^%w_-]", "_")
end

--@inline
local function cacheName(pack)
	return pack .. CACHE_EXTENSION
end

--@inline
local function cachePath(pack)
	return `{CACHE_FOLDER}/{cacheName(pack)}`
end

local function download(pack)
	local cached = Path.Read(cacheName(pack), CACHE_FOLDER)
	if cached then
		return cached
	end

	local url = Manager.Repository .. pack .. ".zst"
	local archive
	if RunService:IsStudio() then
		archive = game:GetService("HttpService"):GetAsync(url)
	else
		-- selene: allow(incorrect_standard_library_use)
		archive = game:HttpGet(url)
	end
	if type(archive) ~= "string" then
		warn(`AssetManager: pack request for '{pack}' returned {typeof(archive)}, expected string`)
		return nil
	end

	local ok, err = pcall(Path.Write, archive, cacheName(pack), CACHE_FOLDER)
	if not ok then
		-- selene: allow(undefined_variable)
		pcall(delfile, cachePath(pack))
		warn(`AssetManager: unable to cache pack '{pack}' at '{cachePath(pack)}' ({#archive} bytes): {err}`)
	end
	return archive
end

--@inline
local function validEntry(filename)
	return string.match(filename, "^[%w_.-]+%.png$") ~= nil
end

local function parseArchive(pack, data)
	local length = buffer.len(data)
	if length < 10 or buffer.readstring(data, 0, 6) ~= MAGIC then
		error(`Invalid asset pack archive: {pack}`)
	end

	local count = buffer.readu32(data, 6)
	local offset = 10
	local entries = {}
	for _ = 1, count do
		if offset + 6 > length then
			error(`Invalid asset pack entry in {pack}`)
		end
		local nameLength = buffer.readu16(data, offset)
		local contentLength = buffer.readu32(data, offset + 2)
		offset += 6
		if offset + nameLength + contentLength > length then
			error(`Invalid asset pack entry in {pack}`)
		end

		local filename = buffer.readstring(data, offset, nameLength)
		offset += nameLength
		if not validEntry(filename) then
			error(`Invalid asset pack entry in {pack}`)
		end
		entries[filename] = {offset = offset, length = contentLength}
		offset += contentLength
	end
	if offset ~= length then
		error(`Invalid asset pack archive: {pack}`)
	end
	return entries
end

local function decompress(archive)
	return Vec.Decompress(buffer.fromstring(archive), MAX_DECOMPRESSED).inner
end

local function extract(pack)
	local record = extracted[pack]
	if record then
		return true
	end

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
			local entries = {}
			for filename, contents in source.images do
				if not validEntry(filename) or type(contents) ~= "string" then
					error("Invalid local asset pack entry in " .. pack)
				end
				entries[filename] = contents
			end
			extracted[pack] = {entries = entries, failed = {}}
			return true
		end
	end

	local embedded = EMBEDDED[pack]
	local archive = embedded or download(pack)
	if not archive then
		return false
	end

	local ok, data = pcall(decompress, archive)
	if not ok then
		if embedded then
			error(data)
		end
		-- selene: allow(undefined_variable)
		pcall(delfile, cachePath(pack))
		archive = download(pack)
		if not archive then
			return false
		end
		data = decompress(archive)
	end

	extracted[pack] = {data = data, entries = parseArchive(pack, data), failed = {}}
	return true
end

-- selene: allow(undefined_variable)
local function fileExists(name, folder)
	-- selene: allow(undefined_variable)
	if isfile then
		-- selene: allow(undefined_variable)
		return isfile(`{folder}/{name}`)
	end
	return Path.Read(name, folder) ~= nil
end

local function imagePath(pack, name)
	local record = extracted[pack]
	if not record then
		return nil
	end

	local filename = string.gsub(tostring(name), "[^%w_.-]", "_") .. ".png"
	local entry = record.entries[filename]
	if not entry or record.failed[filename] then
		return nil
	end

	local folder = imageFolder(pack)
	if not fileExists(filename, folder) then
		local contents = if type(entry) == "string" then entry else buffer.readstring(record.data, entry.offset, entry.length)
		local ok, err = pcall(Path.Write, contents, filename, folder)
		if not ok then
			record.failed[filename] = true
			warn(`AssetManager: unable to write '{filename}' for pack '{pack}': {err}`)
			return nil
		end
	end
	return getcustomasset(folder .. "/" .. filename)
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
		warn(`AssetManager: unable to load pack '{pack}': {tostring(result)}`)
	end
	return loaded[pack]
end

function Manager.LoadAsync(pack, callback)
	if not PACK_NAMES[pack] or not getcustomasset then
		if callback then
			task.spawn(callback, false)
		end
		return false
	end
	if loaded[pack] ~= nil then
		if callback then
			task.spawn(callback, loaded[pack])
		end
		return loaded[pack]
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

function Manager.Register(pack)
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
		if not Manager.Load(pack) then
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

return Manager
