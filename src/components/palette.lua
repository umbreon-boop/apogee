--[=[
	Modal color picker with saturation, value, hue, alpha, hex, and RGB controls. Clicking outside
	dismisses it without saving.

	@class Palette
	@location internals/components
]=]
local Drag = require("../services/drag")
local Dialog = require("./dialog")
local Images = require("../assets/images")
local State = require("../public")
local Style = require("../assets/themes")
local Textbox = require("./textbox")
local Frame = require("./frame")
local Creator = require("../services/creator")
local Pointer = require("../services/pointer")

local Palette = {}
Palette.__index = Palette

local WIDTH = 430
local HEIGHT = 308
local FIELD_ROWS = {Hex = 0, Red = 38, Green = 76, Blue = 114, Alpha = 152}
-- the block of controls between the dialog title and the button tray, scaled as a whole when the card shrinks
local BLOCK_X = 20
local BLOCK_Y = 52
local BLOCK_W = WIDTH - BLOCK_X
local BLOCK_H = 184
local TRAY_HEIGHT = 56
local GAP = 16
-- the touch area of a track is this much wider and taller than the track
local GRIP_EXTRA_WIDTH = 12
local GRIP_EXTRA_HEIGHT = 16

local isPress = Pointer.IsPress

local function corner(radius: UDim?): UICorner
	return Frame.Corner(radius or UDim.new(0, 4))
end

-- a tiled checkerboard behind the transparency track, so a transparent color stays visible
local function checker(props: { [string]: any }, children: { Instance }?): Instance
	props.Image = Images.Checker
	props.ScaleType = Enum.ScaleType.Tile
	props.TileSize = UDim2.fromOffset(8, 8)
	return Creator:New("ImageLabel", props, children)
end

local function alphaHandle(): Frame
	return Creator:New("Frame", {
		Size = UDim2.fromOffset(22, 14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0
	}, {
		corner(UDim.new(1, 0)),
		Creator:New("UIStroke", {Thickness = 2, Themed = {Color = "Surface"}})
	})
end

-- A track fill: one frame with a vertical gradient. Unlike strips of frames, a gradient follows the rounded corners
-- of its frame, so both ends of a track are round.
local function gradient(parent: Instance, color: ColorSequence, transparency: NumberSequence?): Frame
	return Creator:New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = parent
	}, {
		corner(UDim.new(1, 0)),
		Creator:New("UIGradient", {Color = color, Transparency = transparency or NumberSequence.new(0), Rotation = 90})
	})
end

-- the hue spectrum is linear between its seven primaries, so seven keypoints draw it exactly
local function spectrum(): ColorSequence
	local keypoints = {}
	for index = 0, 6 do
		table.insert(keypoints, ColorSequenceKeypoint.new(index / 6, Color3.fromHSV(index / 6 % 1, 1, 1)))
	end
	return ColorSequence.new(keypoints)
end

-- An invisible button larger than a thin track, so the track is easy to grab with a finger. It is as wide as the
-- gap between the tracks allows and reaches past both ends.
local function grip(track: GuiObject): TextButton
	return Creator:New("TextButton", {
		Size = UDim2.new(1, GRIP_EXTRA_WIDTH, 1, GRIP_EXTRA_HEIGHT),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = track
	})
end

local function fraction(value: number, origin: number, length: number): number
	return (math.clamp(value, origin, origin + length) - origin) / length
end

--[=[
	Opens a modal picker dialog for a color picker widget.

	@param picker ColorPicker -- The owning color picker
	@param window Window -- The window the picker is placed in
	@param title string -- The dialog title
	@param alpha boolean -- Show the transparency controls
	@param scrollFrame ScrollingFrame? -- Scroll frame to pause while open
	@return [Palette](Palette.md) -- The newly created color palette dialog.
]=]
function Palette.New(picker: any, window: any, title: string, alpha: boolean, scrollFrame: ScrollingFrame?): any
	local self = setmetatable({
		Hue = picker.Hue,
		Sat = picker.Sat,
		Vib = picker.Vib,
		Transparency = picker.Transparency,
		Opened = false,
		_alpha = alpha,
		_picker = picker,
		_window = window,
		_scrollFrame = scrollFrame or (if window and window.ScrollFrame then window.ScrollFrame else nil),
		_fields = {}
	}, Palette)
	self._title = title
	return self
end

--[=[
	Builds a fresh dialog card with the picker controls. A new one is built per open since closing a dialog
	destroys its whole subtree.
]=]
function Palette:_build()
	local dialog = Dialog.New(self._window)
	dialog.Title.Text = self._title
	dialog:SetSize(UDim2.fromOffset(WIDTH, HEIGHT))
	self._dialog = dialog
	rawset(self, "Root", dialog.Root)
	self._canvas = dialog.Root
	self._barrier = dialog.TintFrame

	local root = dialog.Root
	local column = if self._alpha then 260 else 240

	local card = dialog.Root.Size
	local scale = math.min(1, (card.X.Offset - BLOCK_X) / BLOCK_W, (card.Y.Offset - BLOCK_Y - TRAY_HEIGHT - GAP) / BLOCK_H)
	local block = Creator:New("Frame", {
		Size = UDim2.fromOffset(BLOCK_W, BLOCK_H),
		Position = UDim2.fromOffset(BLOCK_X, BLOCK_Y),
		BackgroundTransparency = 1,
		Parent = root
	}, {Creator:New("UIScale", {Scale = scale})})

	-- Cursor & Saturation Map (exact original dimensions 180x160 at 20, 55)
	self._cursor = Creator:New("ImageLabel", {
		Size = UDim2.fromOffset(18, 18),
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = Images.Cursor
	})

	self._map = Creator:New("ImageLabel", {
		Size = UDim2.fromOffset(180, 160),
		Position = UDim2.fromOffset(0, 0),
		Image = Images.SaturationMap,
		BackgroundColor3 = self._picker.Value,
		BackgroundTransparency = 0,
		Active = true,
		Parent = block
	}, {corner(), self._cursor})

	-- Hue Slider (exact original 12x190 at 210, 55)
	self._hueDrag = alphaHandle()
	self._hueSlider = Creator:New("Frame", {
		Size = UDim2.fromOffset(12, 184),
		Position = UDim2.fromOffset(206 - BLOCK_X, 0),
		ZIndex = 4,
		Active = true,
		Parent = block
	}, {
		corner(UDim.new(1, 0)),
		Creator:New("Frame", {
			Size = UDim2.new(1, 0, 1, -10),
			Position = UDim2.fromOffset(0, 5),
			BackgroundTransparency = 1,
			ZIndex = 3
		}, {
			self._hueDrag
		})
	})
	gradient(self._hueSlider, spectrum())

	-- The thumb previews the selected color and opacity.
	if self._alpha then
		self._alphaDrag = alphaHandle()
		self._alphaSlider = Creator:New("Frame", {
			Size = UDim2.fromOffset(12, 184),
			Position = UDim2.fromOffset(230 - BLOCK_X, 0),
			ZIndex = 3,
			Active = true,
			Parent = block,
			BackgroundTransparency = 1
		}, {
			corner(UDim.new(1, 0)),
			checker({Size = UDim2.fromScale(1, 1)}, {corner(UDim.new(1, 0))}),
			Creator:New("Frame", {
				Size = UDim2.new(1, 0, 1, -10),
				Position = UDim2.fromOffset(0, 5),
				BackgroundTransparency = 1,
				ZIndex = 3
			}, {
				self._alphaDrag
			})
		})
		-- the picked color, fading from opaque at the top to transparent at the bottom
		self._alphaFill = gradient(self._alphaSlider, ColorSequence.new(Color3.new(1, 1, 1)), NumberSequence.new(0, 1))
	end

	-- Fields (exact original rows 55, 95, 135, 175, 215, size 90x32)
	-- Plain input widgets, no row card, so they match the inputs used everywhere else
	self._fields = {}
	for _, name in {"Hex", "Red", "Green", "Blue", "Alpha"} do
		if name == "Alpha" and not self._alpha then
			continue
		end

		local field = Textbox.New(block, true)
		field.Frame.Size = UDim2.fromOffset(90, 32)
		field.Frame.Position = UDim2.fromOffset(column - BLOCK_X, FIELD_ROWS[name])
		Creator:New("TextLabel", {
			FontFace = Font.new(Style.Font, Enum.FontWeight.Medium, Enum.FontStyle.Normal),
			Text = name,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.fromOffset(WIDTH - column - 100, 32),
			Position = UDim2.fromOffset(column + 100 - BLOCK_X, FIELD_ROWS[name]),
			BackgroundTransparency = 1,
			Parent = block,
			Themed = {TextColor3 = "Text"}
		})
		self._fields[name] = field.Input
	end

	-- Done and Cancel use the same standard quiet style, both keeping the plain text color
	local doneAction = dialog:Button("Done", function()
		self._picker:_setHSV(self.Hue, self.Sat, self.Vib, self.Transparency)
		self:_teardown()
	end, "Suggested")
	local cancelAction = dialog:Button("Cancel", function()
		self:_teardown()
	end, "Standard")
	self._actions = {doneAction, cancelAction}
	self._confirmBtn = doneAction.Frame
	self._cancelBtn = cancelAction.Frame

	self:_connect()

	-- Pressing the tint outside the card dismisses without saving
	dialog.TintFrame.InputBegan:Connect(function(input)
		if not isPress(input) or not self.Opened then
			return
		end
		local pos = root.AbsolutePosition
		local size = root.AbsoluteSize
		local x, y = input.Position.X, input.Position.Y
		if x < pos.X or x > pos.X + size.X or y < pos.Y or y > pos.Y + size.Y then
			self:_teardown()
			task.spawn(pcall, dialog.Close, dialog)
		end
	end)
end

function Palette:_rgb(): { R: number, G: number, B: number }
	local color = Color3.fromHSV(self.Hue, self.Sat, self.Vib)
	return {
		R = math.clamp(math.floor(color.R * 255 + 0.5), 0, 255),
		G = math.clamp(math.floor(color.G * 255 + 0.5), 0, 255),
		B = math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
	}
end

--[=[
	Copies the picker's committed values into the working state and repaints.
]=]
function Palette:_sync()
	local picker = self._picker
	self.Hue = picker.Hue
	self.Sat = picker.Sat
	self.Vib = picker.Vib
	self.Transparency = picker.Transparency
	self:Display()
end

--[=[
	Releases the dialog: marks everything closed, resumes scrolling and resets the working state.
]=]
function Palette:_teardown()
	if not self.Opened then
		return
	end
	rawset(self, "Opened", false)
	rawset(self._picker, "Opened", false)

	if self._scrollFrame then
		self._scrollFrame.ScrollingEnabled = true
	end
	-- no repaint here: the closing card keeps its colors while it fades out, and `Open` syncs again
end

--[=[
	Opens the color picker dialog.
]=]
function Palette:Open()
	if self.Opened then
		return
	end
	rawset(self, "Opened", true)
	rawset(self._picker, "Opened", true)

	self:_build()
	self:_sync()

	if self._scrollFrame then
		self._scrollFrame.ScrollingEnabled = false
	end

	self._dialog:Open()
end

--[=[
	Closes the color picker dialog without committing the working state.
]=]
function Palette:Close()
	if not self.Opened then
		return
	end
	self:_teardown()
	task.spawn(pcall, self._dialog.Close, self._dialog)
end

function Palette:_connect()
	local fields = self._fields

	local function commitHex()
		local text = string.gsub(fields.Hex.Text, "[#%s]", "")
		local success, color = pcall(Color3.fromHex, text)
		if success and typeof(color) == "Color3" then
			local h, s, v = color:ToHSV()
			self.Hue = h
			self.Sat = s
			self.Vib = v
		end
		self:Display()
	end

	fields.Hex.FocusLost:Connect(commitHex)
	fields.Hex:GetPropertyChangedSignal("Text"):Connect(function()
		-- only typed text: `Display` also writes the hex, and parsing it back would round the color and reset the hue
		if not fields.Hex:IsFocused() then
			return
		end
		local text = string.gsub(fields.Hex.Text, "[#%s]", "")
		if #text == 6 then
			local success, color = pcall(Color3.fromHex, text)
			if success and typeof(color) == "Color3" then
				local h, s, v = color:ToHSV()
				self.Hue = h
				self.Sat = s
				self.Vib = v
				self:Display()
			end
		end
	end)

	for _, channel in {"Red", "Green", "Blue"} do
		local field = fields[channel]
		field.FocusLost:Connect(function()
			local num = tonumber(field.Text)
			if num then
				local rgb = self:_rgb()
				rgb[string.sub(channel, 1, 1)] = math.clamp(math.floor(num), 0, 255)
				local success, color = pcall(Color3.fromRGB, rgb.R, rgb.G, rgb.B)
				if success and typeof(color) == "Color3" then
					local h, s, v = color:ToHSV()
					self.Hue = h
					self.Sat = s
					self.Vib = v
				end
			end
			self:Display()
		end)
	end

	if self._alpha then
		fields.Alpha.FocusLost:Connect(function()
			local clean = string.gsub(fields.Alpha.Text, "[%%%s]", "")
			local value = tonumber(clean)
			if value then
				self.Transparency = 1 - math.clamp(value, 0, 100) * 0.01
			end
			self:Display()
		end)

		Drag.Bind(grip(self._alphaSlider), function(position)
				local slider = self._alphaSlider
				self.Transparency = fraction(position.Y, slider.AbsolutePosition.Y, slider.AbsoluteSize.Y)
				self:Display()
			end, self._scrollFrame)
	end

	Drag.Bind(self._map, function(position)
		local map = self._map
		self.Sat = fraction(position.X, map.AbsolutePosition.X, map.AbsoluteSize.X)
		self.Vib = 1 - fraction(position.Y, map.AbsolutePosition.Y, map.AbsoluteSize.Y)
		self:Display()
	end, self._scrollFrame)

	Drag.Bind(grip(self._hueSlider), function(position)
			local slider = self._hueSlider
			self.Hue = fraction(position.Y, slider.AbsolutePosition.Y, slider.AbsoluteSize.Y)
			self:Display()
		end, self._scrollFrame)
end

function Palette:Display()
	-- nothing to repaint before the dialog is built on open
	if not rawget(self, "_map") then
		return
	end

	local color = Color3.fromHSV(self.Hue, self.Sat, self.Vib)
	local rgb = self:_rgb()

	self._map.BackgroundColor3 = Color3.fromHSV(self.Hue, 1, 1)
	self._hueDrag.BackgroundColor3 = Color3.fromHSV(self.Hue, 1, 1)
	self._hueDrag.BackgroundTransparency = 0
	self._hueDrag.Position = UDim2.new(0, -5, self.Hue, -7)
	self._cursor.Position = UDim2.fromScale(self.Sat, 1 - self.Vib)

	if not self._fields.Hex:IsFocused() then
		self._fields.Hex.Text = "#" .. color:ToHex()
	end
	if not self._fields.Red:IsFocused() then
		self._fields.Red.Text = tostring(rgb.R)
	end
	if not self._fields.Green:IsFocused() then
		self._fields.Green.Text = tostring(rgb.G)
	end
	if not self._fields.Blue:IsFocused() then
		self._fields.Blue.Text = tostring(rgb.B)
	end

	if self._alpha then
		self._alphaFill.BackgroundColor3 = color
		self._alphaDrag.BackgroundColor3 = color
		self._alphaDrag.BackgroundTransparency = self.Transparency
		self._alphaDrag.Position = UDim2.new(0, -5, self.Transparency, -7)
		if not self._fields.Alpha:IsFocused() then
			self._fields.Alpha.Text = tostring(State:Round((1 - self.Transparency) * 100, 0)) .. "%"
		end
	end
end

function Palette:Destroy()
	if self.Opened then
		self:_teardown()
	end
	local dialog = rawget(self, "_dialog")
	if dialog then
		task.spawn(pcall, dialog.Close, dialog)
	end
end

return Palette
