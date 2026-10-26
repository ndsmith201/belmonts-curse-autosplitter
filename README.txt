Castlevania: Belmont's Curse -- latest LiveSplit package

FILES
BelmontsCurse-Bosses.asl -- first-movement start, boss splits, loading removal.
BelmontsCurse-Bosses-MovementStart.lsl -- latest compact layout.
BelmontsCurse-Bosses.lss -- ten ordered boss splits with embedded portraits.

SETUP
1. Extract all files into a permanent folder.
2. In LiveSplit, right-click > Open Splits > From File and select the .lss.
   This supplied route has no recorded times. Keep your own .lss if it has PBs.
3. Right-click > Open Layout > From File and select the MovementStart .lsl.
4. Right-click > Edit Layout, double-click Scriptable Auto Splitter, and browse
   to the .asl you just extracted. Keep Starting and Splitting enabled. Save the
   layout. Its saved script path initially points to the original build folder,
   so this step makes LiveSplit use your extracted copy.
5. Load the layout before creating a new save. Reset the timer, then create a
   new save. Your first directional gameplay movement starts the timer after
   controls become available. Keyboard and controller movement are supported.
   Reset manually before the next attempt and create another new save.

Loading screens pause Game Time automatically. The layout uses Game Time;
Real Time is also recorded. Normal menus do not pause Game Time.
Loading an existing save does not arm or start the timer.
All ten boss portraits are embedded; no extra image files are needed.

ORDER
The Fallen, Joan, Medusa, Death 1, Isaac 1, Talos, Carmilla, Death 2, Isaac 2,
Dracula. Dracula finishes the run on the final beast-form defeat flag.

Built for the verified Steam 1.1.3 binary and LiveSplit 1.8.25 on 64-bit Windows.
The script is self-contained; it reads game memory without modifying saves.
