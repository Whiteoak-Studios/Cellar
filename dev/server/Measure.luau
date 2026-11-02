--[[
    Runs one benchmark at each pool size, in a folder and category name of
    its own: the benchmark fills the pool, one operation is timed again and
    again, and the median for each size is printed and returned as a line
--]]

--!strict
local Workspace = game:GetService("Workspace")

local POOL_SIZES: { number } = { 10, 100, 400 } -- From a small pool to the largest Frontier Zero keeps
local REPEATS: number = 101 -- Timings taken at each size, odd so the median is one of them
local MICROSECONDS: number = 1e6 -- In one second
local PREFIX: string = "[Cellar bench]"

export type Pool = {
	category: string, -- Not created yet, so the benchmark creates it in the Cellar it required
	folder: Folder, -- The category's parent, destroyed with every copy in it once the size is timed
	size: number, -- How many copies the benchmark fills the pool with
}

--[[
    fill creates the pool's category and fills it, and time runs the
    operation once and returns the seconds it took, keeping any setup the
    next run needs outside its own clock
--]]

return function (operation: string, fill: (pool: Pool) -> (), time: (pool: Pool) -> number): string
	local lines: { string } = {}

	for _, size: number in POOL_SIZES do
		local folder: Folder = Instance.new("Folder")
		folder.Name = `{PREFIX} {operation} {size}`
		folder.Parent = Workspace

		-- The clock keeps every run's names apart, since execute_luau can keep a required Cellar between calls
		local pool: Pool = {
			category = `CellarBench/{operation}/{size}/{os.clock()}`,
			folder = folder,
			size = size,
		}

		fill(pool)

		local timings: { number } = {}
		for _ = 1, REPEATS do
			table.insert(timings, time(pool))
		end

		folder:Destroy()
		table.sort(timings)

		local median: string = string.format("%.2f", timings[(REPEATS + 1) // 2] * MICROSECONDS)
		local line: string = `{PREFIX} {operation} at {size}: {median} us, the median of {REPEATS}`
		print(line)
		table.insert(lines, line)

		-- Studio is frozen until the run yields, so it draws a frame between sizes, outside every timing
		task.wait()
	end

	return table.concat(lines, "\n")
end
