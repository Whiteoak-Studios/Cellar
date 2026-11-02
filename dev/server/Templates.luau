--[[
    The templates the live checks and the benchmarks pool, built in memory
    as a game may build its own: an anchored part, and a tree shaped like
    one of Echo's voices
--]]

--!strict
local Templates = {}

--[[
    An anchored part, as a pooled part must be to stay at the park point
--]]

function Templates.part(name: string): Part
	local part: Part = Instance.new("Part")
	part.Name = name
	part.Anchored = true

	return part
end

--[[
    A tree shaped like one of Echo's voices: an AudioPlayer, the Wire that
    feeds it to an AudioEmitter, and that emitter under an Attachment, all
    in one Folder
--]]

function Templates.voice(): Folder
	local voice: Folder = Instance.new("Folder")
	voice.Name = "Voice"

	local player: AudioPlayer = Instance.new("AudioPlayer")
	player.Parent = voice

	local attachment: Attachment = Instance.new("Attachment")
	attachment.Parent = voice

	local emitter: AudioEmitter = Instance.new("AudioEmitter")
	emitter.Parent = attachment

	local wire: Wire = Instance.new("Wire")
	wire.SourceInstance = player
	wire.TargetInstance = emitter
	wire.Parent = voice

	return voice
end

return Templates
