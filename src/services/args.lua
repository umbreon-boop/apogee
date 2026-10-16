--[=[
	Normalizes positional shorthand into the config table accepted by each method.

	@class Args
	@location internals/services
]=]
local Args = {}

--[=[
	Returns the config for a call. A table as the first argument is the config. Otherwise the arguments fill `fields`
	in order, and a trailing table holds more options, unless its position is a field that takes a table.

	@param fields { string } -- The field of each position
	@param tableFields { [string]: boolean }? -- The fields whose value is a table
	@param first any -- The first argument
	@param ... any -- The other arguments
	@return { [string]: any } -- The normalized configuration table assembled from the supplied arguments.
]=]
function Args.Config(fields: { string }, tableFields: { [string]: boolean }?, first: any, ...: any): { [string]: any }
	if type(first) == "table" then
		return first
	end
	local values = table.pack(first, ...)
	local last = values[values.n]
	local options = nil
	if values.n > 1 and type(last) == "table" and not (tableFields and tableFields[fields[values.n]]) then
		options = last
		values.n -= 1
	end

	local config = {}
	for index = 1, math.min(values.n, #fields) do
		if values[index] ~= nil then
			config[fields[index]] = values[index]
		end
	end
	for key, value in options or {} do
		config[key] = value
	end
	return config
end

return Args
