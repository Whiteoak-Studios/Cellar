# Cellar

Instance pooling for Roblox. A game clones copies of a template once, parks them out of sight, takes one out when it needs it and gives it back when it is done, so it reuses copies instead of cloning and destroying them.

## Contents

- [What Cellar is](#what-cellar-is)
- [Install](#install)
- [A short example](#a-short-example)
- [How each function works](#how-each-function-works)
- [Limits](#limits)
- [API](#api)
- [Moving from ObjectCache 3.5.2](#moving-from-objectcache-352)
- [Testing Cellar](#testing-cellar)
- [License](#license)

## What Cellar is

Some things in a game come and go many times a second: tracers, shell casings, bullet holes, sound voices. Cloning a new instance for each one and destroying it afterward puts a clone and a destroy on every use. A pool clones them once, ahead of time, and hands the same copies out again and again, so taking a copy on a path that runs every frame costs no clone.

Cellar keeps those pools. Each pool is a category: a name, such as `FX/Casing/Rifle`, and a parent where its copies live. `add` fills a category with clones of a template. `get` takes copies out, and `rebound` gives one back, which puts it under the category's parent again and parks it at one point far below the map, (0, -100,000, 0). `remove` destroys idle copies, and `getAll` lists a category's copies, idle and out.

Cellar is one table per realm. Every category name is shared by all the code on the server, and each client has its own set, so a category the server declares does not exist on a client. Prefix each name with the system that owns it, as `FX/Impact` and `Loot/Crate` do.

Nothing in Cellar yields, so no call waits and none returns a Promise. It has no dependencies, opens no remote and holds no game values. Its source is strict-mode Luau written for luau-lsp's new type checker, and a game requires it with full types.

Cellar replaces ObjectCache. It is rewritten from ObjectCache 3.5.2's source as a new package, with that version's known bugs fixed. [Moving from ObjectCache 3.5.2](#moving-from-objectcache-352) says what a game changes, and `CHANGELOG.md` lists every change.

## Install

Cellar is the Wally package `fadeluc-123/cellar`, realm `shared`, so the server and every client can require it. Add it to your game's `wally.toml` under `[dependencies]`:

```toml
[dependencies]
Cellar = "fadeluc-123/cellar@^0.1.0"
```

The name on the left is the name Wally gives the package's entry in `Packages/`, so with `Cellar` the require below reads `Packages.Cellar`. Cellar has no dependencies of its own, so this one line is all it needs.

`^0.1.0` takes any 0.1.x release and never 0.2.0, since Wally follows Cargo's rules, where the first nonzero number marks a breaking change. So while Cellar is on 0.x, a change to a function's name, its argument order or its return shape, or to a behavior a known consumer relies on, comes only in a new minor version, such as 0.2.0, and a game moves to it by editing this line. New API and fixes come in a patch, such as 0.1.1, which `^0.1.0` picks up.

### Typed install

Cellar is fully typed, but Wally hides the types. It installs each package under `Packages/_Index/` and puts a one-line file at `Packages/Cellar` that points at it, and that file loses every exported type, so `require(Packages.Cellar)` comes back as `any`. Run these three commands after every install, from one Lune script in `.lune/` so none of them gets skipped:

```sh
wally install
rojo sourcemap sourcemap.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages/
```

`wally install` installs the packages. `rojo sourcemap` writes a map of your place to `sourcemap.json`. `sourcemap.project.json` is the project file a Whiteoak game builds its sourcemap from, so name whichever project file maps your place. `wally-package-types` reads that map and rewrites the one-line files with the types included. In a Whiteoak game, Rojo and `wally-package-types` come from its `rokit.toml`. Until the last two commands run, a `--!strict` script sees Cellar as `any`, and the checker checks none of your calls into it.

Cellar's types are written for luau-lsp's new type checker. luau-lsp's command line and its VS Code extension both run the old checker unless told otherwise, so pass `--flag:LuauSolverV2=true` to every `luau-lsp analyze`, in CI and by hand, and give the editor the same flags in `.vscode/settings.json`:

```json
{
	"luau-lsp.sourcemap.rojoProjectFile": "sourcemap.project.json",
	"luau-lsp.fflags.enableNewSolver": true,
	"luau-lsp.fflags.enableByDefault": true,
	"luau-lsp.fflags.sync": false
}
```

The first line names the project file the editor builds its sourcemap from. `enableNewSolver` turns the new checker on, `enableByDefault` turns on every boolean Luau flag the way `luau-lsp analyze` does, and `sync: false` stops the extension copying Roblox's live Luau flags, so a change Roblox makes to them never reaches your editor unannounced.

Then require Cellar bare, with no annotation:

```lua
local Cellar = require(ReplicatedStorage.Packages.Cellar)
```

An annotation on that line would replace the module's own type, and every function's type with it. Bare, every call into Cellar is checked, and the exported type `Cellar.Copies` is there for what `getAll` returns. The public functions carry Moonwave doc comments, so the editor shows each one's notes on hover.

## A short example

Impact markers: anchored single parts that a client shows at each hit point and parks again a few seconds later. The game keeps the numbers in its config module `ReplicatedStorage.Shared.Config.Impacts`:

```lua
--[[
    Tuning for the pooled impact markers: the Cellar category they live
    in, how many are cloned at boot and how long each one stays out
--]]

--!strict
return {
	category = "FX/Impact",
	count = 32, -- Copies cloned at boot, and the most hits that show a marker at once
	lifetime = 5, -- Seconds a marker stays out before it is parked again
}
```

The client module that pools the markers:

```lua
--[[
    Impact markers pooled through Cellar on the client: anchored single
    parts cloned into their own folder at boot, shown at a hit point and
    parked again once their lifetime is up. A hit shows nothing while
    every marker is already out
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Packages = ReplicatedStorage.Packages

local Cellar = require(Packages.Cellar)

local Assets = ReplicatedStorage:WaitForChild("Assets") :: Folder -- Boot-time wait: Assets may not have replicated yet

local IMPACT_CATEGORY: string = require(ReplicatedStorage.Shared.Config.Impacts).category
local IMPACT_COUNT: number = require(ReplicatedStorage.Shared.Config.Impacts).count
local IMPACT_LIFETIME: number = require(ReplicatedStorage.Shared.Config.Impacts).lifetime

local Impacts = {}

--[[
    Declares the impact category with its own folder and
    clones every marker it will show, once, at boot
--]]

function Impacts.fill()
	-- The template must be anchored, since parked copies sit below FallenPartsDestroyHeight
	local template = Assets:FindFirstChild("Impact") :: BasePart?
	if not template then
		return warn(`Impacts: no Impact template in {Assets:GetFullName()}`)
	end

	local folder: Folder = Instance.new("Folder")
	folder.Name = "Impacts"
	folder.Parent = Workspace

	Cellar:create(IMPACT_CATEGORY, folder)
	Cellar:add(template, IMPACT_COUNT, folder, IMPACT_CATEGORY)
end

--[[
    Shows one marker at a hit point and parks it again
    once its lifetime is up, or shows nothing when every
    marker is already out
--]]

function Impacts.show(position: Vector3)
	local copies: { Instance }? = Cellar:get(nil, IMPACT_CATEGORY)
	if not copies then
		return
	end

	local marker = copies[1] :: BasePart
	marker.CFrame = CFrame.new(position)

	task.delay(IMPACT_LIFETIME, function ()
		Cellar:rebound(marker)
	end)
end

return Impacts
```

Call `Impacts.fill()` once when the client boots, then `Impacts.show(position)` for each hit.

`fill` finds the template at `ReplicatedStorage.Assets.Impact`, makes a folder in the Workspace for the parked markers, declares the category with that folder as its parent and clones 32 markers into it. `show` takes one marker with `get`, moves it to the hit and gives it back with `rebound` once its lifetime has passed. While all 32 markers are out, `get` returns nil and that hit shows none. The template is anchored because a parked copy sits below the height where the engine destroys unanchored parts ([Limits](#limits)).

A copy comes back typed `Instance`, since a category can hold any kind of instance, so `show` casts the one it takes to `BasePart` at the call.

## How each function works

Every function is called with a colon on the table the require returns, as `Cellar:get(...)`. A `count`, in `add`, `get` and `remove`, is a whole number of 1 or more, and any other count errors at the call, naming the function and the value. The snippets below name their categories and counts with constants a game reads from its config, as the example does, and assume a `casing` template and a `casingFolder` folder.

### create

`Cellar:create(category: string, parent: Instance?): boolean`

Declares a category. `category` is its name, which may carry slashes, as `FX/Casing/Rifle` does. `parent` is where the category's copies live: `add` parents each new copy there, and `rebound` puts each returned copy back there.

A second `create` of a name already declared warns, returns `false` and leaves the first category as it was.

A category declared with no parent takes its parent from the first `add`, as [add](#add) explains.

```lua
Cellar:create(CASING_CATEGORY, casingFolder)
```

### add

`Cellar:add(template: Instance, count: number?, parent: Instance?, category: string): boolean`

Clones `template` `count` times, once when `count` is nil. Each clone is parked, parented and put on the category's idle list before `add` returns, so the copies are ready for the next `get`. `add` runs at runtime as well as at boot, so a pool can grow while the game plays.

The template need not be in the DataModel. `Clone` does not ask, so a tree built in memory works as well as a model in `ReplicatedStorage`.

A category has one parent. The third argument is optional, and `nil` means the category's parent. A category declared with no parent takes the parent the first `add` passes, or the Workspace when that `add` passes none, so the first `add` always settles it. After that, an `add` that names a different parent errors at the call, naming both. A pool that needs two folders is two categories.

```lua
Cellar:create(CASING_CATEGORY)
Cellar:add(casing, CASING_COUNT, casingFolder, CASING_CATEGORY) -- Settles the category's parent on casingFolder
Cellar:add(casing, CASING_COUNT, nil, CASING_CATEGORY) -- Adds more copies under casingFolder
Cellar:add(casing, CASING_COUNT, Workspace, CASING_CATEGORY) -- Errors, since the category's parent is casingFolder
```

`add` raises an error at the call, so it reaches the code that called it, when:

- `template` is nil;
- `category` was never declared with `create`;
- `template.Archivable` is false, since `Clone` returns nil for such an instance, and the message names the template;
- `parent` differs from the category's parent.

### get

`Cellar:get(count: number?, category: string, name: string?): { Instance }?`

Takes copies off the idle list and marks them out. It always returns an array: `Cellar:get(nil, category)` gives `{ copy }`, and a count gives up to that many copies, fewer when fewer are idle. With a `name`, it takes only copies with that name.

It returns nil, and takes nothing, when the category was never declared, when the category has no idle copy, or when a named `get` finds no copy with that name. It never waits for a category to appear.

```lua
local casings: { Instance }? = Cellar:get(CASING_BURST, CASING_CATEGORY)
local pines: { Instance }? = Cellar:get(nil, TREE_CATEGORY, "Pine")
```

`get` takes from the end of the idle list, so nothing shifts and its cost does not grow with the pool. `add` and `rebound` put copies on that end, so the idle list is last in, first out: the copy given back most recently is the next one `get` hands out. A named `get` scans the list once to find its copies, so its cost does grow with the pool.

A copy is typed `Instance`. A caller that knows it pooled parts casts at the call, as in `local marker = copies[1] :: BasePart`.

### rebound

`Cellar:rebound(copy: Instance): boolean`

Gives back a copy taken with `get`. It parents the copy to its category's parent, parks it ([Parking](#parking)) and puts it back on the idle list.

It resets only position and parent. Anything else the copy changed while it was out comes back with it ([Limits](#limits)).

`rebound` warns and returns `false` for a copy that is not out, because it was never taken or was already given back, and for a copy that was destroyed. A destroyed copy never rejoins the pool.

```lua
Cellar:rebound(marker)
```

### remove

`Cellar:remove(category: string, count: number?): boolean`

Destroys up to `count` idle copies, one when `count` is nil, taking from the end of the idle list. Copies that are out are left alone.

An unknown category raises an error at the call. A category with no idle copy makes `remove` warn and return `false`.

`remove` keeps ObjectCache's name, and it destroys every copy it takes.

```lua
Cellar:remove(CASING_CATEGORY, CASING_SURPLUS)
```

### getAll

`Cellar:getAll(category: string): Cellar.Copies?`

Gives a category's copies as two fresh arrays, `idle` and `out`, for a caller that walks every copy, such as a texture quality change that swaps every pooled copy's textures. Changing the arrays changes nothing in the pool. Each array keeps its list's order: the last entry of `idle` is the next copy `get` takes, and `out` lists copies in the order `get` took them. An unknown category returns nil.

```lua
export type Copies = {
	idle: { Instance },
	out: { Instance },
}
```

Each call allocates both arrays, so `getAll` belongs at boot or on a settings change, never on a path that runs every frame. Cellar has no call that lists category names, so a caller that walks several categories keeps its own list of them.

```lua
local copies: Cellar.Copies? = Cellar:getAll(TREE_CATEGORY)
if copies then
	for _, copy: Instance in copies.idle do
		applyQuality(copy)
	end

	for _, copy: Instance in copies.out do
		applyQuality(copy)
	end
end
```

Here `applyQuality` is the game's own function.

### Parking

A copy is parked when `add` makes it and each time `rebound` takes it back. Parking moves a Model with `PivotTo` and a BasePart through its `CFrame`, to `CFrame.new(0, -100000, 0)`, one finite point 100,000 studs below the origin. Anything else, such as a Sound or an AudioPlayer, stays where it is.

At 100,000 studs a 32-bit position rounds to 1/128 of a stud, so a pooled Model's parts come back at most about 0.004 studs from their places.

### A destroyed copy

Each copy's `Destroying` event is connected when `add` makes it, and the connection takes the copy off whichever list holds it, idle or out. The copy owns that connection, so it ends with the copy, and nothing leaks.

Under deferred signals, a copy's `Destroying` may not have run yet when `rebound` is called on it, and a destroyed instance's `Parent` is locked. `rebound` guards its `Parent` write, so it warns and returns `false` there too, rather than throwing. For the same reason `get` never hands out an idle copy whose `Parent` is nil, which is how a copy destroyed under deferred signals looks before its `Destroying` runs, and drops it from the idle list.

## Limits

- Pooled parts must be anchored. The park point sits below `Workspace.FallenPartsDestroyHeight`, where the engine takes an unanchored part out of the world by setting its `Parent` to nil, without destroying it. `getAll` still lists such a copy as idle until the next `get` drops it, and no `get` hands it out. Cellar does not anchor parts for you, so anchor every part in a template.
- `rebound` resets only position and parent. Anything else a copy changed while it was out, such as its attributes, tags, properties or joints, comes back with it, so the code that changes a copy puts it back the way it found it.
- A parked copy stays in the Workspace when its category's parent is in the Workspace, so a CollectionService tag on it still raises its Component while it sits in the pool.
- Anything that is not a Model or a BasePart stays where it is when parked, so the code that owns a pooled Sound or AudioPlayer stops it.
- `getAll` allocates two arrays on every call, so call it at boot or on a settings change. In three benchmark runs in the dev place, under both signal modes, it took 80 to 107 µs on a pool of 400 copies.
- A named `get` scans the idle list, so its cost grows with the pool. In three benchmark runs in the dev place, under both signal modes, a named `get` whose copy sat at the far end took 2 to 3 µs at 10 copies, 18 to 26 µs at 100 and 71 to 102 µs at 400. An unnamed `get` and `remove` take from the end, at the same cost for any size: an unnamed `get` and its `rebound` took about 1 µs at every size.
- Cellar trusts its caller. It has no remote and checks nothing a client could have sent, so a game never addresses a server pool by a string a client sent. A category name a game builds from client input is the game's to validate first.

## API

| Function | Returns | When it refuses |
|---|---|---|
| `Cellar:create(category: string, parent: Instance?)` | `boolean` | warns and returns `false` when the name is already declared |
| `Cellar:add(template: Instance, count: number?, parent: Instance?, category: string)` | `boolean` | errors at the call on a nil template, an unknown category, an unarchivable template or a parent other than the category's |
| `Cellar:get(count: number?, category: string, name: string?)` | `{ Instance }?` | returns nil for an unknown category, one with no idle copy, or a named `get` with no copy of that name |
| `Cellar:rebound(copy: Instance)` | `boolean` | warns and returns `false` for a copy that is not out or was destroyed |
| `Cellar:remove(category: string, count: number?)` | `boolean` | errors at the call on an unknown category; warns and returns `false` when no copy is idle |
| `Cellar:getAll(category: string)` | `Cellar.Copies?` | returns nil for an unknown category |

| Type | Shape |
|---|---|
| `Cellar.Copies` | `{ idle: { Instance }, out: { Instance } }` |

## Moving from ObjectCache 3.5.2

Cellar is a new package under a new name. `fadeluc-123/objectcache` stays installable at 3.5.2 and gets no further versions, so a game moves to Cellar by hand.

Replace the dependency line:

```toml
# ObjectCache 3.5.2
ObjectCache = "fadeluc-123/objectcache@3.5.2"

# Cellar
Cellar = "fadeluc-123/cellar@^0.1.0"
```

ObjectCache required the game's own Promise at `ReplicatedStorage.Packages.Promise`. Cellar needs none, so a `Promise` line kept only for ObjectCache can go.

Run the [typed install](#typed-install), and change the require from `local ObjectCache: any = require(Packages.ObjectCache)` to the bare `local Cellar = require(Packages.Cellar)`. ObjectCache had to be required `: any`, since its annotations declared `get`'s `name` as required. Cellar's types fit every documented call.

Then check each call against what changed:

- `get(count, category, name)` keeps the order 3.5.2's source used. ObjectCache's README gave `(category, count)`, which was wrong. `get` now always returns an array of copies, or nil: a count gives copies, where 3.5.2 gave numbers and lost copies; a named `get` with no match gives nil, where 3.5.2 gave the first copy without taking it; and an unknown category gives nil at once, where 3.5.2 waited 10 seconds, warned and errored.
- `remove` destroys the copies it takes. 3.5.2 dropped them from its list and left them parked in the world.
- `create`, `add`, `rebound` and `remove` return a boolean. A second `create` of a name returns `false`, where 3.5.2 returned nil.
- `add` raises its errors at the call. 3.5.2 cloned inside a Promise with no handler, so an error showed only as a warning about an unhandled rejection.
- `add`'s parent is optional, and a category keeps one parent. An `add` that names a different parent from the category's errors.
- `add`'s template need not be in the DataModel, which 3.5.2 asserted.
- Nothing returns a Promise, and nothing waits.
- The public `cache` and `inUse` fields are gone. `getAll` gives a category's idle and out copies.
- Copies park at (0, -100,000, 0). 3.5.2 parked them at an infinite point, which the engine clamps, so every parked copy stacked on one spot and a pooled Model lost its shape.

## Testing Cellar

Cellar is tested two ways, and a release waits for both: the Lune suite, and a live run in a Studio place. Lune has no physics and no real engine signals, so the park point, a Model's shape and `Destroying` are proven only live, while the suite catches every other break in seconds. Timings come from the benchmarks, which run in the same Studio place.

### The Lune suite

```sh
rokit install
lune run tests
```

`rokit install` installs the tools `rokit.toml` pins: Rojo 7.7.0, Wally 0.3.2, StyLua 2.5.2, selene 0.31.0, wally-package-types 1.6.2, Lune 0.10.5 and luau-lsp 1.70.0. `lune run tests` runs `tests/init.luau`, which runs every case under `tests/Cases/` in path order. `tests/Environment.luau` loads `src/` fresh for each case under a fake `game`, `script`, `task` and `require`. The cases sit in one folder per function, `Create/`, `Add/`, `Get/`, `Rebound/`, `Remove/` and `GetAll/`, with `Park/` for the park point, one camelCase file per case.

A run where every case passes prints one line, with the number of cases, and exits with code 0:

```
27 cases passed
```

The run stops at the first case that fails, so no case after it runs. It prints `Failed`, the case's path under `tests/Cases/` without `.luau`, and the reason, then exits with code 1. A case that returns false prints the reason it gave:

```
Failed Get/missingNameReturnsNil: a named get with no match took copies: 2 of 2 left
```

A case that throws prints `it threw:` and the error, which starts with the case file's full path on disk and the line that threw.

To run only some cases, pass text after `tests`. Only the cases whose path holds that text run, and the match is case sensitive:

```sh
lune run tests Get/
lune run tests badCount
```

`Get/` runs the ten `get` cases and leaves out `GetAll/`, and `badCount` runs the three bad-count cases for `add`, `get` and `remove`. Text that matches no path runs nothing and still prints `0 cases passed` with code 0, so check the count.

### CI

`.github/workflows/ci.yml` runs four gates on every pull request, every push to `main` and every release tag: Format, Lint, Analyze, and Tests, which is `lune run tests`. Each gate runs the same way by hand from the repo folder once `rokit install` has run.

Format runs StyLua over every `.luau` file in `src/`, `tests/`, `dev/` and `.lune/`, puts back the space StyLua takes out after `function` in an anonymous function, and fails when that leaves any change:

```sh
lune run format
git diff --exit-code
```

`lune run format` rewrites files in place and prints nothing. `git diff` shows only changes you have not staged, so stage your own work with `git add` first. A clean run then prints nothing and exits with code 0. A file that was out of format shows as a diff, and the exit code is 1; stage the formatted file.

Lint runs selene over `src/`:

```sh
selene src
```

A clean run prints:

```
Results:
0 errors
0 warnings
0 parse errors
```

Analyze checks `src/` under luau-lsp's new type checker. It needs two files that git ignores: a sourcemap built from `dev.project.json`, and Roblox's type definitions, downloaded from luau-lsp's repository. Make both, then analyze:

```sh
rojo sourcemap dev.project.json --output sourcemap.json
curl -sSfL https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau -o globalTypes.d.luau
luau-lsp analyze --platform=roblox --flag:LuauSolverV2=true --sourcemap=sourcemap.json --definitions=globalTypes.d.luau --ignore="Packages/**" --formatter=gnu src
```

`rojo sourcemap` prints `Created sourcemap at sourcemap.json`, and `curl` prints nothing. A clean analyze prints three log lines of luau-lsp's own and exits with code 0: `[INFO] Loading definitions file: @roblox - globalTypes.d.luau`, a `[WARN]` that the client does not allow `didChangeWatchedFiles` registration, which does not fail the gate, and `[INFO] Loading Luau configuration from` the repo's `.luaurc`. Each problem adds a line with the file, the line and column range and the error, such as `src/Broken.luau:2.23-2.27: TypeError: Expected this to be 'number', but got 'string'`, and the exit code is 1.

A release tag such as `v0.1.0` publishes the release once the gates pass, and only when the tag matches the version in `wally.toml`.

### The live run

The dev place is `127126854743642`. To serve Cellar into it:

1. Open the dev place in Roblox Studio.
2. In the repo folder, run `rojo serve dev.project.json`. It serves on port 34886, the `servePort` in `dev.project.json`. A running serve does not pick up a mount added to the project file, so restart any serve started before `dev.project.json` last changed.
3. Click Connect in the Rojo plugin.

`dev.project.json` mounts `src/` at `ReplicatedStorage.Packages.Cellar`, where a game's install puts it. It mounts `dev/server` as the Script `ServerScriptService.Dev` and `tests/Benchmarks` as the folder `ServerScriptService.Benchmarks`. The dev place's own scripts live in `dev/`, which is never published.

Start a play. `ServerScriptService.Dev` runs six checks on the server, one after another, each in a folder of its own that it destroys afterward. Each check prints one line, `[Cellar live]`, then `PASS`, `FAIL` or `FINDING`, then the check's name, a colon and what it measured. The checks run in this order:

- `shape`: a pooled Model of four parts keeps its shape within 0.004 studs after `add` parks it, after a move into the world, after `rebound` parks it again and after a second trip out. The line gives the largest drift.
- `fallenParts`: an unanchored copy parked below `Workspace.FallenPartsDestroyHeight` leaves the world within 5 seconds and a later `get` skips it, while an anchored copy stays at the park point for those 5 seconds. The line says whether the unanchored copy's `Destroying` fired.
- `wire`: clones a tree shaped like Echo's voice through Cellar, an `AudioPlayer` and the `Wire` that feeds it to an `AudioEmitter` under an `Attachment`, and reports what the clone's `Wire` points at, the clone's own player and emitter or the template's. It always reports `FINDING`.
- `destroyed`: a copy destroyed while out leaves the out record and `rebound` refuses it, and a `get` made straight after an idle copy is destroyed takes the copy behind it instead.
- `bulkMove`: `workspace:BulkMoveTo` moves a copy that is out, and `rebound` parks it again.
- `unarchivable`: `Clone()` on a part whose `Archivable` is false gives nil, which is why `add` refuses such a template.

A check that throws prints `FAIL` with `threw` and the error. After the last check comes one DONE line with the counts and the signal mode. A green run reads `[Cellar live] DONE passed 5, failed 0, findings 1, SignalBehavior` followed by the mode the script read, or by `unreadable:` and the reason when the engine refuses the read. `fallenParts` watches its parts for 5 seconds, so the DONE line prints a few seconds after the play starts.

Each run also prints one warning from Cellar that starts `Cellar:rebound`. It is expected, since `destroyed` calls `rebound` on a destroyed copy on purpose.

Run the checks twice, once with signals deferred and once with signals immediate. A script cannot set `Workspace.SignalBehavior`, so before each play select the Workspace and set `SignalBehavior` in Studio's Properties panel, `Deferred` for one run and `Immediate` for the other, then set it back afterward. Pick each mode by name, since `Default` ran signals immediately in the dev place. The `destroyed` line shows which mode a run used: `Destroying ran at once: false` under Deferred, and `true` under Immediate.

Beside the six checks, a release is checked once in the layout Wally installs. Build the package with `wally package --output cellar.zip`, unpack it into a scratch game's `Packages/_Index/fadeluc-123_cellar@<version>/cellar/`, and write Wally's thunk at `Packages/Cellar.lua`: `return require(script.Parent._Index["fadeluc-123_cellar@<version>"]["cellar"])`. Map `Packages` into `ReplicatedStorage` in the scratch game's `default.project.json`, build its sourcemap, and run `wally-package-types --sourcemap sourcemap.json Packages/`. Then analyze a `--!strict` file that requires `Packages.Cellar` bare, with the analyze command above, once with `--flag:LuauSolverV2=true` and once without. On the code that ships as 0.1.0, every correct call checked clean under both type checkers, a wrong argument and a missing field were refused, and `Cellar.Copies` resolved by name only once `wally-package-types` had rewritten the thunk.

### The benchmarks

The four modules in `tests/Benchmarks/` time Cellar's operations at pool sizes of 10, 100 and 400 copies. Each one returns a function, so nothing runs until it is called. For each size it fills a fresh category in a folder of its own, times its operation 101 times and destroys the folder.

- `getOne` times `get(nil, category)` and `rebound` as one pair on a pool of anchored parts. Its cost should stay the same at every size.
- `getNamed` times a named `get(nil, category, name)` whose one copy of that name sits at the far end of the idle list, so the `get` scans the whole pool. Its cost grows with the pool, and the run shows by how much.
- `addAtRuntime` times `add` of one tree shaped like Echo's voice into a pool already that size, the cost a pool pays to grow mid-game. The new copy is removed again outside the timing.
- `getAll` times one `getAll` on a pool with half its copies out.

Make a timing run with nothing else loading the machine, since any other work on it skews the timings. Throw away a run that overlapped other work and make it again.

1. Serve the dev place as the live run does and start a play.
2. Wait for the live checks' `[Cellar live] DONE` line, so they have finished.
3. Switch the play to its server view with Studio's Client/Server toggle, and run one module from the command bar:

   ```lua
   require(game:GetService("ServerScriptService").Benchmarks.getOne)()
   ```

4. Wait for its three lines, then run `getNamed`, `addAtRuntime` and `getAll` the same way, one at a time.

Each module prints one line per pool size, and the call returns the same three lines:

```
[Cellar bench] <operation> at <size>: <median> us, the median of 101
```

The median is in microseconds. Each run names its own categories, so a module can be run again in the same play to repeat a timing.

## License

Cellar is licensed under the Apache License 2.0, in `LICENSE`.
