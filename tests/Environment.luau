--[[
    Loads src/ fresh for each case under a fake game, script, task and require,
    with proxies that add what @lune/roblox lacks: Destroying, GetPivot,
    PivotTo, a Clone that honors Archivable and a Destroy that locks Parent
--]]

--!strict
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox: any = require("@lune/roblox")
local task = require("@lune/task")

local SOURCE: string = "src"
local ENTRY: string = `{SOURCE}/init.luau`
local PACKAGE_NAME: string = "Cellar"
local MODULE_FILE: string = "^(.+)%.luau$"

export type Loaded = {
	cellar: any, -- The package, as its source returns it
	game: any,
	workspace: any,
	new: (className: string, name: string, parent: any?) -> any, -- Builds an instance for a case to pool
	warnings: { string }, -- Every warn the source called, its arguments joined by spaces
	requires: { string }, -- The full name of every module the source required, in order
}

type State = {
	proxies: { [any]: any }, -- The one proxy of each real instance, so identity and table keys hold
	reals: { [any]: any }, -- The real instance behind each proxy
	listeners: { [any]: { [{ nil }]: () -> () } }, -- Destroying callbacks of each real instance
	destroyed: { [any]: boolean }, -- Real instances whose Parent a Destroy has locked
	modules: { [any]: any }, -- What each ModuleScript returned, since require runs a module once
	root: any, -- The package's ModuleScript, holding one child per src file beside init
	metatable: { [string]: any },
	globals: { [string]: any },
	fakes: { [string]: any },
	warnings: { string },
	requires: { string },
}

local Environment = {}

--[[
    Gives the one proxy of a real instance, and passes any other value
    through untouched
--]]

local function wrap(state: State, value: any): any
	if typeof(value) ~= "Instance" then
		return value
	end

	local proxy: any = state.proxies[value]
	if not proxy then
		proxy = setmetatable({}, state.metatable)
		state.proxies[value] = proxy
		state.reals[proxy] = value
	end

	return proxy
end

local function unwrap(state: State, value: any): any
	return state.reals[value] or value
end

--[[
    Wraps a real method so it takes proxies and gives proxies back, a list
    of instances included
--]]

local function forward(state: State, method: (...any) -> ...any): (...any) -> ...any
	return function (...: any): ...any
		local arguments: { n: number, [number]: any } = table.pack(...)
		for index: number = 1, arguments.n do
			arguments[index] = unwrap(state, arguments[index])
		end

		local results: { n: number, [number]: any } = table.pack(method(table.unpack(arguments, 1, arguments.n)))
		for index: number = 1, results.n do
			local result: any = results[index]
			if type(result) == "table" then
				for key: any, value: any in result do
					result[key] = wrap(state, value)
				end
			end

			results[index] = wrap(state, result)
		end

		return table.unpack(results, 1, results.n)
	end
end

--[[
    Destroys as the engine does in immediate signal mode: Destroying fires
    at once on the instance and on each descendant, then each is parented to
    nil and its Parent locked. Lune's own Destroy also refuses every later
    read of the instance, which the engine allows
--]]

local function destroy(state: State, real: any)
	if state.destroyed[real] then
		return
	end

	local doomed: { any } = real:GetDescendants()
	table.insert(doomed, 1, real)

	for _, instance: any in doomed do
		local callbacks: { [{ nil }]: () -> () }? = state.listeners[instance]
		state.listeners[instance] = nil

		for _, callback: () -> () in callbacks or {} do
			task.spawn(callback)
		end
	end

	for _, instance: any in doomed do
		instance.Parent = nil
		state.destroyed[instance] = true
	end
end

--[[
    The Destroying event of a real instance, with only Connect, whose
    connection has only Disconnect
--]]

local function destroying(state: State, real: any): { [string]: any }
	return {
		Connect = function (_, callback: () -> ()): { [string]: any }
			local token: { nil } = {}
			local callbacks: { [{ nil }]: () -> () } = state.listeners[real] or {}
			callbacks[token] = callback
			state.listeners[real] = callbacks

			return {
				Disconnect = function ()
					callbacks[token] = nil
				end,
			}
		end,
	}
end

--[[
    Moves a Model and every part in it to a new pivot, as the engine's
    PivotTo does. The pivot lives in WorldPivot, which Clone copies
--]]

local function pivotTo(real: any, target: any)
	local offset: any = target * real.WorldPivot:Inverse()

	for _, descendant: any in real:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CFrame = offset * descendant.CFrame
		end
	end

	real.WorldPivot = target
end

--[[
    Reads a member through a proxy, giving the engine's members in place of
    the ones Lune lacks or gets wrong
--]]

local function index(state: State, proxy: any, key: string): any
	local real: any = state.reals[proxy]

	if key == "Clone" then
		return function (self: any): any
			-- The engine gives nil for an unarchivable instance, where Lune clones it anyway
			-- Whiteoak TODO: unarchivable descendants are still cloned; drop them once a case pools a tree holding one
			local original: any = state.reals[self]
			return original.Archivable and wrap(state, original:Clone()) or nil
		end
	elseif key == "Destroy" then
		return function (self: any)
			destroy(state, state.reals[self])
		end
	elseif key == "Destroying" then
		return destroying(state, real)
	elseif key == "GetPivot" and real:IsA("Model") then
		return function (self: any): any
			return state.reals[self].WorldPivot
		end
	elseif key == "PivotTo" and real:IsA("Model") then
		return function (self: any, target: any)
			pivotTo(state.reals[self], target)
		end
	end

	local value: any = real[key]
	if type(value) == "function" then
		return forward(state, value)
	end

	return wrap(state, value)
end

local function newindex(state: State, proxy: any, key: string, value: any)
	local real: any = state.reals[proxy]
	local writer: number = 3 -- The line that wrote, past this function and the metatable's

	if key == "Parent" and state.destroyed[real] then
		error(`The Parent property of {real.Name} is locked, current parent: NULL, new parent {value}`, writer)
	end

	real[key] = unwrap(state, value)
end

--[[
    Runs one src file as the module a ModuleScript stands for, with script
    set to that ModuleScript
--]]

local function run(state: State, path: string, module: any): any
	local globals: { [string]: any } = table.clone(state.globals)
	globals.script = wrap(state, module)

	local chunk: (...any) -> ...any = luau.load(fs.readFile(path), { debugName = path, environment = globals })

	return (chunk())
end

--[[
    The source's require: records the module's full name, then gives the
    case's fake for that name, or runs the src file of one of the package's
    children once
--]]

local function requireModule(state: State, module: any): any
	local real: any = state.reals[module]
	assert(real and real:IsA("ModuleScript"), `require was given {module}, not a ModuleScript`)

	local name: string = real:GetFullName()
	table.insert(state.requires, name)

	if state.fakes[name] ~= nil then
		return state.fakes[name]
	end

	if state.modules[real] == nil then
		assert(real.Parent == state.root, `{name} is not a module of the package`)
		state.modules[real] = run(state, `{SOURCE}/{real.Name}.luau`, real)
	end

	return state.modules[real]
end

--[[
    Loads src/ into a fresh DataModel, the package under
    ReplicatedStorage.Packages where a game installs it, and gives it with
    the instances, records and builder a case reads. A fake replaces the
    global, or the module by its full name, that its key names
--]]

function Environment.load(fakes: { [string]: any }?): Loaded
	local game: any = roblox.Instance.new("DataModel")
	local packages: any = roblox.Instance.new("Folder")
	packages.Name = "Packages"
	packages.Parent = game:GetService("ReplicatedStorage")

	local root: any = roblox.Instance.new("ModuleScript")
	root.Name = PACKAGE_NAME
	root.Parent = packages

	local state: State = {
		proxies = {},
		reals = {},
		listeners = {},
		destroyed = {},
		modules = {},
		root = root,
		metatable = {},
		globals = {},
		fakes = fakes or {},
		warnings = {},
		requires = {},
	}

	state.metatable = {
		__index = function (proxy: any, key: string): any
			return index(state, proxy, key)
		end,

		__newindex = function (proxy: any, key: string, value: any)
			newindex(state, proxy, key, value)
		end,

		__tostring = function (proxy: any): string
			return tostring(state.reals[proxy])
		end,
	}

	state.globals = {
		game = wrap(state, game),
		workspace = wrap(state, game:GetService("Workspace")),
		task = task,
		CFrame = roblox.CFrame,
		Vector3 = roblox.Vector3,

		require = function (module: any): any
			return requireModule(state, module)
		end,

		warn = function (...: any)
			local parts: { string } = {}
			for index: number = 1, select("#", ...) do
				table.insert(parts, tostring((select(index, ...))))
			end

			table.insert(state.warnings, table.concat(parts, " "))
		end,
	}

	for key: string, value: any in state.fakes do
		state.globals[key] = value
	end

	-- Each src file beside init is a child ModuleScript of the package, as Rojo maps it
	for _, file: string in fs.readDir(SOURCE) do
		local name: string? = file:match(MODULE_FILE)
		if name and name ~= "init" then
			local module: any = roblox.Instance.new("ModuleScript")
			module.Name = name
			module.Parent = root
		end
	end

	return {
		cellar = run(state, ENTRY, root),
		game = state.globals.game,
		workspace = state.globals.workspace,
		warnings = state.warnings,
		requires = state.requires,

		new = function (className: string, name: string, parent: any?): any
			local instance: any = roblox.Instance.new(className)
			instance.Name = name
			instance.Parent = unwrap(state, parent)

			if instance:IsA("Model") then
				instance.WorldPivot = roblox.CFrame.new() -- Lune's Model has no pivot to read until one is written
			end

			return wrap(state, instance)
		end,
	}
end

return Environment
