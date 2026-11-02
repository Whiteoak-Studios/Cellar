--[[
    The constants Cellar's own correctness needs: the one finite point far
    below the map where every idle copy is parked
--]]

--!strict
-- Finite, since the engine clamps an infinite CFrame and stacks every copy on one spot. It sits below
-- FallenPartsDestroyHeight, where the engine destroys an unanchored part, so pooled parts are anchored
local PARK_CFRAME: CFrame = CFrame.new(0, -100000, 0)

return {
	PARK_CFRAME = PARK_CFRAME,
}
