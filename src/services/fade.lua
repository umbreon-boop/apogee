--[=[
	Fades each visible descendant by changing its transparency, without reparenting or rendering it as a texture.
	Fade-in restores original transparencies. Properties changed during a fade keep their new values.

	@class Fade
	@location internals/services
]=]
local Creator = require("./creator")
local Motion = require("./motion")

local Fade = {}
local states = setmetatable({}, {__mode = "k"})

-- the transparency properties that each class draws with
local PROPERTIES = {
	ImageLabel = {"BackgroundTransparency", "ImageTransparency"},
	ImageButton = {"BackgroundTransparency", "ImageTransparency"},
	TextLabel = {"BackgroundTransparency", "TextTransparency", "TextStrokeTransparency"},
	TextButton = {"BackgroundTransparency", "TextTransparency", "TextStrokeTransparency"},
	TextBox = {"BackgroundTransparency", "TextTransparency", "TextStrokeTransparency"},
	ScrollingFrame = {"BackgroundTransparency", "ScrollBarImageTransparency"},
	Frame = {"BackgroundTransparency"},
	UIStroke = {"Transparency"}
}

-- records every visible part that is not fully transparent; hidden content and kept children are skipped
local function collect(host: Instance, keep: ((Instance) -> boolean)?): { any }
	local entries = {}
	local function walk(parent: Instance)
		for _, child in parent:GetChildren() do
			if (keep and parent == host and keep(child)) or (child:IsA("GuiObject") and child.Visible == false) then
				continue
			end
			for _, property in PROPERTIES[child.ClassName] or {} do
				local base = (child :: any)[property]
				if base ~= nil and base < 1 then
					table.insert(entries, {instance = child, property = property, base = base, last = base})
				end
			end
			walk(child)
		end
	end
	walk(host)
	return entries
end

-- A part whose value something else changed since the last write leaves the fade and keeps that value. Roblox
-- stores these values as 32 bit floats, so a value read back differs a little from the written one.
local function changed(entry: any): boolean
	if not entry.free and math.abs(entry.instance[entry.property] - entry.last) > 1e-4 then
		entry.free = true
	end
	return entry.free
end

local function apply(state: any, alpha: number)
	for _, entry in state.entries do
		if not changed(entry) then
			local value = 1 - (1 - entry.base) * alpha
			entry.last = value
			entry.instance[entry.property] = value
		end
	end
end

local function restore(state: any)
	for _, entry in state.entries do
		if not changed(entry) then
			entry.instance[entry.property] = entry.base
		end
	end
	state.entries = {}
end

-- starts a fade state with fresh bases; a running fade continues from its current alpha
local function prepare(host: GuiObject, alpha: number, keep: ((Instance) -> boolean)?): any
	local state = states[host]
	if state then
		alpha = state.alpha.Value
		restore(state)
	else
		state = {alpha = Creator:New("NumberValue", {Value = alpha}), entries = {}}
		state.alpha:GetPropertyChangedSignal("Value"):Connect(function()
			apply(state, state.alpha.Value)
		end)
		states[host] = state
	end
	state.entries = collect(host, keep)
	state.alpha.Value = alpha
	apply(state, alpha)
	return state
end

--[=[
	Hides the visible content of `host` at once, ready for a fade in.

	@param host GuiObject -- The frame whose content hides
	@param keep ((child: Instance) -> boolean)? -- Returns true for the children of `host` that do not fade
]=]
function Fade.Hide(host: GuiObject, keep: ((Instance) -> boolean)?)
	prepare(host, 0, keep)
end

--[=[
	Fades `host` in or out. A new fade continues from the current alpha. Fade-in restores original
	transparencies; after fade-out, the caller should hide the host in `completed`.

	@param host GuiObject -- The frame whose content fades
	@param visible boolean -- True to fade in, false to fade out
	@param duration number | TweenInfo -- The fade duration in seconds, or the full tween settings
	@param completed (() -> ())? -- Called when the fade ends without being interrupted
	@param keep ((child: Instance) -> boolean)? -- Returns true for the children of `host` that do not fade
]=]
function Fade.To(host: GuiObject, visible: boolean, duration: number | TweenInfo, completed: (() -> ())?, keep: ((Instance) -> boolean)?)
	local state = prepare(host, if visible then 0 else 1, keep)
	local token = {}
	state.token = token
	Motion.Tween(state.alpha, {Value = if visible then 1 else 0}, duration, nil, nil, function(playback)
		if playback ~= Enum.PlaybackState.Completed or state.token ~= token then
			return
		end
		if visible then
			Fade.Settle(host)
		end
		if completed then
			completed()
		end
	end)
end

--[=[
	Ends a fade at once and restores the exact transparency of every part.

	@param host GuiObject -- The frame whose content faded
]=]
function Fade.Settle(host: GuiObject)
	local state = states[host]
	if not state then
		return
	end
	states[host] = nil
	state.token = nil
	restore(state)
	state.alpha:Destroy()
end

return Fade
