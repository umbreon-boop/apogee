--[=[
	Keeps the themed properties, the text font and the restyled parts of instances in sync with the active theme.
	@class Theme
	@location internals/services
]=]
local Themes = require("../assets/themes")
local palettes = {}
for _, name in Themes.Names do
	palettes[name] = Themes[name]
end

local Theme = {
	Current = Themes.Default,
	Names = Themes.Names,
	Themes = palettes,
	_registry = {},
	_motors = {}
}
--@inline
local function readable(theme: any, key: string): Color3
	local fill = theme:Get(key)
	-- relative luminance, so mid tones like the indigo accent pick the right side
	--@inline
	local function channel(value: number): number
		if value <= 0.04045 then
			return value / 12.92
		end
		return ((value + 0.055) / 1.055) ^ 2.4
	end
	local luminance = 0.2126 * channel(fill.R) + 0.7152 * channel(fill.G) + 0.0722 * channel(fill.B)
	if luminance > 0.18 then
		return Color3.fromRGB(20, 20, 20)
	end
	return Color3.new(1, 1, 1)
end

-- keys computed from other keys so they follow any custom theme
local DERIVED = {
	AccentText = function(theme)
		return readable(theme, "Accent")
	end,
	DestructiveText = function(theme)
		return readable(theme, "Destructive")
	end,
	SurfaceBorder = function(theme)
		local text, surface = theme:Get("Text"), theme:Get("Surface")
		return Color3.new(
			text.R * 0.2 + surface.R * 0.8,
			text.G * 0.2 + surface.G * 0.8,
			text.B * 0.2 + surface.B * 0.8
		)
	end
}
--@inline
local function isText(instance: Instance): boolean
	return instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")
end

-- a theme picks the font family only, so bold and italic text keeps its weight and style across theme changes
--@inline
local function applyFont(instance: any, family: string)
	local face = instance.FontFace
	instance.FontFace = face and Font.new(family, face.Weight, face.Style) or Font.new(family)
end

function Theme:_fontFamily(): string
	local palette = self.Themes[self.Current]
	local font = (palette and palette.Font) or Themes.Font
	if typeof(font) == "EnumItem" then
		return Font.fromEnum(font).Family
	elseif typeof(font) == "Font" then
		return font.Family
	end
	return font
end

--[=[
	Maps instance property names to theme keys.
	@type Bindings
]=]
export type Bindings = { [string]: string }

--[=[
	Returns the active theme value, falling back to the default palette. Derived text and border roles
	are calculated from their related colors.

	@param key string -- The theme key
	@return any -- The active theme value for the key, falling back to the default theme when needed.
]=]
function Theme:Get(key: string): any
	local currentPalette = self.Themes[self.Current]
	local value
	if currentPalette then
		value = currentPalette[key]
	end
	if value ~= nil then
		return value
	end
	if DERIVED[key] then
		return DERIVED[key](self)
	end
	local defaultPalette = Themes[Themes.Default]
	if defaultPalette then
		return defaultPalette[key]
	end
	return nil
end

--[=[
	Returns a role size from the `Size` table of the active theme, or from `Style.Size` when the theme does not set it.

	@param name string -- The role size name
	@return number -- The resolved size for the named role.
]=]
function Theme:Size(name: string): number
	local palette = self.Themes[self.Current]
	local sizes = palette and palette.Size
	return sizes and sizes[name] or Themes.Size[name]
end

--[=[
	Keeps the height of an instance at a role size, also after a theme change. The width stays as it is.

	@param instance GuiObject -- The instance to size
	@param name string -- The role size name
]=]
function Theme:Height(instance: GuiObject, name: string)
	local function apply()
		local size = instance.Size
		instance.Size = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, self:Size(name))
	end
	apply()
	self:Track(apply, instance)
end

function Theme:_apply(instance: Instance, bindings: Bindings)
	for property, key in bindings do
		instance[property] = self:Get(key)
	end
end

Theme._components = {}
Theme._styled = {}

--[=[
	A style dresses a themeable instance and may return a look table. The owner uses its fields and calls
	`Destroy` when replacing the style. Bind colors through `Themed` so theme changes update the instance.

	@type Style (target: Instance, ...any) -> { Destroy: (() -> ())?, [string]: any }?
	@within Theme
]=]
export type Style = (target: Instance, ...any) -> any

--[=[
	Registers the default style of a themeable part. A theme replaces it with a style of the same name in its
	`Components` table.

	@param name string -- The component name
	@param style Style -- The default style
]=]
function Theme:RegisterComponent(name: string, style: Style)
	self._components[name] = style
end

--[=[
	Returns the default style of a themeable part, so a theme style can extend it.

	@param name string -- The part name
	@return Style -- The registered default style for the part.
]=]
function Theme:Default(name: string): Style
	return self._components[name]
end

--[=[
	Returns the style of a themeable part for the active theme.

	@param name string -- The part name
	@return Style -- The active theme style for the part, or its registered default.
]=]
function Theme:GetComponent(name: string): Style
	local palette = self.Themes[self.Current]
	local custom = palette and palette.Components and palette.Components[name]
	return custom or self._components[name]
end
--@inline
local function undress(entry: any)
	if entry.look and entry.look.Destroy then
		entry.look.Destroy()
	end
end

function Theme:_dress(target: Instance, entry: any)
	entry.style = self:GetComponent(entry.name)
	entry.look = entry.style(target, table.unpack(entry.args, 1, entry.args.n))
end

--[=[
	Applies the active style to a target and returns its look. Theme changes replace the look;
	`Track` callbacks run after restyling. Calling again replaces the style arguments.

	@param name string -- The part name
	@param target Instance -- The instance to dress, its destruction ends the styling
	@param ... any -- Extra arguments for the style
	@return { [string]: any }? -- The look
]=]
function Theme:Style(name: string, target: Instance, ...: any): any
	local entry = self._styled[target]
	if entry then
		undress(entry)
	else
		target.Destroying:Connect(function()
			local current = self._styled[target]
			self._styled[target] = nil
			if current then
				undress(current)
			end
		end)
	end
	entry = {name = name, args = table.pack(...)}
	self._styled[target] = entry
	self:_dress(target, entry)
	return entry.look
end

--[=[
	Returns the current look of a dressed target.

	@param target Instance -- The dressed instance
	@return { [string]: any }? -- The look returned by the active style, if the style creates one.
]=]
function Theme:Look(target: Instance): any
	local entry = self._styled[target]
	return entry and entry.look
end

--[=[
	Registers or replaces a theme palette.
	@param name string -- The theme name
	@param palette { [string]: any } -- The palette color definitions
]=]
function Theme:Add(name: string, palette: { [string]: any })
	assert(type(name) == "string", "Theme:Add expects a string name")
	assert(type(palette) == "table", "Theme:Add expects a palette table")
	palette.Name = name
	self.Themes[name] = palette
	if not table.find(self.Names, name) then
		table.insert(self.Names, name)
	end
	-- a replaced active theme repaints at once
	if name == self.Current then
		self:Set(name)
	end
end

--[=[
	Switches the active palette and repaints every bound instance.

	@param name string -- One of `Theme.Names`
	@return boolean -- False when no theme with that name exists
]=]
function Theme:Set(name: string): boolean
	if not self.Themes[name] or not table.find(self.Names, name) then
		return false
	end

	self.Current = name

	for instance, bindings in self._registry do
		self:_apply(instance, bindings)
	end

	local family = self:_fontFamily()
	for instance in self._registry do
		if isText(instance) then
			applyFont(instance, family)
		end
	end
	-- a snapshot, because dressing a target again creates instances that register new styles
	for target, entry in table.clone(self._styled) do
		if self._styled[target] == entry and self:GetComponent(entry.name) ~= entry.style then
			undress(entry)
			self:_dress(target, entry)
		end
	end
	for reset in table.clone(self._motors) do
		reset(name)
	end
	return true
end

--[=[
	Binds instance properties to theme keys and applies them immediately. Text instances also take the font family
	of the active theme and keep their own weight and style.

	@param instance Instance -- The instance to bind
	@param bindings Bindings -- The properties to keep in sync
	@return Instance -- The instance after theme bindings and text font tracking are applied.
]=]
function Theme:Bind(instance: Instance, bindings: Bindings): Instance
	local text = isText(instance)
	if not next(bindings) and not text then
		return instance
	end
	if not self._registry[instance] then
		instance.Destroying:Connect(function()
			self._registry[instance] = nil
		end)
	end
	self._registry[instance] = bindings
	self:_apply(instance, bindings)
	if text then
		applyFont(instance, self:_fontFamily())
	end
	return instance
end

--[=[
	Merges new bindings into the bindings of an already bound instance.

	@param instance Instance -- The bound instance
	@param bindings Bindings -- The new bindings
]=]
function Theme:Override(instance: Instance, bindings: Bindings)
	local existing = self._registry[instance]
	if existing then
		local merged = table.clone(existing)
		for k, v in bindings do
			merged[k] = v
		end
		bindings = merged
	end
	self:Bind(instance, bindings)
end

--[=[
	Registers a function to run after every theme change, after the restyled parts are dressed again.

	@param reset (name: string) -> () -- Called with the new theme name
	@param owner Instance? -- The instance whose destruction removes the function
]=]
function Theme:Track(reset: (name: string) -> (), owner: Instance?)
	self._motors[reset] = true
	if owner then
		owner.Destroying:Connect(function()
			self._motors[reset] = nil
		end)
	end
end

return Theme
