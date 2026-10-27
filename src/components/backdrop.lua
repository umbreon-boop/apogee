--[=[
	The flat surface behind windows and notifications: an opaque body and a hairline border, matching libcosmic's
	background role. No drop shadow is drawn, so nothing square can appear outside the rounded corners.

	@class Backdrop
	@location internals/components
]=]
local Style = require("../assets/themes")
local Squircle = require("./frame")
local Creator = require("../services/creator")

local Backdrop = {}

--[=[
	Creates a new backdrop frame that fills its parent.
	The body is exposed as the `Background` child so its transparency can be toggled.

	@param customRadius number? -- The squircle radius, defaults to the window radius
	@param solidBody boolean? -- Draw an opaque rounded body behind the squircle, so the surface never shows the game
	@return [Frame](Frame.md) -- The backdrop root frame, including its background surfaces.
]=]
function Backdrop.New(customRadius: number?, solidBody: boolean?): Frame
	local radius = customRadius or Style.Squircle.Window
	local children = {}
	if solidBody then
		-- The squircle's 9-slice centre is a point, so it cannot be relied on to fill a fullscreen surface. The body
		-- keeps the window colour identical in normal and maximized mode.
		table.insert(children, Creator:New("Frame", {
			Name = "Body",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 0,
			Themed = {BackgroundColor3 = "Background"},
			ZIndex = 0
		}, {Squircle.Corner(UDim.new(0, radius))}))
	end
	table.insert(children, Squircle.New(radius, {
		Name = "Background",
		ImageTransparency = 0,
		Themed = {ImageColor3 = "Background"}
	}))
	table.insert(children, Squircle.New(radius, {Shape = "Outline", Visible = false, ZIndex = 2, Themed = {ImageColor3 = "Border"}}))
	return Creator:New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1}, children)
end

return Backdrop
