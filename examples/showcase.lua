local Apogee = require("../src/init")
local Widgets = Apogee.Widgets

-- demonstrate modularity: register an authentic Dear ImGui Dark theme. Its `Components` replace the styles of the
-- themeable parts, and the theme service restyles the existing interface on every theme change.
local squircle = Apogee.ThemeService:Default("Frame")

-- ImGui draws every surface square: the default squircle with a 1 px corner
local function ImGuiFrame(instance: any, _radius: number, shape: string)
	squircle(instance, 1, shape)
end

local function ImGuiCorner(corner: UICorner)
	corner.CornerRadius = UDim.new(0, 0)
end

-- ImGui draws no decorative icons: the tabs, the title and the toasts show text only
local function ImGuiIcon(label: ImageLabel)
	label.Image = ""
end

-- ImGui checkbox: a sharp 18x18 box with a check mark when active
local function ImGuiToggle(frame: Frame): any
	local checkmark = Apogee.Creator:New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = "✓",
		FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold),
		Themed = {TextColor3 = "Accent"},
		TextTransparency = 1,
		ZIndex = 2
	})
	local box = Apogee.Creator:New("Frame", {
		Size = UDim2.fromOffset(18, 18),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Parent = frame,
		BorderSizePixel = 1,
		Themed = {BackgroundColor3 = "Field", BorderColor3 = "ControlBorder"}
	}, {checkmark})

	return {
		Paint = function(enabled: boolean)
			checkmark.TextTransparency = if enabled then 0 else 1
		end,
		Destroy = function()
			box:Destroy()
		end
	}
end

-- ImGui slider: a sharp rectangular frame with an accent fill bar and the value text on top
local function ImGuiSlider(frame: Frame): any
	local fill = Apogee.Creator:New("Frame", {Size = UDim2.fromScale(0, 1), Themed = {BackgroundColor3 = "Accent"}})
	local display = Apogee.Creator:New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json"),
		TextSize = 13,
		ZIndex = 3
	})
	local hitbox = Apogee.Creator:New("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4})
	local rail = Apogee.Creator:New("Frame", {
		Size = UDim2.new(0.40, 0, 0, 20),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Parent = frame,
		BorderSizePixel = 1,
		Themed = {BackgroundColor3 = "Field", BorderColor3 = "ControlBorder"}
	}, {fill, display, hitbox})

	return {
		Rail = rail,
		Hitbox = hitbox,
		Paint = function(value: number, scale: number)
			fill.Size = UDim2.fromScale(scale, 1)
			display.Text = tostring(value)
		end,
		Destroy = function()
			rail:Destroy()
		end
	}
end

-- ImGui titlebar buttons: square buttons with classic text symbols (_, M, ×)
local function ImGuiTitleBarButton(button: TextButton, window: any, _icon: string, highlight: string?, text: string): any
	button.Size = UDim2.fromOffset(24, 24)
	local fill = Apogee.Creator:New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0,
		BorderSizePixel = 1,
		Parent = button,
		Text = text,
		TextSize = 13,
		FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold),
		Themed = {BackgroundColor3 = "Control", BorderColor3 = "ControlBorder"}
	})
	local function paint(key: string)
		Apogee.ThemeService:Override(fill, {BackgroundColor3 = key})
	end
	local entered = button.MouseEnter:Connect(function()
		paint(highlight or "Hover")
	end)
	local left = button.MouseLeave:Connect(function()
		paint("Control")
	end)

	return {
		Destroy = function()
			entered:Disconnect()
			left:Disconnect()
			fill:Destroy()
		end
	}
end

Apogee:AddTheme("ImGui", {
	Background = Color3.fromRGB(15, 15, 15), -- ImGui window background
	Surface = Color3.fromRGB(25, 25, 25), -- ImGui frame background
	Overlay = Color3.fromRGB(36, 54, 91), -- ImGui header / active title bar
	Control = Color3.fromRGB(41, 74, 122), -- ImGui button fill
	Field = Color3.fromRGB(18, 18, 18), -- ImGui input field inset
	Divider = Color3.fromRGB(80, 80, 80), -- Crisp separator
	Border = Color3.fromRGB(80, 80, 80), -- 1px contrasting window outline
	ControlBorder = Color3.fromRGB(80, 80, 80), -- Control outline
	Text = Color3.fromRGB(240, 240, 240), -- Crisp ImGui text
	SubText = Color3.fromRGB(160, 160, 160), -- Muted text
	Accent = Color3.fromRGB(66, 150, 250), -- ImGui active / hover blue
	Destructive = Color3.fromRGB(200, 50, 50), -- ImGui error / destructive
	Hover = Color3.fromRGB(66, 150, 250), -- ImGui highlight
	HoverChange = 0.15,
	Font = Enum.Font.RobotoMono, -- Monospaced typography
	-- Direct component overrides for Dear ImGui styling
	Components = {
		Frame = ImGuiFrame,
		Corner = ImGuiCorner,
		Icon = ImGuiIcon,
		Toggle = ImGuiToggle,
		Slider = ImGuiSlider,
		TitleBarButton = ImGuiTitleBarButton
	}
})

local window = Apogee:Window("Apogee " .. Apogee.Version, "by boop", {
	Icon = "orbit",
	Theme = "Dark",
	Minimizer = {Icon = "layout-grid"}
})

-- The ImGui icon style removes decorative images; keep a text restore mark on the floating mobile button instead.
local minimizerMark = Apogee.Creator:New("TextLabel", {
	Name = "ImGuiRestoreMark",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "□",
	TextSize = 22,
	FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold),
	Visible = false,
	ZIndex = 2,
	Themed = {TextColor3 = "Text"},
	Parent = window.Minimizer._body
})
Apogee.ThemeService:Track(function(name)
	minimizerMark.Visible = name == "ImGui"
end, window.Minimizer.Frame)

local main = window:Tab("Main", "")
Apogee:Notify("Notification", "This is a notification", {Duration = 5})
main:Paragraph("Paragraph", "This is a paragraph.\nSecond line!")

main:Button("Button", function()
	window:Dialog("Dialog Title", "This dialog dynamically sizes to accommodate 3 buttons.", {
		{
			Title = "Confirm",
			Style = "Suggested",
			Callback = function()
				print("Confirmed the dialog.")
			end
		},
		{
			Title = "Not yet",
			Style = "Standard",
			Callback = function()
				print("Returning false keeps the dialog open.")
				return false
			end
		},
		{
			Title = "Cancel",
			Style = "Destructive",
			Callback = function()
				print("Cancelled the dialog.")
			end
		}
	})
end, "Opens a dialog with 3 buttons")

main:Button("Open Popup", function()
	local popup = Apogee:Popup("Quick Popup", UDim2.fromOffset(320, 300))
	popup:Paragraph("Popup Element", "Directly hosts widgets without any sections.")
	popup:Toggle("Popup Toggle", true)
	popup:Slider("Popup Slider", 50, 0, 100, 0)
	popup:Button("Close Popup", function()
		popup:Close()
	end)
end, "A compact floating window without sections")

main:Button("Open another window", function()
	-- the new window copies the size and the transparency of the current one
	local extra = Apogee:Window("Second window", "", {Size = window.Size})
	extra:SetTransparency(window.Transparency)
	extra:Tab("Hello", "star"):Paragraph("Hi!", "Close me from the title bar.")
	extra:SelectTab(1)
end, "Several windows can be open at once")

local customSection = main:Section("Demonstration Section")
customSection:Toggle("Section Toggle", true)
customSection:Button("Section Button", function()
	print("Section button clicked.")
end)

-- Layouts divide a section into equal subcontainers; each subcontainer hosts the usual primitives and can nest again.
local layoutSection = main:Section("Layout")
local columns = layoutSection:Layout({Axis = "X", Gap = 8})
local leftColumn = columns:Subcontainer()
local rightColumn = columns:Subcontainer()
leftColumn:Toggle("Compact mode", true)
leftColumn:Slider("Scale", 50, 0, 100, 0)
rightColumn:Input("Search", "", nil, "Type to filter")
rightColumn:Button("Reset", function()
	print("Reset from a layout subcontainer.")
end)

-- Continuous widgets (sliders, color pickers, text input) change on every frame of a drag. They show their values in
-- this paragraph, because printing on every frame fills the Output window and slows Studio down.
local live = main:Paragraph("Live values", "")
local shown = {}
local function show(name: string, value: any)
	shown[name] = tostring(value)
	local lines = {}
	for _, key in {"Slider", "Color", "Alpha", "Input"} do
		if shown[key] then
			table.insert(lines, key .. ": " .. shown[key])
		end
	end
	live.Description = table.concat(lines, "\n")
end

-- widgets with a Name are registered in Apogee.Widgets and saved in configs
local toggle = main:Toggle("Toggle", false, {Name = "MyToggle"})
toggle:OnChanged(function()
	print("Toggle changed:", Widgets.MyToggle.Value)
end)

-- widgets can be built from previous instances to inherit their public properties
local inheritedToggle = customSection:Toggle(toggle)
inheritedToggle.Title = "Inherited Toggle"

-- direct reactive property assignment
Widgets.MyToggle.Value = false

local slider = main:Slider("Slider", 2, 0, 5, 1, function(value)
	show("Slider", value)
end, {Name = "Slider", Description = "This is a slider"})
slider:SetValue(3)

local inheritedSlider = customSection:Slider(slider)
inheritedSlider.Title = "Inherited Slider"

local values = {
	"one", "two", "three", "four", "five", "six", "seven",
	"eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen"
}

local dropdown = main:Dropdown("Dropdown", values, 1, {Name = "Dropdown"})
dropdown:SetValue("four")
dropdown:OnChanged(function(value)
	print("Dropdown changed:", value)
end)

local multiDropdown = main:Dropdown("Multi Dropdown", values, {"seven", "twelve"}, {
	Name = "MultiDropdown",
	Description = "You can select multiple values.",
	Multi = true
})
multiDropdown:SetValue({three = true, five = true, seven = false})
multiDropdown:OnChanged(function(value)
	local selected = {}
	for option in value do
		table.insert(selected, option)
	end
	print("Multi dropdown changed:", table.concat(selected, ", "))
end)

local colorPicker = main:ColorPicker("Color Picker", Color3.fromRGB(96, 205, 255), {Name = "ColorPicker"})
colorPicker:OnChanged(function(color)
	show("Color", color:ToHex())
end)
colorPicker:SetValue(Color3.fromRGB(0, 255, 140))

-- a Transparency adds an alpha slider to the picker
local alphaPicker = main:ColorPicker("Transparent Color", Color3.fromRGB(96, 205, 255), {
	Name = "AlphaPicker",
	Transparency = 0,
	Description = "You can also change the transparency."
})
alphaPicker:OnChanged(function(color, transparency)
	show("Alpha", color:ToHex() .. " at " .. math.round((1 - transparency) * 100) .. "%")
end)

local keybind = main:Keybind("KeyBind", "E", function(key)
	print("Keybind changed!", key)
end, "Toggle", function(toggled)
	print("Keybind pressed!", toggled)
end, {Name = "Keybind"})

keybind:OnChanged(function()
	print("Keybind changed:", keybind.Value)
end)

task.spawn(function()
	while not Apogee.Unloaded do
		task.wait(1)
		if keybind:GetState() then
			print("Keybind is being held down")
		end
	end
end)

keybind:SetValue("MouseRight", "Toggle")

local input = main:Input("Input", "Default", function(value)
	show("Input", value)
end, "Placeholder", {Name = "Input"})

-- configs are stored under one configurable path.
Apogee.Config:SetFolder("ApogeeScriptHub/specific-game")
window:Settings()

window:SelectTab(1)
Apogee:Notify("Apogee", "The script has been loaded.", {Duration = 8})

-- loads autoload.bin if it exists.
local autoloaded, autoloadError = Apogee.Config:Autoload()
if autoloaded then
	Apogee:Notify("Interface", "Config loaded", {SubContent = "Loaded autoload.bin", Duration = 7})
elseif autoloadError then
	Apogee:Notify("Interface", "Config loader", {SubContent = autoloadError, Duration = 7})
end
