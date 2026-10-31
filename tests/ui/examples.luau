--[[
	Runs every example in its own mocked environment. The examples are the public face of the library, so each
	one has to run and show its interface: they run last, and each is destroyed before the next, so the loops
	an example spawns never reach the other areas.
]]
local EXAMPLES = "examples"

return function(t)
	local check = t.check
	local fs = t.fs
	local fresh = t.fresh
	local luau = t.luau
	local resetSandbox = t.resetSandbox
	local step = t.step
	local task = t.task

	local paths = {}
	if fs.isDir(EXAMPLES) then
		for _, name in fs.readDir(EXAMPLES) do
			if string.match(name, "%.lua$") then
				table.insert(paths, EXAMPLES .. "/" .. name)
			end
		end
	end
	table.sort(paths)
	check(#paths > 0, "the examples are built into " .. EXAMPLES .. " (" .. #paths .. " found)")

	for _, path in paths do
		local name = string.match(path, "([^/]+)%.lua$")
		-- saved values and getgenv() state never carry over to the next example
		resetSandbox()
		local sandbox = fresh()

		local ok, result = pcall(function()
			local chunk = assert(luau.load(fs.readFile(path), {debugName = name, environment = sandbox.env}))
			chunk()
			task.wait(0.3)
			step()
			return sandbox.genv.Apogee
		end)

		local Apogee
		if ok then Apogee = result end
		local win = Apogee and Apogee.Current
		if not ok then
			check(false, name .. " runs without error (" .. tostring(result) .. ")")
		else
			check(Apogee.GUI.Parent == sandbox.hui, name .. " parents its gui to gethui()")
			local tabCount, elementCount = 0, 0
			if win then
				tabCount = #win.Tabs
				elementCount = #win._elements
			end
			check(win ~= nil and tabCount > 0, name .. " shows a window with " .. tabCount .. " tabs")
			check(win ~= nil and elementCount > 0, name .. " draws " .. elementCount .. " rows")
		end

		-- Destroy ends the loops the example spawned, such as the showcase poll loop
		pcall(function()
			if Apogee and not Apogee.Unloaded then
				Apogee:Destroy()
			end
			step()
		end)
	end

	resetSandbox()
end
