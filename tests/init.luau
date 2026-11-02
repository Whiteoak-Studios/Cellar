--[[
    The entry `lune run tests` starts: runs every case under tests/Cases in
    path order and stops at the first failure, printing the case and its
    reason. An argument runs only the cases whose path holds it
--]]

--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")

local CASES: string = "tests/Cases"
local CASE_FILE: string = "%.luau$"

local paths: { string } = {}

--[[
    Collects every case file under a directory
--]]

local function collect(directory: string)
	for _, name: string in fs.readDir(directory) do
		local path: string = `{directory}/{name}`

		if fs.isDir(path) then
			collect(path)
		elseif name:match(CASE_FILE) then
			table.insert(paths, path)
		end
	end
end

--[[
    Runs one case to the case contract: it fails when its require errors,
    when it returns no function, when it throws, or when its first return
    is anything but true
--]]

local function run(module: string): (boolean, string | nil)
	-- In an init.luau, ./ is the folder's parent, the repo root the runner runs from
	local loaded: boolean, case: any = pcall(require :: any, `./{module}`)
	if not loaded then
		return false, `its require failed: {case}`
	end

	if type(case) ~= "function" then
		return false, `it returned a {type(case)}, not a function`
	end

	local ran: boolean, passed: any, reason: any = pcall(case)
	if not ran then
		return false, `it threw: {passed}`
	end

	if passed ~= true then
		return false, `{reason}`
	end

	return true, nil
end

collect(CASES)
table.sort(paths)

local only: string? = process.args[1]
local count: number = 0

for _, path: string in paths do
	if only and not path:find(only, 1, true) then
		continue
	end

	local module: string = (path:gsub(CASE_FILE, ""))
	local name: string = module:sub(#CASES + 2)
	local passed: boolean, reason: string? = run(module)

	if not passed then
		print(`Failed {name}: {reason}`)
		process.exit(1)
	end

	count += 1
end

print(`{count} cases passed`)
