--[=[
	Squircle surfaces drawn from 9-slice images. Unlike `UICorner`, a squircle blends its straight edges into the corners
	with a continuous curve, the shape COSMIC and iced use for buttons, inputs and panels.

	@class Frame
	@location internals/components
]=]
local Images = require("../assets/images")
local Creator = require("../services/creator")
local Theme = require("../services/theme")

local Frame = {}
local SLICE = Rect.new(256, 256, 256, 256)
local SHAPES = {
	Full = Images.Squircle,
	Outline = Images.SquircleOutline,
	Top = Images.SquircleTop,
	Bottom = Images.SquircleBottom
}

--[=[
	@type Shape "Full" | "Outline" | "Top" | "Bottom"
	@within Frame
	`Top` and `Bottom` only round the corners on that side.
]=]
export type Shape = "Full" | "Outline" | "Top" | "Bottom"

--[=[
	The default `Frame` style: draws the shape as a libcosmic squircle. Every style of this part must set the same
	properties, so a theme change never leaves a property of the previous style behind. Styles never change `Visible`.

	@param instance ImageLabel | ImageButton -- The surface to dress
	@param radius number -- The corner size in pixels
	@param shape Shape -- The image shape
]=]
function Frame.Style(instance: any, radius: number, shape: Shape)
	instance.Image = SHAPES[shape]
	instance.ScaleType = Enum.ScaleType.Slice
	instance.SliceCenter = SLICE
	instance.SliceScale = radius / 256
	-- the image draws the shape, so a visible background would show square corners (ImageButton defaults to opaque)
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
end

--[=[
	The default `Corner` style: rounds the corners by the given radius.

	@param corner UICorner -- The corner to dress
	@param radius UDim -- The corner radius
]=]
function Frame.CornerStyle(corner: UICorner, radius: UDim)
	corner.CornerRadius = radius
end

--[=[
	Creates a surface that fills its parent and draws behind its other children. The default style is a squircle.
	Use `ImageColor3` and `ImageTransparency` to customize it, or bind colors with `Themed`.

	@param radius number -- The corner size in pixels
	@param props { [string]: any }? -- Properties for the image, `Shape` picks the image and `Button` makes it clickable
	@param children { Instance }? -- Instances parented to the new one
	@return ImageLabel | ImageButton -- The created image label, or image button when `Button` is true.
]=]
function Frame.New(radius: number, props: { [string]: any }?, children: { Instance }?): any
	local settings = {}
	if props then
		settings = table.clone(props)
	end
	local shape = settings.Shape or "Full"
	local class = "ImageLabel"
	if settings.Button then class = "ImageButton" end
	settings.Shape = nil
	settings.Button = nil

	if shape == "Outline" and settings.Visible == nil then
		settings.Visible = false
	end
	settings.Size = settings.Size or UDim2.fromScale(1, 1)
	if settings.ZIndex == nil and class == "ImageLabel" then
		settings.ZIndex = 0
	end

	local instance = Creator:New(class, settings, children)
	Theme:Style("Frame", instance, radius, shape)
	return instance
end

--[=[
	Creates a `UICorner` for shapes that a squircle image cannot draw at any size: pills, circles and solid fills that
	animate their background. The active `Corner` style sets its radius.

	@param radius UDim -- The corner radius
	@return UICorner -- The created UICorner with the requested radius.
]=]
function Frame.Corner(radius: UDim): UICorner
	local corner = Creator:New("UICorner")
	Theme:Style("Corner", corner, radius)
	return corner
end

Theme:RegisterComponent("Frame", Frame.Style)
Theme:RegisterComponent("Corner", Frame.CornerStyle)

return Frame
