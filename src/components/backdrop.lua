--[=[
	The flat surface behind windows and notifications: a soft drop shadow, an opaque body and a hairline border,
	matching libcosmic's background role.

	@class Backdrop
	@location internals/components
]=]
local Images = require("../assets/images")
local Style = require("../assets/themes")
local Squircle = require("./frame")
local Creator = require("../services/creator")

local Backdrop = {}

--[=[
	Creates a new backdrop frame that fills its parent.
	The body is exposed as the `Background` child so its transparency can be toggled.

	@param customRadius number? -- The squircle radius, defaults to the window radius
	@param showShadow boolean? -- Whether to draw the window drop shadow, defaults to true
	@return [Frame](Frame.md) -- The backdrop root frame, including its shadow and background surfaces.
]=]
function Backdrop.New(customRadius: number?, showShadow: boolean?): Frame
	local radius = customRadius or Style.Squircle.Window
	return Creator:New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1}, {
		Creator:New("ImageLabel", {
			Name = "Shadow",
			Image = Images.Shadow,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(Vector2.new(99, 99), Vector2.new(99, 99)),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(1, 120, 1, 116),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			ImageColor3 = Color3.fromRGB(0, 0, 0),
			ImageTransparency = 0.7,
			Visible = showShadow ~= false,
			ZIndex = 0
		}),
		Squircle.New(radius, {
			Name = "Background",
			ImageTransparency = 0,
			Themed = {ImageColor3 = "Background"}
		}),
		Squircle.New(radius, {Shape = "Outline", Visible = false, ZIndex = 2, Themed = {ImageColor3 = "Border"}})
	})
end

return Backdrop
