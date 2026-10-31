# Castlevania: Belmont's Curse — LiveSplit

An ASL autosplitter with **selectable boss checks**, **first-movement auto-start**, **loading-screen removal**, and bundled boss portraits. Choose which boss defeats should split in the autosplitter settings. Each selected defeat advances the current LiveSplit segment; split names are freely editable display labels.

## Included files

| File | Purpose |
| --- | --- |
| [BelmontsCurse-Bosses.asl](BelmontsCurse-Bosses.asl) | Boss checks, auto-start, and loading removal. |
| [BelmontsCurse-Bosses-MovementStart.lsl](BelmontsCurse-Bosses-MovementStart.lsl) | Ready-to-load layout with the autosplitter component. |
| [BelmontsCurse-Bosses-Talos-First.lss](BelmontsCurse-Bosses-Talos-First.lss) | Ten-boss labels with Talos before Carmilla and embedded portraits. |
| [BelmontsCurse-Bosses-Carmilla-First.lss](BelmontsCurse-Bosses-Carmilla-First.lss) | Ten-boss labels with Carmilla before Talos and embedded portraits. |

Both supplied routes use the same script. Their rows describe the expected gameplay order; they do not configure detection.

## Setup

1. Select **Code → Download ZIP** on GitHub and extract it into a permanent folder. Keep the script, layout, and route files together.
2. In LiveSplit, right-click **Open Splits → From File** and choose either supplied `.lss`. Keep your own file if it contains PBs or other times you want to preserve.
3. Right-click **Open Layout → From File** and choose `BelmontsCurse-Bosses-MovementStart.lsl`.
4. Open **Edit Layout**, double-click **Scriptable Auto Splitter**, and browse to the updated `BelmontsCurse-Bosses.asl` from this download. Keep **Starting** and **Splitting** enabled.
5. Under **Boss defeats**, select the bosses you want to split on. All ten are enabled by default. Save the layout after changing these settings.
6. Load the layout and reset the timer **before creating a new save**. Creating that save arms auto-start; the first accepted directional movement starts timing. Reset manually between attempts, then create another new save.

The normal Start/Split hotkey remains available. Auto-start and loading removal work independently of the selected boss checks.

## Choose your boss checks

Configure selections before an attempt in **Edit Layout → Scriptable Auto Splitter → Boss defeats**.

| Checkbox | Check |
| --- | --- |
| Defeat The Fallen | Defeat The Fallen |
| Defeat Joan | Defeat Joan |
| Defeat Medusa | Defeat Medusa |
| Defeat Death 1 (Catacombs) | Defeat Death in the Catacombs |
| Defeat Isaac 1 (first encounter) | Defeat Isaac in the first encounter |
| Defeat Talos | Defeat Talos |
| Defeat Carmilla | Defeat Carmilla |
| Defeat Death 2 | Defeat Death in the second encounter |
| Defeat Isaac 2 | Defeat Isaac in the second encounter |
| Dracula: final beast reaches 0 HP | Final beast-form Dracula health falls from above zero to 0 HP |

For example, selecting only **Medusa**, **Carmilla**, and **Dracula** produces a split for each of those defeats as they happen. Create three matching segment labels in the order you expect to defeat them. The script does not validate row count or label order.

Only these ten checks currently have game detectors. Ability, location, and collectible-count checks can be added later.

## Edit labels or keep existing times

Reset the timer, then open **Edit Splits**. Rename, add, remove, or reorder rows to match the selected events in your expected gameplay order, then save. Any labels work, including duplicates. The names, category, and old route metadata do not choose which boss splits.

You can keep your existing `.lss` with its PBs, comparisons, best segments, history, and portraits. Tags from an older version, such as `[talos]`, are now ordinary visible text; remove them from the **Name** column if you want plain labels. You do not need to replace your splits file. Use **Save Splits As** first to keep an untouched copy.

Boss selections are saved with the layout when using the supplied Scriptable Auto Splitter component. Save that layout after changing selections; loading a different `.lss` changes labels and times, not the selected checks.

## What happens during a run

- **Selected events advance the current row in gameplay order.** Each boss check can automatically split at most once per attempt. Death 1/2 and Isaac 1/2 are separate checks.
- **No historical catch-up.** Disabled progression checks are still observed and consumed. Enabling Dracula starts a fresh HP observation; an initial zero does not split. Multiple selected events observed in the same poll produce one split, with no queued splits afterward.
- **Manual split, skip, and undo remain available.** They do not rearm consumed checks. There are no reserved manual rows: a selected boss event can split whichever row is current. To time manually, disable **Splitting** or the **Boss defeats** group while keeping the component enabled for auto-start and loading removal.
- **Historical defeats are ignored.** Attaching, starting, and loading an existing save establish a baseline instead of replaying completed bosses. Keep the timer running when you want a defeat to split.
- **Auto-start needs a newly created save.** Holding a direction through the opening starts timing when the game accepts movement. Keyboard and controller work; jump or attack alone does not start it. Loading an existing save or attaching during an already-created new-save intro does not arm a late start. Resetting on the same save does not rearm it.
- **Reset remains manual.** Create another new save after resetting for the next attempt.

When Dracula is selected, the HP detector operates regardless of the current row's name or position. It must observe the final beast form alive, then see it reach 0 HP in the same encounter. First-form zero HP, the beast's temporary 1-HP grab protection, and an initial sample already at zero do not split. LiveSplit ends the run when its last segment is completed.

## Game Time and compatibility

The script and bundled layout use **Game Time**; LiveSplit also records Real Time. Visible room-to-room loading icons pause Game Time. Menu and save loads pause it only while the full-screen red-and-gold **Loading** artwork is visible. The bat curtains before and after the artwork, normal menus, background room prefetch, and missing-player intervals do not pause it by themselves. Boundaries are observed at 30 samples per second.

Built for the verified **Steam 1.1.3** binary and **LiveSplit 1.8.25 on 64-bit Windows**. The self-contained script reads memory without modifying the game or save files. It checks `GameAssembly.dll` before using its offsets; a changed game binary requires an updated script. Portraits are embedded in the supplied `.lss` files.

## Validation

The memory readers retain the earlier implementation's validation: both original ten-boss orders passed checks in LiveSplit's native ASL engine, alongside movement-start, loading-pause, and zero-HP safety checks. The route files and portraits were loaded and rendered with LiveSplit. Native tests covered separate room and full-screen visibility, menu time, background loading flags, transient read failures, and restored progression during loading.

Earlier live checks confirmed the loading-artwork boundaries within one poll, with no historical boss splits after reloading. A separate reader found the visible artwork with its cache cleared. The final-beast HP detector was verified live: an independent test timer ended at 0 HP while Dracula's defeat flag remained unset. First-form zero HP and the beast's temporary 1 HP did not cause a finish. These checks only read game memory and did not change the game or the user's saved splits.

The settings-based event selection and expanded component classification cache have separate local regression checks; those checks do not replace a Windows LiveSplit or game run. A complete ten-boss run has not yet been verified live. See [development notes](docs/DEVELOPMENT.md) for the architecture and test instructions.
