--[[
    The live run in the dev place: each check only the engine can make on
    Cellar, run one after another when a play starts, every one printing a
    [Cellar live] line, then one DONE line with the counts and signal mode
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Packages = ReplicatedStorage.Packages

local Cellar = require(Packages.Cellar)

local Templates = require(script.Templates)

local PREFIX: string = "[Cellar live]"
local CATEGORY_ROOT: string = "CellarLive" -- Starts every category the checks make, so none clashes with another's
local SHAPE_TOLERANCE: number = 0.004 -- Studs a pooled Model's part may drift: half a float's step at the park depth
local POSITION_TOLERANCE: number = 0.001 -- Studs a copy may sit from where it was put and still count as there
local FALL_WINDOW: number = 5 -- Seconds the parked parts are watched, in which the unanchored one must leave the world
local SIGNAL_TIMEOUT: number = 2 -- Seconds a destroyed copy's Destroying gets to clear Cellar's record of it
local IDLE_COPIES: number = 2 -- The idle copy destroyed and the one behind it, which get must take instead
local OUT_CFRAME: CFrame = CFrame.new(0, 50, 0) * CFrame.Angles(0, math.rad(30), 0) -- Where a taken copy is put, turned

-- Each part's place in the pooled Model from the first, its pivot; the others sit off the 1/128-stud grid a float
-- keeps at the park point's depth, so its rounding shows
local PART_OFFSETS: { CFrame } = {
	CFrame.new(),
	CFrame.new(4.1, 1.37, 0.3) * CFrame.Angles(0, 0, math.rad(45)),
	CFrame.new(-3.3, 0.21, 2.7),
	CFrame.new(0.6, 3.3, -6.1) * CFrame.Angles(math.rad(20), 0, 0),
}

type Copies = Cellar.Copies
type Status = "PASS" | "FAIL" | "FINDING"
type Check = (folder: Folder) -> (Status, string)
type Entry = { name: string, run: Check }

--[[
    The place's Workspace.SignalBehavior, read through a cast since
    luau-lsp's definitions leave the property out, and through pcall in
    case the engine refuses a script the read
--]]

local function signalBehavior(): string
	local read: boolean, behavior: any = pcall(function ()
		return (Workspace :: any).SignalBehavior
	end)

	return read and behavior.Name or `unreadable: {behavior}`
end

-- Waits a frame at a time until condition holds or timeout seconds pass, and says whether it held
local function waitUntil(condition: () -> boolean, timeout: number): boolean
	local deadline: number = os.clock() + timeout

	while not condition() do
		if os.clock() >= deadline then
			return false
		end

		task.wait()
	end

	return true
end

-- Whether two CFrames sit within POSITION_TOLERANCE of each other
local function near(first: CFrame, second: CFrame): boolean
	return (first.Position - second.Position).Magnitude <= POSITION_TOLERANCE
end

-- The farthest any part of a pooled Model sits from its place in PART_OFFSETS, measured from the Model's pivot
local function drift(copy: Model): number
	local pivot: CFrame = copy:GetPivot()
	local largest: number = 0

	for index: number, offset: CFrame in PART_OFFSETS do
		local part = assert(copy:FindFirstChild(`Part{index}`), `the copy lost Part{index}`) :: BasePart
		local placed: Vector3 = pivot:ToObjectSpace(part.CFrame).Position
		largest = math.max(largest, (placed - offset.Position).Magnitude)
	end

	return largest
end

--[[
    A pooled Model keeps its shape: each part's offset from the pivot is
    measured after add parks it, after a move into the world, after rebound
    parks it again and after a second trip out, against the template's
--]]

local function shape(folder: Folder): (Status, string)
	local category: string = `{CATEGORY_ROOT}/shape`
	local template: Model = Instance.new("Model")

	for index: number, offset: CFrame in PART_OFFSETS do
		local part: Part = Templates.part(`Part{index}`)
		part.CFrame = offset
		part.Parent = template

		if index == 1 then
			template.PrimaryPart = part
		end
	end

	Cellar:create(category, folder)
	Cellar:add(template, nil, nil, category)
	template:Destroy()

	local copy = assert(Cellar:get(nil, category), `get gave no copy of the model`)[1] :: Model
	local largest: number = drift(copy)

	copy:PivotTo(OUT_CFRAME)
	largest = math.max(largest, drift(copy))

	if not Cellar:rebound(copy) then
		return "FAIL", `rebound refused the model`
	end

	largest = math.max(largest, drift(copy))

	copy = assert(Cellar:get(nil, category), `get gave no copy of the model after rebound`)[1] :: Model
	copy:PivotTo(OUT_CFRAME)
	largest = math.max(largest, drift(copy))

	local measured: string = `the largest drift was {string.format("%.5f", largest)} studs`
	local against: string = `across {#PART_OFFSETS} parts, against {SHAPE_TOLERANCE}`

	return largest <= SHAPE_TOLERANCE and "PASS" or "FAIL", `{measured} {against}`
end

--[[
    The engine takes an unanchored part parked below FallenPartsDestroyHeight
    out of the world, and a later get skips it, while an anchored one stays
    parked for the whole window
--]]

local function fallenParts(folder: Folder): (Status, string)
	local category: string = `{CATEGORY_ROOT}/fallenParts`
	local anchored: Part = Templates.part("Anchored")
	local loose: Part = Templates.part("Unanchored")
	loose.Anchored = false

	Cellar:create(category, folder)
	Cellar:add(anchored, nil, nil, category)
	Cellar:add(loose, nil, nil, category)
	anchored:Destroy()
	loose:Destroy()

	-- add puts each copy on the end of the idle list, so they sit in the order they were added
	local idle: { Instance } = assert(Cellar:getAll(category), `getAll found no {category}`).idle
	local heldCopy = idle[1] :: BasePart
	local looseCopy = idle[2] :: BasePart
	local parked: CFrame = heldCopy.CFrame
	local fired: boolean = false

	-- Disconnected once the window ends, and ended with the copy should the check throw first
	local connection: RBXScriptConnection = looseCopy.Destroying:Connect(function ()
		fired = true
	end)

	local started: number = os.clock()
	local gone: boolean = waitUntil(function (): boolean
		return looseCopy.Parent == nil
	end, FALL_WINDOW)
	local seconds: number = os.clock() - started

	task.wait(math.max(0, FALL_WINDOW - seconds))
	connection:Disconnect()

	local depth: string = `FallenPartsDestroyHeight {Workspace.FallenPartsDestroyHeight}`
	if not gone then
		local enabled: string = `FallHeightEnabled {Workspace.FallHeightEnabled}`
		return "FAIL", `the unanchored copy was still at {looseCopy.Position} after {FALL_WINDOW}s, {depth}, {enabled}`
	end

	if Cellar:get(nil, category, looseCopy.Name) then
		return "FAIL", `get handed out the unanchored copy the engine took out of the world`
	end

	if heldCopy.Parent ~= folder or not near(heldCopy.CFrame, parked) then
		return "FAIL", `the anchored copy left the park point {parked.Position} for {heldCopy.Position}`
	end

	local fell: string = `the unanchored copy left the world after {string.format("%.2f", seconds)}s`
	local how: string = `Destroying fired: {fired}, and get skipped it`
	local held: string = `the anchored copy stayed at y {parked.Y} for {FALL_WINDOW}s, below {depth}`

	return "PASS", `{fell} ({how}); {held}`
end

-- Names what one end of a Wire points at: the clone's own instance, the template's, or something else
local function describe(value: Instance?, own: Instance, template: Instance): string
	if value == own then
		return `{own:GetFullName()}, the clone's own {own.ClassName}`
	elseif value == template then
		return `{template:GetFullName()}, the template's {template.ClassName}`
	end

	return `{value and value:GetFullName() or "nil"}, neither the clone's nor the template's`
end

-- A voice tree's AudioPlayer, Wire and AudioEmitter, found by class
local function voiceParts(tree: Instance): (AudioPlayer, Wire, AudioEmitter)
	local attachment: Attachment = assert(tree:FindFirstChildOfClass("Attachment"), `{tree} holds no Attachment`)
	local player: AudioPlayer = assert(tree:FindFirstChildOfClass("AudioPlayer"), `{tree} holds no AudioPlayer`)
	local wire: Wire = assert(tree:FindFirstChildOfClass("Wire"), `{tree} holds no Wire`)
	local emitter: AudioEmitter =
		assert(attachment:FindFirstChildOfClass("AudioEmitter"), `{tree} holds no AudioEmitter`)

	return player, wire, emitter
end

--[[
    Clones a tree shaped like Echo's voice through Cellar and reports what
    the clone's Wire points at, the clone's own AudioPlayer and emitter or
    the template's. A finding either way, never a pass or a fail
--]]

local function wire(folder: Folder): (Status, string)
	local category: string = `{CATEGORY_ROOT}/wire`
	local template: Folder = Templates.voice()

	Cellar:create(category, folder)
	Cellar:add(template, nil, nil, category)

	local copy: Instance = assert(Cellar:get(nil, category), `get gave no copy of the voice`)[1]
	local templatePlayer: AudioPlayer, _, templateEmitter: AudioEmitter = voiceParts(template)
	local copyPlayer: AudioPlayer, copyWire: Wire, copyEmitter: AudioEmitter = voiceParts(copy)

	local source: string = `SourceInstance {describe(copyWire.SourceInstance, copyPlayer, templatePlayer)}`
	local target: string = `TargetInstance {describe(copyWire.TargetInstance, copyEmitter, templateEmitter)}`
	local names: string = `SourceName "{copyWire.SourceName}", TargetName "{copyWire.TargetName}"`
	template:Destroy()

	return "FINDING", `the clone's Wire holds {source}; {target}; {names}; Connected {copyWire.Connected}`
end

--[[
    Destroying is how Cellar learns a copy is gone: a copy destroyed while
    out leaves the out record and rebound refuses it, and a copy destroyed
    while idle is never handed out by a get made straight after, before a
    deferred Destroying has run
--]]

local function destroyed(folder: Folder): (Status, string)
	local outCategory: string = `{CATEGORY_ROOT}/destroyed/out`
	local idleCategory: string = `{CATEGORY_ROOT}/destroyed/idle`
	local template: Part = Templates.part("Copy")

	Cellar:create(outCategory, folder)
	Cellar:add(template, nil, nil, outCategory)
	Cellar:create(idleCategory, folder)
	Cellar:add(template, IDLE_COPIES, nil, idleCategory)
	template:Destroy()

	-- 1) A copy destroyed while out
	local out: Instance = assert(Cellar:get(nil, outCategory), `get gave no copy to destroy`)[1]
	local ran: boolean = false

	-- Disconnected straight after the Destroy, since only whether it ran at once matters
	local connection: RBXScriptConnection = out.Destroying:Connect(function ()
		ran = true
	end)
	out:Destroy()
	connection:Disconnect()

	local atOnce: boolean = ran
	if Cellar:rebound(out) then
		return "FAIL", `rebound gave back a copy destroyed while out`
	end

	local cleared: boolean = waitUntil(function (): boolean
		local copies: Copies? = Cellar:getAll(outCategory)
		return copies ~= nil and table.find(copies.out, out) == nil and #copies.idle == 0
	end, SIGNAL_TIMEOUT)

	if not cleared then
		return "FAIL", `getAll still lists the copy destroyed while out after {SIGNAL_TIMEOUT}s`
	end

	-- 2) A copy destroyed while idle, then a get at once, before a deferred Destroying can run
	local idle: { Instance } = assert(Cellar:getAll(idleCategory), `getAll found no {idleCategory}`).idle
	local doomed: Instance = idle[#idle] -- The copy get takes next
	doomed:Destroy()

	local handed: { Instance }? = Cellar:get(nil, idleCategory)
	if handed and table.find(handed, doomed) then
		return "FAIL", `get handed out the idle copy destroyed just before it`
	end

	if not handed then
		return "FAIL", `get gave nothing, though a live copy sat behind the destroyed one`
	end

	local mode: string = `under SignalBehavior {signalBehavior()}, Destroying ran at once: {atOnce}`
	local outDetail: string = `a copy destroyed while out left the out record and rebound refused it`
	local idleDetail: string = `a get straight after an idle copy's Destroy took the copy behind it`

	return "PASS", `{mode}; {outDetail}; {idleDetail}`
end

--[[
    A copy that is out moves with workspace:BulkMoveTo as any part does,
    and rebound parks it again
--]]

local function bulkMove(folder: Folder): (Status, string)
	local category: string = `{CATEGORY_ROOT}/bulkMove`
	local template: Part = Templates.part("Tracer")

	Cellar:create(category, folder)
	Cellar:add(template, nil, nil, category)
	template:Destroy()

	local copy = assert(Cellar:get(nil, category), `get gave no copy to move`)[1] :: BasePart
	local parked: CFrame = copy.CFrame

	Workspace:BulkMoveTo({ copy }, { OUT_CFRAME })
	if not near(copy.CFrame, OUT_CFRAME) then
		return "FAIL", `BulkMoveTo left the out copy at {copy.Position}, not {OUT_CFRAME.Position}`
	end

	if not Cellar:rebound(copy) then
		return "FAIL", `rebound refused the copy BulkMoveTo moved`
	end

	if not near(copy.CFrame, parked) then
		return "FAIL", `rebound left the copy at {copy.Position}, not parked at {parked.Position}`
	end

	local moved: string = `BulkMoveTo moved the out copy to {OUT_CFRAME.Position}`

	return "PASS", `{moved}, and rebound parked it again at y {parked.Y}`
end

--[[
    Clone gives nil for an instance whose Archivable is false, which is why
    add refuses such a template at the call
--]]

local function unarchivable(_: Folder): (Status, string)
	local template: Part = Templates.part("Unarchivable")
	template.Archivable = false

	local clone: Instance? = template:Clone()
	template:Destroy()

	if clone then
		clone:Destroy()
		return "FAIL", `Clone on a part whose Archivable is false gave a {clone.ClassName}`
	end

	return "PASS", `Clone on a part whose Archivable is false gave nil`
end

local checks: { Entry } = {
	{ name = "shape", run = shape },
	{ name = "fallenParts", run = fallenParts },
	{ name = "wire", run = wire },
	{ name = "destroyed", run = destroyed },
	{ name = "bulkMove", run = bulkMove },
	{ name = "unarchivable", run = unarchivable },
}

local counts: { [Status]: number } = {
	PASS = 0,
	FAIL = 0,
	FINDING = 0,
}

for _, check: Entry in checks do
	-- Each check works in a folder of its own, destroyed with every copy in it whether the check returned or threw
	local folder: Folder = Instance.new("Folder")
	folder.Name = `Cellar live {check.name}`
	folder.Parent = Workspace

	local ran: boolean, status: any, detail: any = pcall(check.run, folder)
	folder:Destroy()

	local result: Status = ran and status or "FAIL"
	local text: string = ran and detail or `threw {status}`
	counts[result] += 1
	print(`{PREFIX} {result} {check.name}: {text}`)
end

local tally: string = `passed {counts.PASS}, failed {counts.FAIL}, findings {counts.FINDING}`
print(`{PREFIX} DONE {tally}, SignalBehavior {signalBehavior()}`)
