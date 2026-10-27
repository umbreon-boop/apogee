return function(t)
	local Apogee = t.Apogee
	local check = t.check
	local input = t.input
	local pointer = t.pointer
	local task = t.task
	local win = t.win

	-- dialogs ---------------------------------------------------------------------
	local function buttons(dialog)
		local found = {}
		for _, child in dialog.ButtonHolder:GetChildren() do
			if child.ClassName == "TextButton" then
				table.insert(found, child)
			end
		end
		return found
	end

	local kept = 0
	local dialog = win:Dialog({
		Title = "Keep",
		Content = "x",
		Buttons = {
			{
				Title = "Stay",
				Callback = function()
					kept += 1
					return false
				end
			},
			{Title = "Go"}
		}
	})
	local actions = buttons(dialog)
	check(actions[1].LayoutOrder < actions[2].LayoutOrder and actions[1].Size.X.Offset == actions[2].Size.X.Offset, "regular dialog button order and equal sizing are preserved")
	check(actions[1]:FindFirstChildOfClass("ImageLabel").Image == Apogee.internals.assets.images.Squircle, "dialog buttons are squircles")
	check(dialog._border ~= nil and dialog.TintFrame.ClassName == "ImageButton", "the dialog overlay is a squircle")
	check(dialog.Root.Size.X.Offset <= win.Root.Size.X.Offset and dialog.Root.Size.Y.Offset <= win.Root.Size.Y.Offset, "a dialog fits inside its window")
	check(dialog.ButtonHolder.Size.Y.Offset <= dialog.ButtonHolderFrame.Size.Y.Offset, "dialog buttons fit inside the button tray")
	check(dialog.ButtonHolder.Size.Y.Scale == 1, "the button holder fills its tray so the buttons are never squeezed")
	check(dialog.ButtonHolderFrame.Size.Y.Offset - dialog.ButtonHolder.Size.Y.Offset >= 24, "dialog buttons keep clearance inside the tray")
	actions[1].MouseButton1Click:Fire()
	task.wait(0.3)
	check(kept == 1 and dialog.TintFrame.Parent ~= nil, "a callback returning false keeps the dialog open")

	local start = win.Position.X.Offset
	local press = pointer("MouseButton1", 50, 10)
	dialog.TintFrame.InputBegan:Fire(press)
	input.InputChanged:Fire(pointer("MouseMovement", 150, 60))
	input.InputEnded:Fire(press)
	check(win.Position.X.Offset == start, "the window does not move while a dialog covers it")
	local body = pointer("MouseButton1", 50, 200)
	dialog.TintFrame.InputBegan:Fire(body)
	input.InputChanged:Fire(pointer("MouseMovement", 400, 400))
	input.InputEnded:Fire(body)
	check(win.Position.X.Offset == start, "presses below the title strip do not move the window")

	actions[2].MouseButton1Click:Fire()
	task.wait(0.3)
	check(dialog.TintFrame.Parent == nil and dialog._window._dialogs[dialog] == nil, "other buttons close the dialog")
	check(next(dialog._window._dialogs) == nil, "the owning window clears its last open dialog")

	local fit = win:Dialog({
		Title = "Close",
		Content = "Are you sure you want to unload the interface?",
		Buttons = {{Title = "Yes"}, {Title = "No"}}
	})
	local fitTrayTop = fit.ButtonHolderFrame.Position.Y.Scale * fit.Root.Size.Y.Offset + fit.ButtonHolderFrame.Position.Y.Offset
	check(fit.Content.Position.Y.Offset + fit.Content.Size.Y.Offset + 12 <= fitTrayTop, "dialog text stays above the button tray")
	fit:Destroy()

	t.buttons = buttons
	t.win = win
end
