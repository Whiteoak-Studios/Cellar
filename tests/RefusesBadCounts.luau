--[[
    Checks that a call refuses each count that is not a whole number of 1
    or more: zero, a negative count and a fraction each error at the call,
    with a message that names the value
--]]

--!strict
local ZERO: number = 0
local NEGATIVE: number = -1
local FRACTION: number = 2.5

local COUNTS: { number } = { ZERO, NEGATIVE, FRACTION }

return function (label: string, call: (count: number) -> ()): (boolean, string | nil)
	for _, count: number in COUNTS do
		local ok: boolean, message: any = pcall(call, count)
		if ok then
			return false, `{label} with a count of {count} returned instead of erroring`
		end

		-- The value must stand alone in the message, never inside a longer number such as a line number
		local value: string = (tostring(count):gsub("%p", "%%%0"))
		if not tostring(message):find(`%f[%d%.%-]{value}%f[%D]`) then
			return false, `{label} with a count of {count} errored without naming it: {message}`
		end
	end

	return true, nil
end
