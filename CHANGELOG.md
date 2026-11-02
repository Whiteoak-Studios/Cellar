# Changelog

Every notable change to Cellar is recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Cellar is rewritten from ObjectCache 3.5.2 (`fadeluc-123/objectcache`), so its first release lists its changes against that version.

## [0.1.0] - 2026-11-02

### Added

- `getAll(category)`, which returns a category's copies as two fresh arrays, `idle` and `out`, for a caller that walks every copy, such as a texture quality change. It allocates on every call, so it belongs at boot or on a settings change.
- The exported type `Copies`, the shape `getAll` returns, which a game reaches as `Cellar.Copies` after the typed install.
- Moonwave doc comments on the public API.

### Changed

- The package is `fadeluc-123/cellar`, installed as `Cellar = "fadeluc-123/cellar@^0.1.0"` and required as `require(ReplicatedStorage.Packages.Cellar)`. `fadeluc-123/objectcache` stays installable at 3.5.2 and gets no further versions.
- Cellar is licensed under the Apache License 2.0. ObjectCache was MIT licensed.
- A game requires Cellar bare and keeps full types, after the three typed-install commands in the README. ObjectCache 3.5.2 had to be required `: any`, since its annotations declared `get`'s `name` as required.
- The source is strict-mode `.luau`, written for luau-lsp's new type checker.
- `create`, `add`, `rebound` and `remove` return a boolean. A second `create` of a name warns and returns `false`, keeping the first category, where 3.5.2 warned and returned nil.
- A category has one parent. `add`'s parent is optional, and nil means the category's parent. A category declared with no parent takes the first `add`'s parent, or the Workspace when that `add` passes none, and an `add` that names a different parent errors at the call, naming both. In 3.5.2 `add` required a parent while `create`'s was optional, so the two could disagree and `rebound` put copies somewhere other than where `add` had.
- `add` takes a template that is not in the DataModel, such as a tree built in memory. 3.5.2 asserted that the template was in the DataModel.

### Fixed

- Parked copies no longer stack at one point. 3.5.2 parked them at an infinite CFrame, which the engine clamps to (0, -1,000,000, 0), so every parked copy landed on one spot and a pooled Model lost its shape. Copies now park at the finite point (0, -100,000, 0), and a pooled Model comes back within about 0.004 studs of its shape.
- `get` with a count returns copies. Its loop started at 0 and handed back the loop index in place of each copy, so a count of 2 returned `{ 1, 2 }` and lost two copies from the pool. A count now returns up to that many copies, each marked out.
- A named `get` that finds no copy of that name returns nil and takes nothing. In 3.5.2 it returned the first copy without taking it off the list or marking it out, so that copy could be handed out twice, and `rebound` then refused it.
- `get` on a category that was never declared returns nil at once. 3.5.2 waited 10 seconds, warned, then errored indexing nil.
- `remove` destroys the copies it takes, and takes no more than its count. 3.5.2 dropped them from its list and left them parked in the world, and with a count its loop, which started at 0, dropped one more than asked.
- An error in `add` reaches the caller at the call. 3.5.2 cloned inside a Promise with no handler, so an error showed only as a warning about an unhandled rejection.
- `get` and `remove` take from the end of the list, so their cost does not grow with the pool, and the copy given back most recently is the next one out. 3.5.2 took from the front with `table.remove(items, 1)`, which shifted every remaining copy.
- A copy destroyed while it is out leaves the out record and never rejoins the pool, and `rebound` on it warns and returns `false`. In 3.5.2 the copy stayed in the record for good, and `rebound` on it threw, since a destroyed instance's `Parent` is locked.
- `add` refuses a template whose `Archivable` is false, at the call, with a message naming it. `Clone` returns nil for such a template, so 3.5.2 warned and then errored at `clone.Parent`, inside the unhandled Promise.
- ObjectCache's README gave `get` the order `(category, count)`, gave `create` no parent and listed search modes the source never had. Cellar's README gives `get(count, category, name)`, the order 3.5.2's source used, and documents every function as it behaves.

### Removed

- The public `cache` and `inUse` fields. A category's lists are private, and `getAll` gives a caller its copies.
- The dependency on Promise, with ObjectCache's require of the game's own Promise at `ReplicatedStorage.Packages.Promise`. Cellar has no dependencies.
