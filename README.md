# Castlevania: Belmont's Curse — LiveSplit

A ten-boss autosplitter with **first-movement auto-start**, **loading-screen removal**, and a compact layout with embedded boss portraits.

<p align="center">
  <img src="assets/livesplit-layout.png" alt="LiveSplit layout showing all ten boss portraits and the compact timer" width="360">
</p>

## Included files

| File | Purpose |
| --- | --- |
| [BelmontsCurse-Bosses.asl](BelmontsCurse-Bosses.asl) | Detects movement, boss defeats, and loading screens. |
| [BelmontsCurse-Bosses-MovementStart.lsl](BelmontsCurse-Bosses-MovementStart.lsl) | Ready-to-load layout with the autosplitter component. |
| [BelmontsCurse-Bosses.lss](BelmontsCurse-Bosses.lss) | Ten ordered boss splits with embedded portraits. |

## Setup

1. Select **Code → Download ZIP** on GitHub and extract it into a permanent folder. Keep the three files above together.
2. In LiveSplit, right-click **Open Splits → From File** and choose `BelmontsCurse-Bosses.lss`. This is a blank route with no recorded times; keep your own `.lss` if it contains PBs you want to preserve.
3. Right-click **Open Layout → From File** and choose `BelmontsCurse-Bosses-MovementStart.lsl`.
4. Open **Edit Layout**, double-click **Scriptable Auto Splitter**, and browse to the `BelmontsCurse-Bosses.asl` you extracted. The supplied layout initially references its original build folder, so select your local copy even if a path is already shown. Keep **Starting** and **Splitting** enabled, then save the layout.
5. Load the layout and reset the timer **before creating a new save**. Creating that save arms auto-start; your first directional movement starts the timer once gameplay controls become available. Keyboard and controller movement both work.
6. Reset manually between attempts, then create another new save. The normal Start/Split hotkey remains available.

## Timing behavior

- **Auto-start:** a newly created save arms the timer. Holding a direction through the opening starts timing when the game first accepts movement. Jump or attack alone does not start it.
- **Existing saves:** loading an existing save does not arm or start the timer. Attaching during an already-created new-save intro does not trigger a late start.
- **Game Time:** loading screens pause the clock automatically. Normal menus do not pause it. The script and included layout use Game Time; LiveSplit also records Real Time.
- **Boss splits:** each boss splits when its live defeat flag appears. Keep the ten segments in the order below and keep the timer running during boss defeats. Previously defeated bosses are ignored when attaching or starting.
- **Reset:** resets remain manual. Resetting on the same save does not rearm auto-start; create another new save for the next attempt.

## Boss order

| # | Boss |
| --- | --- |
| 1 | The Fallen |
| 2 | Joan |
| 3 | Medusa |
| 4 | Death 1 — Catacombs |
| 5 | Isaac 1 — first encounter |
| 6 | Talos |
| 7 | Carmilla |
| 8 | Death 2 |
| 9 | Isaac 2 |
| 10 | Dracula — final beast form |

Dracula's first-form defeat does not finish the run. Splits follow the game's defeat flags, which may appear after a defeat animation.

## Compatibility and validation

Built for the verified **Steam 1.1.3** game binary and **LiveSplit 1.8.25 on 64-bit Windows**. The script locates the running game automatically and is self-contained; it reads memory without modifying the game or saves. All portraits are embedded in the splits file.

The script checks `GameAssembly.dll` before using its offsets. A changed game binary requires an updated script.

Live memory reads and simulated timer scenarios have been checked. A complete live ten-boss run has not been tested, so try the next boss in a practice run before relying on it for a PB.
