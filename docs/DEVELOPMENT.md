# Autosplitter development

`BelmontsCurse-Bosses.asl` is a self-contained ASL script. It keeps the original filename so existing layouts can select the update. The bundled `.lss` files provide cosmetic labels, portraits, and expected route order; settings choose the events that split.

## Architecture

### Check catalog and settings

The startup catalog assigns each check a stable string ID and display name. The current IDs are `fallen`, `joan`, `medusa`, `death_1`, `isaac_1`, `talos`, `carmilla`, `death_2`, `isaac_2`, and `dracula`. The **Boss defeats** settings group has ID `bosses`, with child settings named `boss_` plus the check ID. The group and all ten checks default to enabled.

Names, categories, old `BelmontsCurse.Route` metadata, and segment positions do not configure detection. A selected event advances the current row. There is no row-count or route-order validation, so users arrange cosmetic labels to match the order of selected events in gameplay.

This follows the settings-based event-selection pattern in [Timespinner's ASL](https://github.com/Coltaho/Autosplitters/blob/e4350dbf9720f766632b736c9f7571d3c9b2b4ca/Timespinner/Timespinnerautosplit.asl#L219), which checks settings and records completed events separately from segment names. Our consumption rules below also prevent delayed or unselected events from creating a backlog.

### Detectors

The first nine checks use newly appearing progression GUIDs. Their flags are observed regardless of selection, so unselected events can be consumed immediately. Dracula uses a separate final-beast HP reader and a positive-to-zero edge for the same entity, stat, context, and save. When that check is selected, its detector operates independently of the current row's name and position. It must observe positive HP before zero. The final HP event must not depend on the player progression component remaining available during a death or cutscene.

Dracula's search caches fully classified component dictionaries for both boss and non-boss entities. Dictionary identity/version and native entity/context identities validate each cached classification; context changes clear the cache. Unknown component identities are retried. This reduces repeated component classification while keeping the 30 Hz health sampling rate. Deselecting Dracula resets HP continuity; enabling it requires a fresh positive-to-zero observation.

Reader guards are part of detection correctness: preserve the exact binary hash gate, stable-sample checks, loading-flow gates, and baselines after attach, save changes, failed reads, starts, and resets. Restored progression and a first observed Dracula HP value of zero are baselines, not new defeats.

New-save movement-start detection and loading removal operate independently of boss selections. All checks can be disabled while retaining both features.

### Event router

Each observed check is consumed at most once per attempt, including unselected checks. A consumed check cannot replay after undo, rollback, or later enabling its checkbox. Multiple selected events observed in one poll are consumed together and produce at most one split. The router does not queue events.

A pending split must remain tied to the same run, current segment, index, and routing revision until `split` accepts it. Manual split, skip, undo, run replacement, and edits must not move an old event onto a new row. They also do not rearm consumed checks. Reset clears attempt state; baselines prevent historical state from replaying after attachment or loading.

No row is reserved for manual splitting. Any selected event can advance any current row. Users who want manual timing disable **Splitting** or the **Boss defeats** group.

## Add a supported check

1. Verify the game's actual memory source and event semantics for the supported binary.
2. Add a unique stable ID and display name to `vars.checkNames`; startup automatically registers a default-enabled `boss_<id>` child of `bosses`. For a progression check, add its verified GUID and ID to `vars.flagChecks`.
3. Implement the detector separately from event routing. Define its baseline, identity, loading, and read-failure behavior. Produce fresh events instead of treating an indefinitely true completion flag as a new event on every poll.
4. Feed the event through the common router and consume it even when unselected. A detector gated by selection must establish a fresh baseline when enabled so completion already present cannot replay.
5. Add regressions for selection, disabled groups, historical state, loading, failed reads, simultaneous events, repeats, and manual timer changes. A repeatable condition needs an explicit repeat policy; the existing boss checks are once per attempt.
6. Document the checkbox in the README. Validate the complete script with LiveSplit's native ASL engine on Windows before claiming runtime compatibility, and verify the detector in the game before claiming live validation.

Ability, location, and counter checks are extension points, not implemented features. Adding a catalog entry or checkbox alone does not make a usable detector.

## Files and settings persistence

The script uses standard ASL checkbox settings. With the supplied Scriptable Auto Splitter layout, selections are saved in the `.lsl` layout. The default `<CustomSettings />` is empty because all checks default to enabled. LiveSplit also supports activating ASL from the Splits Editor; in that hosting mode, its settings are stored with the splits instead.

The bundled `.lss` files contain plain names and retain embedded portraits, times, and history. Existing user files need no replacement: old tags are ordinary display text and can be removed in Edit Splits. Preserve XML content unrelated to names when editing these files. No renderer adapter, display component, hidden text, or positional route mapping is required.

## Validation scope

Run the regression suite from the repository root with Python 3 and the .NET 8 SDK installed:

```sh
python3 tests/run_tests.py
```

Use `python3 tests/run_tests.py --dotnet /path/to/dotnet` to select an explicit SDK executable. The harness extracts the actual ASL actions and supplies fake timer and memory data. It compiles the full `init` action but does not invoke it, so it does not attach to a process or read the game.

Local tests exercise settings, event consumption, current-row advancement, stale events, manual timer changes, resets, and run changes. The extracted Dracula component reader is also tested against synthetic dictionaries. Synthetic samples cannot verify Windows memory layouts or timing against real gameplay. The earlier native-ASL and live memory-reader checks in the README remain historical evidence for those detectors; the changed event selection and component classification cache need their own native-ASL and live validation.

## LiveSplit references

- [Official ASL documentation](https://github.com/LiveSplit/LiveSplit.AutoSplitters#the-auto-splitting-language---asl): actions, boolean settings, persistence, execution order, and testing.
- [LiveSplitState source](https://github.com/LiveSplit/LiveSplit/blob/master/src/LiveSplit.Core/Model/LiveSplitState.cs): current run, phase, segment, split index, and timer events.
- [Scriptable Auto Splitter source](https://github.com/LiveSplit/LiveSplit.ScriptableAutoSplit): ASL host and runtime implementation.
