--[=[
	Creates icons using the active `Icon` style. Themes can replace or hide the image; hidden icons
	close their layout gap.

	@class Icon
	@location internals/components
]=]
local Creator = require("../services/creator")
local Theme = require("../services/theme")

local Icon = {}

--[=[
	The default `Icon` style: shows the given image. Every style of this part must set `Image`, so a theme change
	never leaves the image of the previous style behind. Styles never change `Visible`.

	@param label ImageLabel -- The icon to dress
	@param image string? -- The image asset, nil for none
]=]
function Icon.Style(label: ImageLabel, image: string?)
	label.Image = image or ""
end

--[=[
	Creates an icon dressed by the active `Icon` style.

	@param image string? -- The image asset, nil for none
	@param props { [string]: any }? -- Properties for the image label
	@return ImageLabel -- The image label displaying the icon, if an image was supplied.
]=]
function Icon.New(image: string?, props: { [string]: any }?): ImageLabel
	local label = Creator:New("ImageLabel", props)
	Theme:Style("Icon", label, image)
	return label
end

--[=[
	Calls `changed` with whether the icon shows, now and after every theme change.

	@param label ImageLabel -- The icon
	@param changed (shown: boolean) -> () -- Updates the layout around the icon
]=]
function Icon.Watch(label: ImageLabel, changed: (shown: boolean) -> ())
	local function update()
		local shown = label.Image ~= ""
		label.Visible = shown
		changed(shown)
	end
	label:GetPropertyChangedSignal("Image"):Connect(update)
	update()
end

Theme:RegisterComponent("Icon", Icon.Style)

return Icon
