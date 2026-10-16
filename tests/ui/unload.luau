return function(t)
	local Apogee = t.Apogee
	local check = t.check
	local genv = t.genv

	-- auto localize ---------------------------------------------------------------
	local guis, missing = 0, 0
	local function walk(instance)
		if instance:IsA("GuiBase2d") then
			guis += 1
			if instance.AutoLocalize ~= false then
				missing += 1
			end
		end
		for _, child in instance:GetChildren() do
			walk(child)
		end
	end
	walk(Apogee.GUI)
	check(guis > 100 and missing == 0, "AutoLocalize is disabled on all " .. guis .. " gui instances")

	Apogee:Destroy()
	check(Apogee.Unloaded, "Destroy unloads the interface")
	check(next(Apogee.Widgets) == nil and genv.Apogee == nil and Apogee.Current == nil, "Destroy clears the widgets, the current window and getgenv().Apogee")
	check(type(Apogee.internals) == "table", "Apogee.internals table exists")
	check(type(Apogee.internals.aria) == "table" and Apogee.internals.aria.Maid ~= nil, "Apogee.internals.aria exists")
	check(type(Apogee.internals.assets) == "table" and Apogee.internals.assets.themes ~= nil, "Apogee.internals.assets exists")
	check(type(Apogee.internals.components) == "table" and Apogee.internals.components.window ~= nil, "Apogee.internals.components exists")
	check(type(Apogee.internals.primitives) == "table" and Apogee.internals.primitives.button ~= nil, "Apogee.internals.primitives exists")
	check(type(Apogee.internals.services) == "table" and Apogee.internals.services.creator ~= nil, "Apogee.internals.services exists")
end
