--[=[
	A clickable card that runs its callback when pressed.

	@class Button
	@location internals/primitives
]=]
local Class = require("../services/class")
local Element = require("../components/element")
local Icon = require("../components/icon")
local Widget = require("./widget")

local Button = Class.Extend({Type = "Button"}, Widget)

--[=[
	@interface ButtonConfig
	.Name string? -- Registry name used by `Apogee.Widgets`.
	.Title string -- Required row label.
	.Description string? -- Optional supporting label.
	.Persist boolean? -- Set false to omit the named entry from saved configurations.
	.Callback (() -> ())? -- Protected function called on activation; buttons have no value state.
	@within Button
]=]
export type Config = {
	Name: string?,
	Title: string,
	Description: string?,
	Persist: boolean?,
	Callback: (() -> ())?
}

--[=[
	Creates an action row. It does not participate in value persistence or the widget
	`OnChanged` contract.

	@param config Config -- Action label, optional description, registry name, and callback.
	@param parent Container -- The container to draw the button in
	@return [Button](Button.md) -- The button widget added to the parent container.
]=]
function Button.New(config: Config, parent: any): any
	assert(config.Title, "Button - Missing Title")

	local self = Class.New(Button)
	local element = Element.New(config.Title, config.Description, parent.Container, true, parent._window)
	element.LabelHolder.Size = UDim2.new(1, -40, 0, 0)

	local chevron = Icon.New("chevron-right", {
		Name = "Chevron",
		Size = UDim2.fromOffset(16, 16),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		BackgroundTransparency = 1,
		Parent = element.Frame,
		Themed = {ImageColor3 = "Text"}
	})
	-- a theme without icons gives the label the space of the chevron
	Icon.Watch(chevron, function(shown)
		local width = -24
		if shown then width = -40 end
		element.LabelHolder.Size = UDim2.new(1, width, 0, 0)
	end)

	self:_bind(element)
	self:From({Title = config.Title, Description = config.Description, Callback = config.Callback})

	element.Frame.MouseButton1Click:Connect(function()
		self:_fire()
	end)

	return self
end

return Button
