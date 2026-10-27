--[[
	A mocked Roblox environment for the interface tests: instances, signals, services, rendering and input.
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local base64Values = {}
for index = 1, #base64Alphabet do
	base64Values[string.sub(base64Alphabet, index, index)] = index - 1
end

local function decodeBase64(input: string): string
	local output, chunk = {}, {}
	local value, bits = 0, 0
	for index = 1, #input do
		local character = string.sub(input, index, index)
		if character == "=" then
			break
		end
		local digit = base64Values[character]
		if digit ~= nil then
			value = value * 64 + digit
			bits += 6
			if bits >= 8 then
				bits -= 8
			chunk[#chunk + 1] = string.char(math.floor(value / 2 ^ bits) % 256)
				value %= 2 ^ bits
				if #chunk == 8192 then
					output[#output + 1] = table.concat(chunk)
					table.clear(chunk)
				end
			end
		end
	end
	output[#output + 1] = table.concat(chunk)
	return table.concat(output)
end

local BUNDLE = process.args[1] or "dist/showcase.lua"
local SANDBOX = (process.env.TMPDIR or "/tmp") .. "/affluent-tests"

-- Empties the saved configuration directory, so a bundle never reads the state of the one before it
local function resetSandbox()
	if fs.isDir(SANDBOX) then
		fs.removeDir(SANDBOX)
	end
	fs.writeDir(SANDBOX)
end
resetSandbox()

-- lune stores UDim offsets as 32 bit integers: 0.10.5 truncated them and 0.11.0 rejects them, while the
-- interface works in sub-pixel values. The mock truncates at construction, which is how the tests always
-- read the geometry back. Real constructors are kept for every other call.
local function trunc(value: number?): number?
	if value == nil then
		return nil
	end
	if value < 0 then
		return math.ceil(value)
	end
	return math.floor(value)
end

local UDim, UDim2 = roblox.UDim, roblox.UDim2
local TRUNCATED_UDIM = setmetatable({}, {__index = UDim})
TRUNCATED_UDIM.new = function(scale, offset)
	return UDim.new(scale or 0, trunc(offset))
end

local TRUNCATED_UDIM2 = setmetatable({}, {__index = UDim2})
TRUNCATED_UDIM2.new = function(...)
	-- two arguments is the (x UDim, y UDim) form, whose offsets are already whole
	if select("#", ...) == 2 then
		return UDim2.new(...)
	end
	local xScale, xOffset, yScale, yOffset = ...
	return UDim2.new(xScale, trunc(xOffset), yScale, trunc(yOffset))
end
TRUNCATED_UDIM2.fromOffset = function(x, y)
	return UDim2.fromOffset(trunc(x), trunc(y))
end

-- test files build geometry too, so they read the same truncated datatypes as the bundle
local ROBLOX = setmetatable({UDim = TRUNCATED_UDIM, UDim2 = TRUNCATED_UDIM2}, {__index = roblox})

-- signals ---------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({_handlers = {}, _waiting = {}}, Signal)
end

function Signal:Connect(handler)
	local entry = {handler = handler}
	table.insert(self._handlers, entry)
	return {
		Connected = true,
		Disconnect = function(connection)
			connection.Connected = false
			entry.dead = true
		end
	}
end

function Signal:Wait()
	table.insert(self._waiting, coroutine.running())
	return coroutine.yield()
end

function Signal:Fire(...)
	for _, entry in table.clone(self._handlers) do
		if not entry.dead then
			local ok, err = pcall(entry.handler, ...)
			if not ok then
				error(err, 0)
			end
		end
	end
	local waiting = self._waiting
	self._waiting = {}
	for _, thread in waiting do
		task.spawn(thread, ...)
	end
end

-- instances -------------------------------------------------------------------
local EVENTS = {
	MouseButton1Click = true,
	Activated = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	MouseEnter = true,
	MouseLeave = true,
	InputBegan = true,
	InputChanged = true,
	InputEnded = true,
	Focused = true,
	FocusLost = true,
	Destroying = true,
	Changed = true
}
local LAYOUT = {AbsoluteSize = true, AbsolutePosition = true, TextBounds = true, AbsoluteContentSize = true}
local camera

-- the size of a text, the same rule for TextBounds and for TextService
local function textSize(text: string, size: number, width: number?): any
	local line = #text * size * 0.5
	local wrap = math.huge
	if width and width > 0 and width < math.huge then wrap = width end
	local lines = 0
	if line ~= 0 then lines = math.max(1, math.ceil(line / wrap)) end
	return roblox.Vector2.new(math.min(line, wrap), lines * size * 1.2)
end

-- Like Roblox, TextBounds follows a new Text only after the next render; `step` renders the pending texts
local pendingText = {}
local NOT_GUI = {Folder = true, PlayerGui = true, CoreGui = true, Lighting = true}
local InstanceMt = {}
local Instance = {}

local function data(instance)
	return rawget(instance, "_d")
end

local function method(instance, key)
	local d = data(instance)
	if key == "IsA" then
		return function(_, class)
			if class == "GuiBase2d" or class == "GuiObject" then
				return string.sub(d.ClassName, 1, 2) ~= "UI" and not NOT_GUI[d.ClassName]
			end
			return d.ClassName == class
		end
	elseif key == "GetChildren" then
		return function()
			return table.clone(d.children)
		end
	elseif key == "Destroy" then
		return function(target)
			local function destroy(item)
				local itemData = data(item)
				itemData.destroyed = true
				if itemData.events.Destroying then
					itemData.events.Destroying:Fire()
				end
				for _, child in table.clone(itemData.children) do
					destroy(child)
				end
			end
			destroy(target)
			target.Parent = nil
		end
	elseif key == "FindFirstChild" then
		return function(_, name)
			for _, child in d.children do
				if child.Name == name then
					return child
				end
			end
			return nil
		end
	elseif key == "FindFirstChildOfClass" then
		return function(_, class)
			for _, child in d.children do
				if data(child).ClassName == class then
					return child
				end
			end
			return nil
		end
	elseif key == "GetPropertyChangedSignal" then
		return function(_, property)
			d.propertySignals[property] = d.propertySignals[property] or Signal.new()
			return d.propertySignals[property]
		end
	elseif key == "IsFocused" then
		return function()
			return false
		end
	end
	return nil
end

InstanceMt.__index = function(instance, key)
	local d = data(instance)
	local value = d.props[key]
	if value ~= nil then
		return value
	elseif key == "ClassName" or key == "Name" then
		return d.ClassName
	elseif key == "Parent" then
		return d.parent
	end

	local found = method(instance, key)
	if found then
		return found
	elseif EVENTS[key] then
		d.events[key] = d.events[key] or Signal.new()
		return d.events[key]
	elseif key == "TextBounds" then
		local size = d.props.Size
		local width
		if d.props.TextWrapped and size then width = size.X.Offset end
		return textSize(d.rendered or "", d.props.TextSize or 14, width)
	elseif key == "AbsoluteSize" and d.ClassName == "ScreenGui" then
		local topLeft = roblox.Vector2.new(0, 36)
		if d.props.IgnoreGuiInset == true then topLeft = roblox.Vector2.new(0, 0) end
		return camera.ViewportSize - topLeft
	elseif LAYOUT[key] then
		return roblox.Vector2.new(100, 20)
	elseif key == "CursorPosition" then
		return -1
	end

	for _, child in d.children do
		if child.Name == key then
			return child
		end
	end
	return nil
end

InstanceMt.__newindex = function(instance, key, value)
	local d = data(instance)
	if key == "Parent" then
		if d.parent then
			local siblings = data(d.parent).children
			local index = table.find(siblings, instance)
			if index then
				table.remove(siblings, index)
			end
		end
		d.parent = value
		if value then
			table.insert(data(value).children, instance)
		end
		return
	end

	-- reject writes that Roblox rejects
	if value == nil and key ~= "Image" then
		error("nil assigned to " .. d.ClassName .. "." .. key)
	elseif EVENTS[key] or LAYOUT[key] then
		error("read only property " .. key)
	end

	if key == "Text" then
		pendingText[instance] = true
	end
	-- Roblox stores transparency values as 32 bit floats, so a value read back differs a little from the written one
	if type(value) == "number" and string.find(key, "Transparency", 1, true) then
		value = string.unpack("f", string.pack("f", value))
	end
	local old = d.props[key]
	d.props[key] = value
	if old ~= value and d.propertySignals[key] then
		d.propertySignals[key]:Fire()
	end
end

InstanceMt.__tostring = function(instance)
	return "Instance(" .. data(instance).ClassName .. ")"
end

function Instance.new(class)
	return setmetatable({
		_d = {ClassName = class, props = {}, children = {}, events = {}, propertySignals = {}}
	}, InstanceMt)
end

-- services --------------------------------------------------------------------
local renderStepped = Signal.new()
local viewportChanged = Signal.new()
camera = {
	ViewportSize = roblox.Vector2.new(1920, 1080),
	GetPropertyChangedSignal = function()
		return viewportChanged
	end
}
local input = {
	InputBegan = Signal.new(),
	InputChanged = Signal.new(),
	InputEnded = Signal.new(),
	TouchEnabled = false,
	GetFocusedTextBox = function()
		return nil
	end,
	IsMouseButtonPressed = function()
		return false
	end,
	IsKeyDown = function()
		return false
	end
}
local services = {
	RunService = {
		Heartbeat = renderStepped,
		RenderStepped = renderStepped,
		IsStudio = function()
			return true
		end
	},
	UserInputService = input,
	GuiService = {
		GetGuiInset = function()
			return roblox.Vector2.new(0, 36), roblox.Vector2.zero
		end
	},
	TweenService = {
		Create = function(_, instance, _, properties)
			local completed = Signal.new()
			local cancelled = false
			return {
				Play = function()
					if cancelled then
						return
					end
					for key, value in properties do
						instance[key] = value
					end
					completed:Fire(roblox.Enum.PlaybackState.Completed)
				end,
				Cancel = function()
					cancelled = true
					completed:Fire(roblox.Enum.PlaybackState.Cancelled)
				end,
				Completed = completed
			}
		end
	},
	TextService = {
		GetTextBoundsAsync = function(_, params)
			return textSize(params.Text or "", params.Size or 14, params.Width)
		end,
		GetTextSize = function(_, text, size, _font, frame)
			local line = math.max(#text, 1) * size * 0.5
			local width = line
			if frame and frame.X < math.huge then width = frame.X end
			local lines = math.max(1, math.ceil(line / math.max(width, 1)))
			return roblox.Vector2.new(math.min(line, width), lines * size * 1.2)
		end
	},
	Players = {
		LocalPlayer = {
			PlayerGui = Instance.new("PlayerGui"),
			GetMouse = function()
				return {X = 0, Y = 0}
			end
		}
	},
	Workspace = {CurrentCamera = camera},
	CoreGui = Instance.new("CoreGui"),
	HttpService = {
		JSONDecode = function(_, value)
			return serde.decode("json", value)
		end,
		JSONEncode = function(_, value)
			return serde.encode("json", value)
		end
	}
}

-- The asset mock reads the embedded core archive and exposes its PNG entries as a local
-- source. Other packs use a small fixture of names exercised by the test suite. Local
-- URLs are the only successful result; unresolved assets never get an rbxasset fallback.
local function readArchive(encoded)
	local compressed = serde.decompress("zstd", decodeBase64(encoded))
	local bitLength = buffer.readu32(buffer.fromstring(compressed), 0)
	local archive = string.sub(compressed, 5)
	assert(bitLength == #archive * 8, "src/assets/core.lua has an invalid archive length")
	assert(string.sub(archive, 1, 6) == "APGPK3", "src/assets/core.lua does not contain an APGPK3 archive")
	local data = buffer.fromstring(archive)
	local count = buffer.readu32(data, 6)
	local offset = 10
	local entries = {}
	for _ = 1, count do
		local nameLength = buffer.readu16(data, offset)
		local contentLength = buffer.readu32(data, offset + 2)
		offset += 6
		local name = buffer.readstring(data, offset, nameLength)
		offset += nameLength + contentLength
		entries[#entries + 1] = name
	end
	return entries
end

local coreSource = fs.readFile("src/assets/core.lua")
local coreEncoded = string.match(coreSource, '^%s*return%s*"(.-)"%s*$')
assert(coreEncoded, "src/assets/core.lua must contain a returned Base64 string")
local coreEntries = readArchive(coreEncoded)

local TEST_PACKS = {
	lucide = {"house", "orbit", "star", "layers", "home", "square"},
	sfsymbols = {"house"},
	gravity = {"house"},
	feather = {"home"},
	["heroicons-outline"] = {"home"},
	["heroicons-solid"] = {"home"},
	["material-design"] = {"home"},
	["tabler-outline"] = {"home"},
	["tabler-filled"] = {"home"},
}

local function localAssetPack(pack)
	local images = {}
	if pack == "core" then
		for _, filename in coreEntries do
			images[filename] = "mock PNG " .. filename
		end
	else
		local names = TEST_PACKS[pack]
		if not names then
			return nil
		end
		for _, name in names do
			images[name .. ".png"] = "mock PNG " .. name
		end
	end
	return {images = images}
end

local hui = Instance.new("Folder")
local genv = {}

-- Each bundle runs against its own environment, so `getgenv()`, `gethui()` and the services below never leak
local function makeEnv(targetGenv, targetHui)
	local env = setmetatable({
		game = {
			GetService = function(_, name)
				return services[name] or error("unknown service " .. name)
			end
		},
		Instance = Instance,
		task = task,
		tick = os.clock,
		warn = function() end,
		print = function() end,
		TweenInfo = {
			new = function()
				return {}
			end
		},
		getgenv = function()
			return targetGenv
		end,
		gethui = function()
			return targetHui
		end,
		base64decode = decodeBase64,
		getassetpack = localAssetPack,
		getcustomasset = function(path)
			assert(fs.isFile(SANDBOX .. "/" .. path), "missing local asset " .. path)
			return "localasset://" .. path
		end,
		isfile = function(path)
			return fs.isFile(SANDBOX .. "/" .. path)
		end,
		isfolder = function(path)
			return fs.isDir(SANDBOX .. "/" .. path)
		end,
		makefolder = function(path)
			fs.writeDir(SANDBOX .. "/" .. path)
		end,
		writefile = function(path, content)
			fs.writeFile(SANDBOX .. "/" .. path, content)
		end,
		readfile = function(path)
			return fs.readFile(SANDBOX .. "/" .. path)
		end,
		delfile = function(path)
			fs.removeFile(SANDBOX .. "/" .. path)
		end,
		listfiles = function(path)
			local files = {}
			for _, name in fs.readDir(SANDBOX .. "/" .. path) do
				table.insert(files, path .. "/" .. name)
			end
			return files
		end
	}, {__index = getfenv(1)})
	for key, value in roblox do
		if rawget(env, key) == nil and key ~= "Instance" then
			env[key] = value
		end
	end
	env.UDim, env.UDim2 = TRUNCATED_UDIM, TRUNCATED_UDIM2
	return env
end

local env = makeEnv(genv, hui)

-- An isolated environment for a bundle that is not the main one
local function fresh()
	local other = {genv = {}, hui = Instance.new("Folder")}
	other.env = makeEnv(other.genv, other.hui)
	return other
end

-- fakes a read only layout value, such as a scaled AbsoluteSize, and fires its change signal; nil restores the default
local function setLayout(instance, key, value)
	local d = data(instance)
	d.props[key] = value
	if d.propertySignals[key] then
		d.propertySignals[key]:Fire()
	end
end

local function renderText()
	local pending = pendingText
	pendingText = {}
	for instance in pending do
		local d = data(instance)
		d.rendered = d.props.Text
		if d.propertySignals.TextBounds then
			d.propertySignals.TextBounds:Fire()
		end
	end
end

local function step(frames: number?)
	for _ = 1, frames or 120 do
		renderText()
		renderStepped:Fire(1 / 60)
	end
end

local function setViewport(x, y)
	camera.ViewportSize = roblox.Vector2.new(x, y)
	viewportChanged:Fire()
end

-- lune leaves `KeyCode.Unknown` out of its reflection database, and the mock only reports the key name
local UNKNOWN_KEY = {Name = "Unknown"}

local function pointer(kind, x, y)
	return {
		UserInputType = roblox.Enum.UserInputType[kind],
		KeyCode = UNKNOWN_KEY,
		Position = roblox.Vector3.new(x or 0, y or 0, 0)
	}
end

local results = {passed = 0, failed = {}}
local function check(condition, message)
	if condition then
		results.passed += 1
		print("ok  " .. message)
	else
		table.insert(results.failed, message)
		print("FAIL  " .. message)
	end
end

-- the example's keybind poll loop never ends, so a hung area would keep lune running forever
task.delay(60, function()
	print("TIMEOUT: the tests did not finish within 60s")
	process.exit(1)
end)

return {
	BUNDLE = BUNDLE,
	check = check,
	env = env,
	fs = fs,
	fresh = fresh,
	genv = genv,
	hui = hui,
	input = input,
	luau = luau,
	pointer = pointer,
	process = process,
	results = results,
	resetSandbox = resetSandbox,
	roblox = ROBLOX,
	SANDBOX = SANDBOX,
	services = services,
	setLayout = setLayout,
	setViewport = setViewport,
	step = step,
	task = task
}
