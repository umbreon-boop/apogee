--[=[
	Theme palettes and shared visual styling (typography, spacing, corner scales and shapes).

	@class Themes
	@location internals/assets
]=]
local Workspace = game:GetService("Workspace")
local camera = Workspace.CurrentCamera
local initialViewport = Vector2.new(1920, 1080)
if camera and camera.ViewportSize.X >= 640 and camera.ViewportSize.Y >= 480 then
	initialViewport = camera.ViewportSize
end

local baseDiagonal = math.sqrt(1920 * 1920 + 1080 * 1080)
local currentDiagonal = math.sqrt(initialViewport.X * initialViewport.X + initialViewport.Y * initialViewport.Y)
local scale = math.clamp(currentDiagonal / baseDiagonal, 0.85, 1.5)
local function scaled(size: number): number
	return math.round(size * scale)
end

local Space = {
	XXXS = 4,
	XXS = 8,
	XS = 12,
	S = 16,
	M = 24,
	L = 32,
	XL = 48,
	XXL = 64
}

local Type = {
	Title = scaled(24),
	Heading = scaled(14),
	Body = scaled(14),
	Small = scaled(12)
}

-- line heights scale with the text, so scaled text never overflows its line
local Line = {
	Title = scaled(36),
	Heading = scaled(21),
	Body = scaled(21),
	Small = scaled(17)
}

local Radius = {
	Window = UDim.new(0, 16),
	Container = UDim.new(0, 8),
	Popup = UDim.new(0, 16),
	Control = UDim.new(0, 8),
	Small = UDim.new(0, 4),
	Round = UDim.new(1, 0)
}

local Squircle = {
	Window = 22,
	Container = 12,
	Control = 12,
	Small = 6
}

--[=[
	Role sizes in pixels, unscaled like `Space`. A palette can replace any of them in its own `Size` table; read them
	with `Theme:Size`.

	@prop Row number -- Card and row height
	@prop Tab number -- Sidebar tab height
	@prop Control number -- Height of input, keybind and dropdown fields
	@prop Button number -- Height of dialog buttons
	@prop Option number -- Height of a dropdown list row
	@prop List number -- Largest height of a dropdown list
	@prop ListWidth number -- Smallest width of a dropdown list
	@prop Maximizer number -- Width and height of the maximizer button
	@prop MaximizerRadius number -- Corner size of the maximizer button
	@within Themes
]=]
local Size = {
	Row = 42,
	Tab = 30,
	Control = 30,
	Button = 32,
	Option = 32,
	List = 402,
	ListWidth = 170,
	Maximizer = 48,
	MaximizerRadius = 14
}

local Dark = {
	Name = "Dark",
	Background = Color3.fromRGB(30, 30, 30),
	Surface = Color3.fromRGB(41, 41, 41),
	Overlay = Color3.fromRGB(46, 46, 46),
	Control = Color3.fromRGB(48, 48, 48),
	Field = Color3.fromRGB(66, 66, 66),
	Divider = Color3.fromRGB(59, 59, 59),
	Border = Color3.fromRGB(59, 59, 59),
	ControlBorder = Color3.fromRGB(79, 79, 79),
	Text = Color3.fromRGB(201, 201, 201),
	SubText = Color3.fromRGB(174, 174, 174),
	Accent = Color3.fromRGB(148, 235, 235),
	Destructive = Color3.fromRGB(255, 181, 181),
	Hover = Color3.fromRGB(0, 0, 0),
	HoverChange = 0.1
}

local Light = {
	Name = "Light",
	Background = Color3.fromRGB(222, 222, 222),
	Surface = Color3.fromRGB(233, 233, 233),
	Overlay = Color3.fromRGB(244, 244, 244),
	Control = Color3.fromRGB(247, 247, 247),
	Field = Color3.fromRGB(255, 255, 255),
	Divider = Color3.fromRGB(185, 185, 185),
	Border = Color3.fromRGB(185, 185, 185),
	ControlBorder = Color3.fromRGB(211, 211, 211),
	Text = Color3.fromRGB(39, 39, 39),
	SubText = Color3.fromRGB(93, 93, 93),
	Accent = Color3.fromRGB(0, 73, 109),
	Destructive = Color3.fromRGB(160, 37, 43),
	Hover = Color3.fromRGB(0, 0, 0),
	HoverChange = 0.1
}

local Themes = {
	Default = Dark.Name,
	Names = {Dark.Name, Light.Name},
	Dark = Dark,
	Light = Light,
	Font = "rbxasset://fonts/families/BuilderSans.json",
	Viewport = initialViewport,
	Scale = scale,
	Scaled = scaled,
	Space = Space,
	Size = Size,
	Type = Type,
	Line = Line,
	Radius = Radius,
	Squircle = Squircle
}

Themes.Style = Themes
return Themes
