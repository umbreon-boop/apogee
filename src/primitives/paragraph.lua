--[=[
	A static card of text: the title and the body text in `Description`.

	@class Paragraph
	@location internals/primitives
]=]
local Class = require("../services/class")
local Element = require("../components/element")
local Widget = require("./widget")

local Paragraph = Class.Extend({Type = "Paragraph"}, Widget)

--[=[
	@interface ParagraphConfig
	.Name string? -- Optional registry name.
	.Title string -- Required heading.
	.Description string? -- The body text
	.Persist boolean? -- Set false to omit the named entry from saved configurations.
	@within Paragraph
]=]
export type Config = { Name: string?, Title: string, Description: string?, Persist: boolean? }

--[=[
	Creates a new paragraph. Use `Container:Paragraph` instead of calling this directly.

	@param config Config -- Heading and optional body text.
	@param parent Container -- The container to draw the paragraph in
	@return [Paragraph](Paragraph.md) -- The paragraph widget added to the parent container.
]=]
function Paragraph.New(config: Config, parent: any): any
	assert(config.Title, "Paragraph - Missing Title")

	local self = Class.New(Paragraph)
	local element = Element.New(config.Title, config.Description or "", parent.Container, false, parent._window)
	element.LabelHolder.Size = UDim2.new(1, -24, 0, 0)

	self:_bind(element)
	self:From({Title = config.Title, Description = config.Description or ""})

	return self
end

return Paragraph
