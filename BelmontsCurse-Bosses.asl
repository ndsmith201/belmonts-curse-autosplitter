// Castlevania: Belmont's Curse -- selectable boss events, Windows Steam build 1.1.3.
// Reads boss progression and final Dracula HP without writing to the game's memory or save files.
// A new save arms auto-start; the first accepted movement input starts timing.
// Reset manually between attempts.
// Select boss events in the ASL settings; each selected event advances the current row.
// Split names are cosmetic. Keep labels in the expected gameplay order; no tags are needed.
// Game Time removes visible room loads and red/gold loading artwork; LiveSplit also records Real Time.
// GameAssembly.dll SHA256: 4904978ba2c15884185cfaea8d348dfb8ffe69d466fafed1f46fb963a7276152
// Defeat GUIDs were extracted from this installed build's actual assets.

state("Castlevania Belmont's Curse") {}

startup
{
    refreshRate = 30;
    // CHECK CATALOG: stable setting/event keys, independent of displayed names.
    vars.checkNames = new Dictionary<string, string> {
        { "fallen", "The Fallen" }, { "joan", "Joan" }, { "medusa", "Medusa" },
        { "death_1", "Death 1" }, { "isaac_1", "Isaac 1" },
        { "talos", "Talos" }, { "carmilla", "Carmilla" },
        { "death_2", "Death 2" }, { "isaac_2", "Isaac 2" }, { "dracula", "Dracula" }
    };
    // DETECTORS: progression GUID -> catalog key. Dracula uses live HP instead.
    vars.flagChecks = new Dictionary<string, string> {
        { "20c378a72ad9c664686476a360b99777", "fallen" },
        { "641325fec3360bb459c879275fdee639", "joan" },
        { "ac985fb3574b3cc4eadaf3a79793112e", "medusa" },
        { "769b38ad62fa14249b54a74ef889998c", "death_1" },
        { "99cd7d3d4e286c84da47e29d2fbb7e83", "isaac_1" },
        { "3c8796f7f58e2634eb4bcc8fe8a49746", "talos" },
        { "4a7b39e0c582899409003620d44f5712", "carmilla" },
        { "c94c4e1cc1f8dbf4fb525f2c6b94920c", "death_2" },
        { "e47322c821f3eda4999f654f86dad494", "isaac_2" }
    };
    // Native ASL settings are checkboxes. All ten boss events are on by default.
    settings.Add("bosses", true, "Boss defeats");
    foreach (var check in (Dictionary<string, string>)vars.checkNames)
    {
        string description = check.Key == "dracula" ? "Dracula: final beast reaches 0 HP"
            : check.Key == "death_1" ? "Defeat Death 1 (Catacombs)"
            : check.Key == "isaac_1" ? "Defeat Isaac 1 (first encounter)"
            : "Defeat " + check.Value;
        settings.Add("boss_" + check.Key, true, description, "bosses");
    }
    vars.resetDracula = (Action)(() => {
        vars.draculaEntity = 0L;
        vars.draculaStat = 0L;
        vars.draculaContext = 0L;
        vars.draculaSave = 0L;
        vars.draculaPositive = false;
        vars.draculaValid = false;
        vars.draculaHealth = -1.0f;
        vars.draculaMaximum = -1.0f;
        vars.draculaStatus = "Waiting for final Dracula health";
    });
    vars.resetDracula();
    // The live final-form reader is installed in init; null means no encounter.
    vars.draculaSnapshot = (Func<object[]>)(() => null);
    // EVENT SELECTION: consume each observed event once per attempt, including
    // unchecked progression events. The first selected event advances the row.
    // No event backlog, name matching, or independent route cursor is needed.
    vars.flags = new HashSet<string>();
    vars.seenChecks = new HashSet<string>();
    vars.enabledChecks = new HashSet<string>();
    vars.observedRun = (object)timer.Run;
    vars.segmentRevision = 0;
    vars.sampleRevision = -1;
    vars.sampleRun = (object)null;
    vars.sampleSegment = (object)null;
    vars.sampleIndex = -1;
    vars.clearTrigger = (Action)(() => {
        vars.triggerIndex = -1;
        vars.triggerCheck = (string)null;
        vars.triggerRun = (object)null;
        vars.triggerSegment = (object)null;
    });
    vars.clearTrigger();
    vars.invalidateSegment = (Action)(() => {
        vars.segmentRevision = (int)vars.segmentRevision + 1;
        vars.clearTrigger();
        vars.resetDracula();
    });
    // ASL rewrites every bare return to return null, including inside lambdas.
    // Use a value-returning delegate so its early exits stay valid C#.
    vars.emitCheck = (Func<string, bool>)(key => {
        if (!vars.seenChecks.Add(key)) return false;
        if (!vars.enabledChecks.Contains(key) || vars.triggerCheck != null) return false;
        int index = timer.CurrentSplitIndex;
        if (timer.CurrentPhase != TimerPhase.Running || timer.Run == null
            || index < 0 || index >= timer.Run.Count || index != (int)vars.sampleIndex
            || (int)vars.sampleRevision != (int)vars.segmentRevision
            || !Object.ReferenceEquals((object)timer.Run, (object)vars.sampleRun)
            || !Object.ReferenceEquals((object)timer.Run[index], (object)vars.sampleSegment)) return false;
        vars.triggerIndex = index;
        vars.triggerCheck = key;
        vars.triggerRun = (object)timer.Run;
        vars.triggerSegment = (object)timer.Run[index];
        return true;
    });
    // onSplit is an ASL action. Skip/undo require LiveSplit's native events.
    vars.segmentChanged = (EventHandler)((sender, args) => vars.invalidateSegment());
    timer.OnSkipSplit += vars.segmentChanged;
    timer.OnUndoSplit += vars.segmentChanged;
    vars.valid = false;
    vars.supported = false;
    vars.baselineNeeded = true;
    vars.startRequested = false;
    vars.startArmed = false;
    vars.armedSaveObject = 0L;
    vars.saveBaselineReady = false;
    vars.lastSaveObject = 0L;
    vars.loading = false;
    vars.loadingValid = false;
    vars.loadingArtworkFlowActive = false;
    vars.loadingArtworkFlowKnown = true;
    vars.fullLoadingScreenSnapshot = (Func<bool?>)(() => null);
    timer.CurrentTimingMethod = TimingMethod.GameTime;
    vars.saveStatus = "Waiting to observe the current save";
    vars.status = "Waiting for the game";
}

init
{
    vars.resetDracula();
    vars.valid = false;
    vars.baselineNeeded = true;
    vars.clearTrigger();
    vars.startRequested = false;
    vars.startArmed = false;
    vars.armedSaveObject = 0L;
    vars.saveBaselineReady = false;
    vars.lastSaveObject = 0L;
    vars.mc = 0L;
    vars.component = 0L;
    vars.componentClass = 0L;
    vars.inputEntity = 0L;
    vars.inputCache = 0L;
    vars.inputEntries = 0L;
    vars.inputVersion = -1;
    vars.inputComponent = 0L;
    vars.inputClass = 0L;
    vars.inputIndices = new int[] { -1, -1, -1 };
    vars.loading = false;
    vars.loadingValid = false;
    var module = modules.FirstOrDefault(m => m.ModuleName == "GameAssembly.dll");
    if (module == null) throw new Exception("GameAssembly.dll has not loaded yet.");
    vars.baseAddress = module.BaseAddress.ToInt64();

    // Fixed offsets are accepted only for the exact binary inspected and tested.
    string hash;
    using (var sha = System.Security.Cryptography.SHA256.Create())
    using (var file = File.OpenRead(module.FileName))
        hash = BitConverter.ToString(sha.ComputeHash(file)).Replace("-", "").ToLowerInvariant();
    vars.supported = hash == "4904978ba2c15884185cfaea8d348dfb8ffe69d466fafed1f46fb963a7276152";
    version = vars.supported ? "Steam 1.1.3 (verified binary)" : "Unsupported game build";
    vars.status = vars.supported ? "Waiting for a loaded save" : "Unsupported GameAssembly.dll -- update this script";
    print(vars.status);

    vars.read = (Func<long, int, byte[]>)((address, length) => {
        if (address < 0x10000 || length < 0 || length > 1048576)
            throw new Exception("Invalid memory range");
        var bytes = game.ReadBytes(new IntPtr(address), length);
        if (bytes == null || bytes.Length != length) throw new Exception("Incomplete memory read");
        return bytes;
    });
    vars.ptr = (Func<long, long>)(address => BitConverter.ToInt64(vars.read(address, 8), 0));
    vars.i32 = (Func<long, int>)(address => BitConverter.ToInt32(vars.read(address, 4), 0));
    vars.guid = (Func<long, string>)(address => {
        int length = vars.i32(address + 0x10);
        if (length != 32) throw new Exception("Invalid progression GUID length");
        return Encoding.Unicode.GetString(vars.read(address + 0x14, 64));
    });
    vars.loadingFlag = (Func<long, bool>)(address => {
        byte value = vars.read(address, 1)[0];
        if (value > 1) throw new Exception("Invalid loading flag");
        return value == 1;
    });
    vars.roomLoadingVisible = (Func<long, bool>)(eventRva => {
        long type = vars.ptr((long)vars.baseAddress + eventRva);
        // An untouched IL2CPP metadata slot can still hold an encoded token.
        // No event subscribers/loading icon exist before this type initializes.
        if (type < 0x10000 || (type & 7) != 0) return false;
        long fields = vars.ptr(type + 0xB8);
        if (fields == 0) return false;
        long callback = vars.ptr(fields);
        if (callback == 0) return false;
        long calls = vars.ptr(callback + 0x78);
        long[] delegates;
        if (calls == 0) delegates = new long[] { callback };
        else
        {
            int count = vars.i32(calls + 0x18);
            if (count < 0 || count > 128) throw new Exception("Invalid loading event list");
            byte[] entries = vars.read(calls + 0x20, count * 8);
            delegates = new long[count];
            for (int i = 0; i < count; i++) delegates[i] = BitConverter.ToInt64(entries, i * 8);
        }
        foreach (long call in delegates)
        {
            if (call == 0) continue;
            long target = vars.ptr(call + 0x20);
            if (target == 0) continue;
            long klass = vars.ptr(target);
            byte[] nameBytes = vars.read(vars.ptr(klass + 0x10), 32);
            int end = Array.IndexOf(nameBytes, (byte)0);
            if (end < 0 || Encoding.ASCII.GetString(nameBytes, 0, end) != "RoomTransitionLoadingScreen")
                continue;
            if (vars.ptr(target + 0x10) == 0) continue;
            long icon = vars.ptr(target + 0x20);
            if (icon == 0) continue;
            long native = vars.ptr(icon + 0x10);
            if (native != 0 && vars.loadingFlag(native + 0x56)) return true;
        }
        return false;
    });
    vars.loadingSnapshot = (Func<bool>)(() => {
        bool unknown = false;
        // Keep room-to-room loading removal independent of the full-screen UI.
        try { if ((bool)vars.roomLoadingVisible(0x3F082C8L)) return true; }
        catch { unknown = true; }
        try { if ((bool)vars.roomLoadingVisible(0x3F08390L)) return true; }
        catch { unknown = true; }
        try
        {
            // Menu/save loads count only while their loading artwork is visible.
            // Engine loading flags can extend before/after that screen and must
            // never start or prolong a pause on their own.
            bool? visible = vars.fullLoadingScreenSnapshot();
            if (visible.HasValue)
            {
                if (visible.Value) return true;
            }
        }
        catch { unknown = true; }
        if (unknown) throw new Exception("Visible loading-screen data is temporarily unavailable");
        return false;
    });
    vars.saveSnapshot = (Func<object[]>)(() => {
        // SingletonScriptableObject<SaveLogic>.Instance MethodInfo -> rgctx
        // -> closed singleton class -> static instance. Verified for this build.
        long method = vars.ptr((long)vars.baseAddress + 0x3F16AD8);
        long owner = vars.ptr(method + 0x20);
        long context = vars.ptr(owner + 0xC0);
        long singleton = vars.ptr(context + 0x10);
        long logic = vars.ptr(vars.ptr(singleton + 0xB8));
        long save = vars.ptr(logic + 0x50);
        if (save == 0) return new object[] { 0L, false };
        long player = vars.ptr(save + 0x18);
        long id = vars.ptr(player + 0x10);
        int idLength = id == 0 ? 0 : vars.i32(id + 0x10);
        long level = vars.ptr(player + 0x28);
        int levelLength = level == 0 ? 0 : vars.i32(level + 0x10);
        long progress = vars.ptr(player + 0x58);
        int progressCount = progress == 0 ? 0 : vars.i32(progress + 0x18);
        float playTime = BitConverter.ToSingle(vars.read(player + 0x20, 4), 0);
        bool hasSpawn = vars.read(player + 0x24, 1)[0] != 0;
        if (idLength < 0 || idLength > 128 || levelLength < 0 || levelLength > 128
            || progressCount < 0 || progressCount > 8192 || float.IsNaN(playTime) || playTime < 0)
            throw new Exception("Invalid save creation sample");
        if (save != vars.ptr(logic + 0x50) || player != vars.ptr(save + 0x18)
            || id != vars.ptr(player + 0x10) || level != vars.ptr(player + 0x28)
            || progress != vars.ptr(player + 0x58))
            throw new Exception("Save changed during sample");
        // A new in-memory PlayerSave has no ID. SavePlayer assigns a GUID
        // before writing any normal save to disk, including an unplayed one.
        bool fresh = idLength == 0 && playTime == 0 && !hasSpawn
            && levelLength == 0 && progressCount == 0;
        return new object[] { save, fresh };
    });
    vars.nativeName = (Func<long, string>)(address => {
        byte[] bytes = vars.read(address, 64);
        int end = Array.IndexOf(bytes, (byte)0);
        return end < 0 ? "" : Encoding.ASCII.GetString(bytes, 0, end);
    });
    // Install in init after read/ptr/i32. Exact installed Steam1.1.3 native layouts.
    // Timing uses the actual red/gold ScreenContent AND its loading camera only.
    // Bats, application-launch black screens, videos and NoRose fades are excluded.
    // Flow flags below are diagnostics for boss rebaselining, NEVER timing inputs.
    vars.loadingArtworkFlowActive = false;
    vars.loadingArtworkFlowKnown = false;
    vars.artworkBudget = new int[] { 0 };
    vars.artworkClassNames = new Dictionary<long, string>();
    vars.artworkBindings = new Dictionary<long, long[]>();
    vars.artworkName = (Func<long, string>)(obj => {
        long klass = vars.ptr(obj);
        if (klass < 0x10000 || (klass & 7) != 0) throw new Exception("Invalid artwork object type");
        string name;
        if (!vars.artworkClassNames.TryGetValue(klass, out name)) {
            byte[] bytes = vars.read(vars.ptr(klass + 0x10), 96);
            int end = Array.IndexOf(bytes, (byte)0);
            if (end <= 0) throw new Exception("Invalid artwork type name");
            name = Encoding.ASCII.GetString(bytes, 0, end);
            vars.artworkClassNames[klass] = name;
        }
        return name;
    });
    vars.artworkString = (Func<long, string>)(obj => {
        if (obj == 0) return "";
        int count = vars.i32(obj + 0x10);
        if (count < 0 || count > 512) throw new Exception("Invalid artwork string");
        return Encoding.Unicode.GetString(vars.read(obj + 0x14, count * 2));
    });
    vars.artworkNativeName = (Func<long, string>)(native => {
        long name = vars.ptr(native + 0x60);
        if (name < 0x10000) throw new Exception("Invalid artwork GameObject name");
        byte[] bytes = vars.read(name, 96);
        int end = Array.IndexOf(bytes, (byte)0);
        if (end < 0) throw new Exception("Unterminated artwork GameObject name");
        return Encoding.UTF8.GetString(bytes, 0, end);
    });
    vars.artworkList = (Func<long, long[]>)(list => {
        if (list == 0) return new long[0];
        long items = vars.ptr(list + 0x10);
        int count = vars.i32(list + 0x18), stamp = vars.i32(list + 0x1C);
        if (count < 0 || count > 128 || (count > 0 && (items == 0 || vars.i32(items + 0x18) < count)))
            throw new Exception("Invalid artwork source list");
        byte[] data = count == 0 ? new byte[0] : (byte[])vars.read(items + 0x20, count * 8);
        long[] result = new long[count];
        for (int i = 0; i < count; i++) result[i] = BitConverter.ToInt64(data, i * 8);
        if (items != vars.ptr(list + 0x10) || count != vars.i32(list + 0x18) || stamp != vars.i32(list + 0x1C))
            throw new Exception("Artwork source list changed");
        return result;
    });
    vars.artworkTargets = (Func<long, long[]>)(callback => {
        if (callback == 0) return new long[0];
        long calls = vars.ptr(callback + 0x78);
        int count = calls == 0 ? 1 : (int)vars.i32(calls + 0x18);
        if (count < 0 || count > 128) throw new Exception("Invalid artwork delegates");
        long[] result = new long[count];
        for (int i = 0; i < count; i++) {
            long call = calls == 0 ? callback : (long)vars.ptr(calls + 0x20 + i * 8);
            result[i] = call == 0 ? 0L : (long)vars.ptr(call + 0x20);
        }
        if (calls != vars.ptr(callback + 0x78)) throw new Exception("Artwork delegates changed");
        return result;
    });
    vars.artworkRegistry = (Func<long, string, long[]>)((rva, requiredKey) => {
        long type = vars.ptr((long)vars.baseAddress + rva);
        if (type < 0x10000 || (type & 7) != 0) return new long[0];
        long fields = vars.ptr(type + 0xB8), registry = fields == 0 ? 0L : (long)vars.ptr(fields);
        if (registry == 0) return new long[0];
        long dictionary = vars.ptr(registry + 0x10), entries = vars.ptr(dictionary + 0x18);
        int count = vars.i32(dictionary + 0x20), stamp = vars.i32(dictionary + 0x2C);
        if (count < 0 || count > 128 || (count > 0 && (entries == 0 || vars.i32(entries + 0x18) < count)))
            throw new Exception("Invalid artwork registry");
        var result = new List<long>();
        for (int i = 0; i < count; i++) {
            long entry = entries + 0x20 + i * 24;
            if (vars.i32(entry) < 0) continue;
            if (requiredKey != "" && (string)vars.artworkString((long)vars.ptr(entry + 8)) != requiredKey) continue;
            long holder = vars.ptr(entry + 0x10);
            if (holder != 0) result.Add(holder);
        }
        if (entries != vars.ptr(dictionary + 0x18) || count != vars.i32(dictionary + 0x20)
            || stamp != vars.i32(dictionary + 0x2C) || dictionary != vars.ptr(registry + 0x10)
            || registry != vars.ptr(fields)) throw new Exception("Artwork registry changed");
        return result.ToArray();
    });
    // Native hierarchy lookup is scoped to ONE exact LoadingScreen root, not the world.
    // Verified getters: GO.transform=ptr(ptr(GO+30)+8); parent+90; children+70/count80.
    vars.artworkFindContent = (Func<long, long>)(managerNative => {
        long owner = vars.ptr(managerNative + 0x30);
        if (owner < 0x10000) throw new Exception("Loading camera manager has no GameObject");
        long transform = vars.ptr(vars.ptr(owner + 0x30) + 8), root = 0;
        for (int depth = 0; transform != 0 && depth < 16; depth++) {
            long go = vars.ptr(transform + 0x30);
            string name = vars.artworkNativeName(go);
            if (name == "LoadingScreen" || name == "LoadingScreenMainMenu") { root = transform; break; }
            long parent = vars.ptr(transform + 0x90);
            if (parent == transform) throw new Exception("Cyclic loading hierarchy");
            transform = parent;
        }
        if (root == 0) return 0L;
        var pending = new Stack<long>(); var seen = new HashSet<long>();
        pending.Push(root); long content = 0;
        while (pending.Count > 0) {
            long item = pending.Pop();
            if (!seen.Add(item)) continue;
            if (seen.Count > 256) throw new Exception("Artwork hierarchy budget exceeded");
            long go = vars.ptr(item + 0x30);
            if ((string)vars.artworkNativeName(go) == "ScreenContent") {
                if (content != 0 && content != go) throw new Exception("Ambiguous loading artwork");
                content = go;
            }
            long children = vars.ptr(item + 0x70); int count = vars.i32(item + 0x80);
            if (count < 0 || count > 128 || (count > 0 && children < 0x10000)) throw new Exception("Invalid artwork children");
            for (int i = 0; i < count; i++) pending.Push((long)vars.ptr(children + i * 8));
            if (children != vars.ptr(item + 0x70) || count != vars.i32(item + 0x80)) throw new Exception("Artwork hierarchy changed");
        }
        return content;
    });
    vars.artworkLearnManager = (Func<long, long, bool>)((manager, knownContent) => {
        if (manager == 0 || (string)vars.artworkName(manager) != "LoadingScreenCameraManager") return false;
        long klass = vars.ptr(manager), native = vars.ptr(manager + 0x10);
        if (native == 0) return false;
        if (native < 0x10000 || (native & 7) != 0) throw new Exception("Invalid loading camera manager");
        long camera = vars.ptr(manager + 0x30);
        if (camera == 0 || (string)vars.artworkName(camera) != "Camera") throw new Exception("Invalid loading artwork camera");
        long cameraClass = vars.ptr(camera), cameraNative = vars.ptr(camera + 0x10);
        if (cameraNative == 0) return false;
        long[] previous;
        if (vars.artworkBindings.TryGetValue(manager, out previous) && previous[0] == klass && previous[1] == native
            && previous[2] == camera && previous[3] == cameraClass && previous[4] == cameraNative
            && (knownContent == 0 || knownContent == previous[5])) {
            bool contentValid = false;
            try { contentValid = vars.ptr(previous[5]) == previous[6] && vars.ptr(previous[5] + 0x60) == previous[7]
                && (string)vars.artworkNativeName(previous[5]) == "ScreenContent"; } catch { }
            if (contentValid) return false;
        }
        long content = knownContent == 0 ? (long)vars.artworkFindContent(native) : knownContent;
        if (content == 0) return false;
        if ((string)vars.artworkNativeName(content) != "ScreenContent") throw new Exception("Unverified artwork GameObject");
        if (klass != vars.ptr(manager) || native != vars.ptr(manager + 0x10)
            || camera != vars.ptr(manager + 0x30) || cameraNative != vars.ptr(camera + 0x10))
            throw new Exception("Loading artwork binding changed");
        vars.artworkBindings[manager] = new long[] { klass, native, camera, cameraClass, cameraNative, content, vars.ptr(content), vars.ptr(content + 0x60) };
        return true;
    });
    // Immutable scene events explicitly pair ScreenContent.SetActive(true) and camera enable.
    vars.artworkEvent = (Func<long, bool>)(ev => {
        if (ev == 0) return false;
        long group = vars.ptr(ev + 0x18);
        if (group == 0) return false;
        long content = 0; var managers = new List<long>();
        foreach (long call in (long[])vars.artworkList((long)vars.ptr(group + 0x10))) {
            if (call == 0 || vars.i32(call + 0x38) == 0) continue;
            long target = vars.ptr(call + 0x10);
            if (target == 0) continue;
            string method = vars.artworkString((long)vars.ptr(call + 0x20));
            string name = vars.artworkName(target);
            if (name == "LoadingScreenCameraManager" && method == "EnableLoadingScreenCamera") managers.Add(target);
            if (name == "GameObject" && method == "SetActive") {
                long args = vars.ptr(call + 0x30), native = vars.ptr(target + 0x10);
                if (args != 0 && native != 0 && vars.read(args + 0x30, 1)[0] == 1
                    && (string)vars.artworkNativeName(native) == "ScreenContent") content = native;
            }
        }
        if (content != 0) foreach (long manager in managers) vars.artworkLearnManager(manager, content);
        return true;
    });
    vars.artworkGraph = (Func<long, int, bool>)((node, depth) => {
        if (node == 0) return false;
        if (depth > 8 || --vars.artworkBudget[0] < 0) throw new Exception("Artwork graph budget exceeded");
        string name = vars.artworkName(node);
        if (name == "LoadingScreenTransitionSequence") {
            long events = vars.ptr(node + 0x20); int count = events == 0 ? 0 : (int)vars.i32(events + 0x18);
            if (count < 0 || count > 64) throw new Exception("Invalid artwork events");
            for (int i = 0; i < count; i++) vars.artworkEvent((long)vars.ptr(events + 0x20 + i * 16 + 8));
            long items = vars.ptr(node + 0x18); count = items == 0 ? 0 : (int)vars.i32(items + 0x18);
            if (count < 0 || count > 64) throw new Exception("Invalid artwork transitions");
            for (int i = 0; i < count; i++) vars.artworkGraph((long)vars.ptr(items + 0x20 + i * 8), depth + 1);
        } else if (name == "LoadingScreenTransitionDebug") {
            vars.artworkEvent((long)vars.ptr(node + 0x20)); vars.artworkEvent((long)vars.ptr(node + 0x28));
        }
        return true;
    });
    vars.artworkController = (Func<long, int, bool>)((obj, depth) => {
        if (obj == 0) return false;
        if (depth > 8 || --vars.artworkBudget[0] < 0) throw new Exception("Artwork controller budget exceeded");
        string name = vars.artworkName(obj);
        if (name == "LoadingScreenBranchController") vars.artworkController((long)vars.ptr(obj + 0x38), depth + 1);
        else if (name == "LoadingScreenTransitionsController" && vars.ptr(obj + 0x10) != 0)
            vars.artworkGraph((long)vars.ptr(obj + 0x30), 0);
        // NoRose's LoadingScreenFadeController has no red/gold LOADING artwork.
        return true;
    });
    vars.artworkTask = (Func<long, int, bool>)((task, depth) => {
        if (task == 0) return false;
        if (depth > 12 || --vars.artworkBudget[0] < 0) throw new Exception("Artwork task budget exceeded");
        string name = vars.artworkName(task);
        if (name == "TaskSequence") foreach (long child in (long[])vars.artworkList((long)vars.ptr(task + 0x10))) vars.artworkTask(child, depth + 1);
        else if (name == "WaitForLoadingScreenUnloadTask") vars.artworkController((long)vars.ptr(task + 0x10), 0);
        return true;
    });
    vars.loadingArtworkSnapshot = (Func<bool>)(() => {
        vars.artworkBudget[0] = 512; vars.loadingArtworkFlowKnown = false;
        long afm = 0;
        foreach (long holder in (long[])vars.artworkRegistry(0x3F24238L, "ScrVar_GameManagement_ApplicationFlowManager")) {
            long candidate = vars.ptr(holder + 0x10);
            if (candidate != 0 && (string)vars.artworkName(candidate) == "ApplicationFlowManager" && vars.ptr(candidate + 0x10) != 0) afm = candidate;
        }
        bool scenePresent = false;
        if (afm != 0) {
            long sceneManager = vars.ptr(afm + 0x30);
            long[] lists = new long[2]; int[] counts = new int[2], stamps = new int[2];
            for (int n = 0; n < 2; n++) {
                long list = vars.ptr(sceneManager + 0x10 + n * 8); lists[n] = list;
                if (list != 0) { counts[n] = vars.i32(list + 0x18); stamps[n] = vars.i32(list + 0x1C); }
                foreach (long scene in (long[])vars.artworkList(list)) {
                    long wrapper = vars.ptr(scene + 0x20);
                    string path = vars.artworkString((long)vars.ptr(wrapper + 0x18));
                    if (path.IndexOf("/LoadingScreen/", StringComparison.OrdinalIgnoreCase) >= 0) scenePresent = true;
                }
            }
            for (int n = 0; n < 2; n++) if (lists[n] != (long)vars.ptr(sceneManager + 0x10 + n * 8)
                || (lists[n] != 0 && (counts[n] != (int)vars.i32(lists[n] + 0x18) || stamps[n] != (int)vars.i32(lists[n] + 0x1C))))
                throw new Exception("Artwork flow scene lists changed");
            if (sceneManager != (long)vars.ptr(afm + 0x30)) throw new Exception("Artwork flow manager changed");
        }
        long afmType = vars.ptr((long)vars.baseAddress + 0x3F5F570);
        bool engineLoading = false;
        if (afmType >= 0x10000 && (afmType & 7) == 0) {
            long fields = vars.ptr(afmType + 0xB8);
            if (fields != 0) engineLoading = vars.read(fields, 1)[0] == 1;
        }
        vars.loadingArtworkFlowActive = scenePresent || engineLoading;
        vars.loadingArtworkFlowKnown = true;
        bool unknown = false;
        if (afm != 0) try {
            foreach (long target in (long[])vars.artworkTargets((long)vars.ptr(afm + 0x40))) vars.artworkController(target, 0);
            long runner = vars.ptr(afm + 0x68);
            if (runner != 0) foreach (long task in (long[])vars.artworkList((long)vars.ptr(runner + 0x10))) vars.artworkTask(task, 0);
        } catch { unknown = true; }
        // This persistent variable listener exists throughout entry/opaque/exit,
        // including cold attachment after onEndLoadState removed its controller.
        try {
            foreach (long holder in (long[])vars.artworkRegistry(0x3F244C0L, "ScrVar_GameManagement_MainCamera"))
                foreach (long target in (long[])vars.artworkTargets((long)vars.ptr(holder + 0x18))) vars.artworkLearnManager(target, 0L);
        } catch { unknown = true; }
        bool visible = false;
        foreach (long manager in ((Dictionary<long, long[]>)vars.artworkBindings).Keys.ToArray()) {
            long[] row = vars.artworkBindings[manager];
            try {
                if (vars.ptr(manager) != row[0] || vars.ptr(manager + 0x10) != row[1] || vars.ptr(row[2]) != row[3]
                    || vars.ptr(row[2] + 0x10) != row[4] || row[4] == 0) { vars.artworkBindings.Remove(manager); continue; }
                if (vars.ptr(manager + 0x30) != row[2]) throw new Exception("Artwork camera changed");
                if (vars.ptr(row[5]) != row[6] || vars.ptr(row[5] + 0x60) != row[7]
                    || (string)vars.artworkNativeName(row[5]) != "ScreenContent") throw new Exception("Artwork GameObject changed");
                byte enabled = vars.read(row[4] + 0x38, 1)[0];
                byte self = vars.read(row[5] + 0x56, 1)[0];
                if (enabled > 1 || self > 1) throw new Exception("Invalid artwork visibility");
                if (enabled == 0 || self == 0) continue;
                byte hierarchy = vars.read(row[5] + 0x57, 1)[0];
                if (hierarchy > 1) throw new Exception("Artwork hierarchy visibility is unresolved");
                long cameraGO = vars.ptr(row[4] + 0x30);
                byte cameraHierarchy = vars.read(cameraGO + 0x57, 1)[0];
                if (cameraHierarchy > 1) throw new Exception("Artwork camera hierarchy is unresolved");
                if (vars.ptr(manager + 0x10) != row[1] || vars.ptr(row[2] + 0x10) != row[4]
                    || enabled != vars.read(row[4] + 0x38, 1)[0] || self != vars.read(row[5] + 0x56, 1)[0]
                    || hierarchy != vars.read(row[5] + 0x57, 1)[0] || cameraGO != vars.ptr(row[4] + 0x30)
                    || cameraHierarchy != vars.read(cameraGO + 0x57, 1)[0]) throw new Exception("Artwork visibility changed during sample");
                if (hierarchy == 1 && cameraHierarchy == 1) visible = true;
            } catch { if (!scenePresent) vars.artworkBindings.Remove(manager); else unknown = true; }
        }
        if (visible) return true;
        if (unknown && scenePresent) throw new Exception("Loading artwork sample is unstable");
        return false;
    });
    // Compatibility alias for the existing room-icon OR artwork wrapper. No fallback.
    vars.fullLoadingScreenSnapshot = (Func<bool?>)(() => (bool)vars.loadingArtworkSnapshot());

    // Final-form reader: null means no encounter; exceptions mark an unstable sample.
    // Samples contain entity, current StatObject, context, effective HP and max HP.
    vars.draculaClassNames = new Dictionary<long, string>();
    vars.draculaComponentHandles = new Dictionary<long, long[]>();
    vars.draculaComponentContext = 0L;
    vars.draculaClassName = (Func<long, string>)(obj => {
        long klass = vars.ptr(obj);
        string name;
        if (!vars.draculaClassNames.TryGetValue(klass, out name))
        {
            name = vars.nativeName(vars.ptr(klass + 0x10));
            string space = vars.nativeName(vars.ptr(klass + 0x18));
            if (space != "") name = space + "." + name;
            vars.draculaClassNames.Add(klass, name);
        }
        return name;
    });
    vars.draculaComponents = (Func<long, long[]>)(entity => {
        long native = vars.ptr(entity + 0x10), context = vars.ptr(entity + 0x28);
        if (context != (long)vars.draculaComponentContext)
        {
            vars.draculaComponentHandles.Clear();
            vars.draculaComponentContext = context;
        }
        long cache = vars.ptr(entity + 0x30);
        long entries = vars.ptr(cache + 0x18);
        int count = vars.i32(cache + 0x20), sampleVersion = vars.i32(cache + 0x2C);
        if (count < 0 || count > 2048 || count > vars.i32(entries + 0x18))
            throw new Exception("Invalid final-boss component cache");
        long[] found;
        if (vars.draculaComponentHandles.TryGetValue(entity, out found)
            && found[4] == cache && found[5] == entries && found[6] == count && found[7] == sampleVersion
            && found[8] == native && found[9] == context)
            return found;
        byte[] data = vars.read(entries + 0x20, count * 0x18);
        found = new long[] { 0, 0, 0, 0, cache, entries, count, sampleVersion, native, context };
        for (int i = 0; i < count; i++)
        {
            if (BitConverter.ToInt32(data, i * 0x18) < 0) continue;
            long component = BitConverter.ToInt64(data, i * 0x18 + 0x10);
            if (component < 0x10000) { found[3] = 1; continue; }
            string name;
            try { name = vars.draculaClassName(component); }
            catch { found[3] = 1; continue; }
            if (name == "DraculaBeastState") found[0] = component;
            else if (name == "Damageable") found[1] = component;
            else if (name == "MobComponent") found[2] = component;
        }
        if (entries != (long)vars.ptr(cache + 0x18)
            || count != (int)vars.i32(cache + 0x20)
            || sampleVersion != (int)vars.i32(cache + 0x2C)
            || native != (long)vars.ptr(entity + 0x10) || context != (long)vars.ptr(entity + 0x28))
            throw new Exception("Final-boss component cache changed");
        if (found[0] != 0 && found[1] != 0 && found[2] != 0)
        {
            found[3] = 0;
            vars.draculaComponentHandles[entity] = found;
        }
        // Dracula can be selected for the whole run. Reuse fully classified
        // non-boss dictionaries instead of rereading all their components at
        // every poll. Unknown entries are retried; version/identity changes
        // invalidate the classification, and context changes clear the cache.
        else if (found[3] == 0 && native != 0 && context != 0)
            vars.draculaComponentHandles[entity] = found;
        return found;
    });
    vars.draculaStatValue = (Func<long, long, float>)((reference, entity) => {
        if (reference < 0x10000 || vars.ptr(reference + 0x20) != entity)
            throw new Exception("Invalid final-boss health reference");
        long stat = vars.ptr(reference + 0x18);
        if (stat < 0x10000 || (string)vars.draculaClassName(stat) != "StatObject")
            throw new Exception("Invalid final-boss health stat");
        long modifiers = vars.ptr(stat + 0x20);
        int count = vars.i32(modifiers + 0x18), sampleVersion = vars.i32(modifiers + 0x1C);
        // Final Beast's actual current/max/min stats have no modifiers. An unknown
        // modifier must not silently convert a base value into an effective value.
        if (count != 0) throw new Exception("Unsupported final-boss health modifier");
        float value = BitConverter.ToSingle(vars.read(stat + 0x18, 4), 0);
        if (float.IsNaN(value) || float.IsInfinity(value)
            || value < int.MinValue || value >= (double)int.MaxValue)
            throw new Exception("Invalid final-boss stat value");
        if (stat != (long)vars.ptr(reference + 0x18)
            || entity != (long)vars.ptr(reference + 0x20)
            || modifiers != (long)vars.ptr(stat + 0x20)
            || count != (int)vars.i32(modifiers + 0x18)
            || sampleVersion != (int)vars.i32(modifiers + 0x1C))
            throw new Exception("Final-boss health reference changed");
        // StatObject.GetInt uses the same ties-to-even rounding as Mathf.RoundToInt.
        return (float)Math.Round((double)value, MidpointRounding.ToEven);
    });
    vars.draculaSnapshot = (Func<object[]>)(() => {
        long type = vars.ptr((long)vars.baseAddress + 0x3F23D78);
        long manager = vars.ptr(vars.ptr(type + 0xB8));
        long context = vars.ptr(manager + 0x28);
        if (context < 0x10000) throw new Exception("No boss entity context");
        Func<long, bool, object[]> sample = (entity, cached) => {
            if (entity < 0x10000 || vars.ptr(entity + 0x28) != context) return null;
            if (!cached && vars.ptr(entity + 0x10) == 0) return null;
            if ((string)vars.draculaClassName(entity) != "MotherBase.EntityFramework.Entity") return null;
            long[] components = vars.draculaComponents(entity);
            long beast = components[0], damageable = components[1], mobComponent = components[2];
            if (beast == 0 || damageable == 0 || mobComponent == 0)
            {
                if (components[3] != 0) throw new Exception("Incomplete boss component identities");
                return null;
            }
            if ((string)vars.draculaClassName(beast) != "DraculaBeastState"
                || (string)vars.draculaClassName(damageable) != "Damageable"
                || (string)vars.draculaClassName(mobComponent) != "MobComponent")
                throw new Exception("Cached final-boss components changed class");
            if (vars.ptr(damageable + 0x48) != entity) return null;
            long mob = vars.ptr(mobComponent + 0x20);
            long id = vars.ptr(mob + 0x18);
            int length = vars.i32(id + 0x10);
            if (length != 12 || Encoding.Unicode.GetString(vars.read(id + 0x14, 24)) != "DraculaBeast")
                return null;
            long currentRef = vars.ptr(damageable + 0x20), maxRef = vars.ptr(damageable + 0x28);
            long minRef = vars.ptr(damageable + 0x30);
            if (vars.ptr(damageable + 0x38) != 0 || vars.ptr(damageable + 0x40) != 0)
                throw new Exception("Unsupported final-boss health clamp reference");
            long stat = vars.ptr(currentRef + 0x18);
            float health = vars.draculaStatValue(currentRef, entity);
            float maximum = vars.draculaStatValue(maxRef, entity);
            float minimum = minRef == 0 ? 0.0f : (float)vars.draculaStatValue(minRef, entity);
            float rawHealth = health;
            // Beast grab moves can temporarily set HealthMin to1. The displayed
            // Damageable.currentHealth is max(current stat, minimum stat).
            health = Math.Max(health, minimum);
            if (health == 0)
            {
                // Health and its temporary minimum can change in the same action.
                // A second numeric sample rejects a mixture of two different states.
                float currentCheck = vars.draculaStatValue(currentRef, entity);
                float maximumCheck = vars.draculaStatValue(maxRef, entity);
                float minimumCheck = minRef == 0 ? 0.0f : (float)vars.draculaStatValue(minRef, entity);
                if (currentCheck != rawHealth || maximumCheck != maximum || minimumCheck != minimum)
                    throw new Exception("Final-boss health values changed during zero sample");
            }
            byte[] flags = vars.read(entity + 0x20, 2);
            if (flags[0] > 1 || flags[1] > 1) throw new Exception("Invalid final-boss entity flags");
            bool enabled = flags[0] == 0 && flags[1] == 1 && vars.ptr(entity + 0x10) != 0;
            // Die may remove the entity from enabled sets before our next30Hz poll.
            // A cached actual0 with onDieActionStarted still represents the hit.
            if (!enabled)
            {
                if (!cached || health != 0) return null;
                byte deathStarted = vars.read(damageable + 0x58, 1)[0];
                if (deathStarted != 1)
                    throw new Exception("Waiting for cached zero-health death state");
            }
            if (context != (long)vars.ptr(manager + 0x28)
                || context != (long)vars.ptr(entity + 0x28)
                || components[4] != (long)vars.ptr(entity + 0x30)
                || components[5] != (long)vars.ptr(components[4] + 0x18)
                || components[6] != (int)vars.i32(components[4] + 0x20)
                || components[7] != (int)vars.i32(components[4] + 0x2C)
                || entity != (long)vars.ptr(damageable + 0x48)
                || mob != (long)vars.ptr(mobComponent + 0x20)
                || currentRef != (long)vars.ptr(damageable + 0x20)
                || maxRef != (long)vars.ptr(damageable + 0x28)
                || minRef != (long)vars.ptr(damageable + 0x30)
                || stat != (long)vars.ptr(currentRef + 0x18))
                throw new Exception("Final-boss identity changed during health sample");
            return new object[] { entity, stat, context, health, maximum };
        };
        long previous = vars.draculaEntity;
        if (previous >= 0x10000)
        {
            object[] cached = sample(previous, true);
            if (cached != null) return cached;
        }
        long set = vars.ptr(context + 0x38);
        long slots = vars.ptr(set + 0x18);
        int count = vars.i32(set + 0x20), last = vars.i32(set + 0x24), sampleVersion = vars.i32(set + 0x38);
        if (last < 0 || last > 8192 || count < 0 || count > last || last > vars.i32(slots + 0x18))
            throw new Exception("Invalid enabled boss entity set");
        byte[] entities = vars.read(slots + 0x20, last * 0x10);
        object[] result = null;
        bool unknown = false;
        for (int i = 0; i < last; i++)
        {
            if (BitConverter.ToInt32(entities, i * 0x10) < 0) continue;
            long entity = BitConverter.ToInt64(entities, i * 0x10 + 8);
            if (entity < 0x10000) continue;
            object[] candidate;
            try { candidate = sample(entity, false); }
            catch { unknown = true; continue; }
            if (candidate == null) continue;
            if (result != null) throw new Exception("Multiple final Dracula entities");
            result = candidate;
        }
        if (context != (long)vars.ptr(manager + 0x28)
            || set != (long)vars.ptr(context + 0x38)
            || slots != (long)vars.ptr(set + 0x18)
            || count != (int)vars.i32(set + 0x20)
            || last != (int)vars.i32(set + 0x24)
            || sampleVersion != (int)vars.i32(set + 0x38))
            throw new Exception("Enabled boss entity set changed during search");
        if (result == null && unknown) throw new Exception("Some enabled entity identities are unavailable");
        return result;
    });
    vars.gameplayState = (Func<long, bool>)(manager => {
        long initial = vars.ptr(manager + 0x20);
        long stack = vars.ptr(manager + 0xA0);
        if (initial == 0 || stack == 0) return false;
        int count = vars.i32(stack + 0x18);
        if (count < 0 || count > 128) throw new Exception("Invalid gameplay state stack");
        if (count == 0) return false;
        long items = vars.ptr(stack + 0x10);
        if (count > vars.i32(items + 0x18)) throw new Exception("Incomplete gameplay state stack");
        long top = vars.ptr(items + 0x20 + (count - 1) * 8);
        return top != 0 && vars.ptr(top + 0x18) == initial;
    });
    vars.movementSnapshot = (Func<bool>)(() => {
        long gameType = vars.ptr((long)vars.baseAddress + 0x3F23D78);
        long manager = vars.ptr(vars.ptr(gameType + 0xB8));
        long mc = vars.ptr(manager + 0xB0);
        if (mc < 0x10000) return false;
        long context = vars.ptr(mc + 0x28);
        Func<bool> controlsReady = () =>
            mc == (long)vars.ptr(manager + 0xB0)
            && vars.read(mc + 0x20, 1)[0] == 0
            && vars.read(mc + 0x21, 1)[0] == 1
            && context != 0 && context == (long)vars.ptr(mc + 0x28)
            && vars.read(context + 0x68, 1)[0] == 0
            && vars.read(manager + 0xB8, 1)[0] == 0
            && (bool)vars.gameplayState(manager);
        if (!controlsReady()) return false;

        long cache = vars.ptr(mc + 0x30);
        long entries = vars.ptr(cache + 0x18);
        int count = vars.i32(cache + 0x20);
        int cacheVersion = vars.i32(cache + 0x2C);
        if (count < 0 || count > 2048 || count > vars.i32(entries + 0x18))
            throw new Exception("Invalid input component dictionary");
        if (mc != (long)vars.inputEntity || cache != (long)vars.inputCache
            || entries != (long)vars.inputEntries || cacheVersion != (int)vars.inputVersion)
        {
            // The ECS cache retains removed objects. Discover their runtime
            // bit indices, then use the ACTIVE component mask for input gates.
            // A type absent from the dictionary cannot currently be active.
            string[] names = { "PlayerInput", "DisableInput", "OutOfTime" };
            int[] hashes = new int[3];
            bool[] found = new bool[3];
            long input = 0L, inputClass = 0L;
            byte[] components = vars.read(entries + 0x20, count * 0x18);
            for (int i = 0; i < count; i++)
            {
                if (BitConverter.ToInt32(components, i * 0x18) < 0) continue;
                long candidate = BitConverter.ToInt64(components, i * 0x18 + 0x10);
                if (candidate < 0x10000) continue;
                long klass = vars.ptr(candidate);
                string name = vars.nativeName(vars.ptr(klass + 0x10));
                int slot = Array.IndexOf(names, name);
                if (slot < 0 || (string)vars.nativeName(vars.ptr(klass + 0x18)) != "MotherBase.ActionFramework")
                    continue;
                hashes[slot] = BitConverter.ToInt32(components, i * 0x18 + 8);
                found[slot] = true;
                if (slot == 0) { input = candidate; inputClass = klass; }
            }
            if (input == 0) return false;

            // ComponentsIndexCache assigns these indices at runtime; none of
            // the component indices observed in one session are hardcoded.
            long indexType = vars.ptr((long)vars.baseAddress + 0x3F7EC38);
            long indexCache = vars.ptr(vars.ptr(indexType + 0xB8));
            long indexMap = vars.ptr(indexCache + 0x10);
            long indexEntries = vars.ptr(indexMap + 0x18);
            int indexCount = vars.i32(indexMap + 0x20);
            int indexVersion = vars.i32(indexMap + 0x2C);
            if (indexCount < 0 || indexCount > 2048 || indexCount > vars.i32(indexEntries + 0x18))
                throw new Exception("Invalid component index dictionary");
            byte[] indices = vars.read(indexEntries + 0x20, indexCount * 0x10);
            int[] bits = { -1, -1, -1 };
            for (int i = 0; i < indexCount; i++)
            {
                if (BitConverter.ToInt32(indices, i * 0x10) < 0) continue;
                int componentHash = BitConverter.ToInt32(indices, i * 0x10 + 8);
                int bit = BitConverter.ToInt32(indices, i * 0x10 + 0xC);
                if (bit < 0 || bit >= 2048) throw new Exception("Invalid component bit index");
                for (int slot = 0; slot < 3; slot++)
                    if (found[slot] && componentHash == hashes[slot]) bits[slot] = bit;
            }
            for (int slot = 0; slot < 3; slot++)
                if (found[slot] && bits[slot] < 0) throw new Exception("Input component index is not ready");
            if (indexEntries != (long)vars.ptr(indexMap + 0x18)
                || indexCount != (int)vars.i32(indexMap + 0x20)
                || indexVersion != (int)vars.i32(indexMap + 0x2C)
                || entries != (long)vars.ptr(cache + 0x18)
                || count != (int)vars.i32(cache + 0x20)
                || cacheVersion != (int)vars.i32(cache + 0x2C))
                throw new Exception("Input component dictionaries changed during sample");
            vars.inputEntity = mc;
            vars.inputCache = cache;
            vars.inputEntries = entries;
            vars.inputVersion = cacheVersion;
            vars.inputComponent = input;
            vars.inputClass = inputClass;
            vars.inputIndices = bits;
        }
        long playerInput = vars.inputComponent;
        if (vars.ptr(playerInput) != (long)vars.inputClass || vars.ptr(playerInput + 0x10) == 0
            || vars.read(playerInput + 0x70, 1)[0] != 1) return false;
        // Unity's processed movement action is shared by keyboard and gamepad.
        // Position/MoveIntent can change during scripted movement, so are not used.
        byte[] axes = vars.read(playerInput + 0x54, 8);
        float x = BitConverter.ToSingle(axes, 0), y = BitConverter.ToSingle(axes, 4);
        if (float.IsNaN(x) || float.IsInfinity(x) || float.IsNaN(y) || float.IsInfinity(y)
            || (x == 0 && y == 0)) return false;
        byte[] mask = vars.read(mc + 0xC8, 256);
        int[] activeBits = vars.inputIndices;
        Func<int, bool> has = slot => activeBits[slot] >= 0
            && (BitConverter.ToUInt64(mask, (activeBits[slot] / 64) * 8)
                & (1UL << (activeBits[slot] % 64))) != 0;
        if (!has(0) || has(1) || has(2)) return false;
        if (entries != (long)vars.ptr(cache + 0x18)
            || cacheVersion != (int)vars.i32(cache + 0x2C)
            || vars.read(playerInput + 0x70, 1)[0] != 1 || !controlsReady())
            throw new Exception("Gameplay input changed during sample");
        return true;
    });
}

update
{
    vars.draculaValid = false;
    vars.clearTrigger();
    vars.startRequested = false;
    vars.valid = false;
    if (!vars.supported) return false;
    // Read the runtime settings here rather than capturing startup's settings
    // builder in a delegate. Progression is observed even for unchecked events.
    var enabled = new HashSet<string>();
    if ((bool)settings["bosses"])
        foreach (string key in ((Dictionary<string, string>)vars.checkNames).Keys)
            if ((bool)settings["boss_" + key]) enabled.Add(key);
    vars.enabledChecks = enabled;
    if (!Object.ReferenceEquals((object)vars.observedRun, (object)timer.Run))
    {
        vars.observedRun = (object)timer.Run;
        vars.seenChecks.Clear();
        vars.baselineNeeded = true;
        vars.invalidateSegment();
    }
    int currentIndex = timer.CurrentSplitIndex;
    object currentSegment = timer.Run != null && currentIndex >= 0 && currentIndex < timer.Run.Count
        ? (object)timer.Run[currentIndex] : null;
    if (currentIndex != (int)vars.sampleIndex
        || !Object.ReferenceEquals(currentSegment, (object)vars.sampleSegment))
        vars.invalidateSegment();
    vars.sampleRun = (object)timer.Run;
    vars.sampleIndex = currentIndex;
    vars.sampleSegment = currentSegment;
    vars.sampleRevision = (int)vars.segmentRevision;
    // Loading screens can replace or temporarily remove the player entity.
    // Read their state before the player; retain the last sample on a transient
    // read failure instead of treating missing player data as a loading screen.
    bool previousLoading = vars.loading;
    bool previousLoadingValid = vars.loadingValid;
    bool previousLoadingFlow = vars.loadingArtworkFlowActive;
    bool previousLoadingFlowKnown = vars.loadingArtworkFlowKnown;
    try
    {
        vars.loading = (bool)vars.loadingSnapshot();
        vars.loadingValid = true;
    }
    catch
    {
        vars.loadingValid = false;
    }
    // Loaded saves can populate progression after the new player first appears.
    // The bat-curtain tail counts on the clock, but save flags can still be
    // restored there. Keep progression baselining separate from timing removal.
    if (vars.loading || !vars.loadingValid || previousLoading || !previousLoadingValid
        || vars.loadingArtworkFlowActive || !vars.loadingArtworkFlowKnown
        || previousLoadingFlow || !previousLoadingFlowKnown)
        vars.baselineNeeded = true;
    // Save creation happens before an MC entity is available. Observe it
    // independently, including while an attempt is running or already ended.
    bool saveValid = false;
    try
    {
        object[] saveSample = vars.saveSnapshot();
        long saveObject = (long)saveSample[0];
        bool fresh = (bool)saveSample[1];
        if (saveObject != (long)vars.lastSaveObject)
        {
            vars.baselineNeeded = true;
            vars.resetDracula();
        }
        if (saveObject != (long)vars.armedSaveObject || timer.CurrentPhase != TimerPhase.NotRunning)
        {
            vars.startArmed = false;
            vars.armedSaveObject = 0L;
        }
        if (vars.saveBaselineReady)
        {
            if (saveObject != 0 && saveObject != (long)vars.lastSaveObject && fresh
                && timer.CurrentPhase == TimerPhase.NotRunning)
            {
                vars.startArmed = true;
                vars.armedSaveObject = saveObject;
                print("New save created: waiting for first movement input");
            }
        }
        else vars.saveBaselineReady = true;
        vars.lastSaveObject = saveObject;
        saveValid = true;
        vars.saveStatus = vars.startArmed ? "Waiting for first gameplay movement" : "Current save observed";
    }
    catch
    {
        vars.baselineNeeded = true;
        vars.saveStatus = "Waiting for stable save data";
    }
    // The same new save can acquire its persistent ID before control returns.
    // Preserve its arm, but require a valid identity and loading sample to start.
    if (saveValid && vars.startArmed && vars.loadingValid && !vars.loading
        && timer.CurrentPhase == TimerPhase.NotRunning)
    {
        try
        {
            if ((bool)vars.movementSnapshot())
            {
                object[] confirmation = vars.saveSnapshot();
                vars.startRequested = (long)confirmation[0] == (long)vars.armedSaveObject
                    && !(bool)vars.loadingSnapshot();
            }
        }
        catch { vars.saveStatus = "Waiting for stable gameplay input"; }
    }
    // Final Dracula uses an independent health edge. Player progression can
    // disappear during death/cutscenes and must not delay or suppress this split.
    // The HP detector follows its checkbox on every row. An initial zero still
    // cannot replay a past kill; deselecting the event breaks HP continuity.
    if (!enabled.Contains("dracula") || currentSegment == null
        || timer.CurrentPhase != TimerPhase.Running || !saveValid
        || !vars.loadingValid || vars.loading || vars.loadingArtworkFlowActive
        || !vars.loadingArtworkFlowKnown || vars.seenChecks.Contains("dracula"))
        vars.resetDracula();
    else
    {
        if (previousLoading || !previousLoadingValid || previousLoadingFlow || !previousLoadingFlowKnown)
            vars.resetDracula();
        try
        {
            object[] sample = vars.draculaSnapshot();
            if (sample == null) vars.resetDracula();
            else
            {
                long entity = (long)sample[0], healthStat = (long)sample[1], context = (long)sample[2];
                float health = (float)sample[3], maximum = (float)sample[4];
                if (entity < 0x10000 || healthStat < 0x10000 || context < 0x10000
                    || float.IsNaN(health) || float.IsInfinity(health) || health < 0
                    || float.IsNaN(maximum) || float.IsInfinity(maximum) || maximum <= 0)
                    throw new Exception("Invalid final Dracula health sample");
                object[] confirmation = vars.saveSnapshot();
                if ((long)confirmation[0] != (long)vars.lastSaveObject)
                    throw new Exception("Save changed during Dracula health sample");
                bool sameEncounter = entity == (long)vars.draculaEntity
                    && healthStat == (long)vars.draculaStat && context == (long)vars.draculaContext
                    && (long)vars.lastSaveObject == (long)vars.draculaSave;
                if (sameEncounter && vars.draculaPositive && health == 0)
                {
                    // Recheck loading at the killing hit, not a later defeat flag.
                    if ((bool)vars.loadingSnapshot() || vars.loadingArtworkFlowActive
                        || !vars.loadingArtworkFlowKnown) vars.resetDracula();
                    else vars.emitCheck("dracula");
                }
                vars.draculaEntity = entity;
                vars.draculaStat = healthStat;
                vars.draculaContext = context;
                vars.draculaSave = (long)vars.lastSaveObject;
                vars.draculaPositive = health > 0;
                vars.draculaHealth = health;
                vars.draculaMaximum = maximum;
                vars.draculaValid = true;
                vars.draculaStatus = "Reading final Dracula health";
            }
        }
        catch
        {
            vars.resetDracula();
            vars.draculaStatus = "Waiting for stable final Dracula health";
        }
    }
    try
    {
        // GameStateManager_TypeInfo -> static_fields -> instance -> MC entity.
        long klass = vars.ptr((long)vars.baseAddress + 0x3F23D78);
        long manager = vars.ptr(vars.ptr(klass + 0xB8));
        long mc = vars.ptr(manager + 0xB0);
        if (mc < 0x10000 || vars.read(mc + 0x20, 1)[0] != 0)
            throw new Exception("No active player entity");
        if (mc != (long)vars.mc)
        {
            vars.mc = mc;
            vars.component = 0L;
            vars.baselineNeeded = true;
        }

        long component = vars.component;
        if (component == 0 || vars.ptr(component) != (long)vars.componentClass || vars.ptr(component + 0x10) == 0)
        {
            // Entity.componentCache is Dictionary<int, Component>. Discover by
            // managed type, since dictionary entry indices can vary by scene.
            long cache = vars.ptr(mc + 0x30);
            long entries = vars.ptr(cache + 0x18);
            int count = vars.i32(cache + 0x20);
            if (count < 1 || count > 2048 || count > vars.i32(entries + 0x18))
                throw new Exception("Invalid component dictionary");
            byte[] bytes = vars.read(entries + 0x20, count * 0x18);
            component = 0;
            for (int i = 0; i < count; i++)
            {
                if (BitConverter.ToInt32(bytes, i * 0x18) < 0) continue;
                long candidate = BitConverter.ToInt64(bytes, i * 0x18 + 0x10);
                if (candidate < 0x10000) continue;
                long type = vars.ptr(candidate);
                long name = vars.ptr(type + 0x10);
                byte[] text = vars.read(name, 32);
                int end = Array.IndexOf(text, (byte)0);
                if (end >= 0 && Encoding.ASCII.GetString(text, 0, end) == "ProgressionComponent")
                {
                    component = candidate;
                    vars.componentClass = type;
                    break;
                }
            }
            if (component == 0) throw new Exception("Player progression component is not ready");
            vars.component = component;
            vars.baselineNeeded = true;
        }

        long list = vars.ptr(component + 0x28);
        long items = vars.ptr(list + 0x10);
        int size = vars.i32(list + 0x18);
        int listVersion = vars.i32(list + 0x1C);
        if (size < 0 || size > 8192 || size > vars.i32(items + 0x18))
            throw new Exception("Invalid progression list");
        byte[] pointers = vars.read(items + 0x20, size * 8);
        var flags = new HashSet<string>();
        for (int i = 0; i < size; i++)
        {
            long key = BitConverter.ToInt64(pointers, i * 8);
            string guid = vars.guid(vars.ptr(key + 0x18));
            string check;
            if (vars.flagChecks.TryGetValue(guid, out check)) flags.Add(check);
        }
        // Reject a sample if the game changed the list while we read it.
        if (list != vars.ptr(component + 0x28) || items != vars.ptr(list + 0x10)
            || size != vars.i32(list + 0x18) || listVersion != vars.i32(list + 0x1C)
            || mc != vars.ptr(manager + 0xB0))
            throw new Exception("Player progression changed during sample");

        HashSet<string> previous = vars.flags;
        vars.flags = flags;
        vars.valid = true;
        vars.status = "Reading live check events";
        if (vars.baselineNeeded || !previous.IsSubsetOf(flags))
        {
            // Attach, player replacement, failed reads and save rollback must
            // establish a baseline instead of replaying completed bosses.
            foreach (string check in flags) vars.seenChecks.Add(check);
            // Keep waiting through a save-read gap; restored flags may arrive
            // on the first poll that can identify that save again.
            vars.baselineNeeded = !saveValid;
            return;
        }
        foreach (string check in flags)
            if (!previous.Contains(check)) vars.emitCheck(check);
    }
    catch
    {
        vars.baselineNeeded = true;
        vars.component = 0L;
        vars.status = "Waiting for stable player data";
        // Continue the independent loading clock and new-save detector even
        // when the player is absent. No progression edge is emitted here.
        return true;
    }
}

isLoading
{
    return (bool)vars.loading;
}

start
{
    if (!vars.supported || !vars.startRequested || timer.CurrentPhase != TimerPhase.NotRunning)
        return false;
    // Consume this event even if LiveSplit's Starting checkbox is disabled.
    vars.startRequested = false;
    vars.startArmed = false;
    vars.armedSaveObject = 0L;
    print("First gameplay movement input detected");
    return true;
}

split
{
    int index = timer.CurrentSplitIndex;
    string check = vars.triggerCheck;
    if (timer.CurrentPhase != TimerPhase.Running || timer.Run == null || check == null
        || index < 0 || index >= timer.Run.Count || index != (int)vars.triggerIndex
        || !Object.ReferenceEquals((object)timer.Run, (object)vars.triggerRun)
        || !Object.ReferenceEquals((object)timer.Run[index], (object)vars.triggerSegment)
        || !(bool)settings["bosses"] || !(bool)settings["boss_" + check]) return false;
    vars.clearTrigger();
    print(check == "dracula" ? "Final Dracula HP reached zero" : "Boss defeated: " + vars.checkNames[check]);
    return true;
}

onSplit
{
    vars.invalidateSegment();
}

onStart
{
    vars.resetDracula();
    timer.CurrentTimingMethod = TimingMethod.GameTime;
    vars.startRequested = false;
    vars.startArmed = false;
    vars.armedSaveObject = 0L;
    vars.seenChecks.Clear();
    vars.invalidateSegment();
    vars.baselineNeeded = true;
}

onReset
{
    vars.resetDracula();
    vars.startRequested = false;
    vars.startArmed = false;
    vars.armedSaveObject = 0L;
    vars.seenChecks.Clear();
    vars.invalidateSegment();
    vars.baselineNeeded = true;
}

exit
{
    vars.resetDracula();
    vars.loading = false;
    vars.loadingValid = false;
    timer.IsGameTimePaused = false;
    vars.startRequested = false;
    vars.startArmed = false;
    vars.armedSaveObject = 0L;
    vars.saveBaselineReady = false;
    vars.valid = false;
    vars.baselineNeeded = true;
    vars.component = 0L;
    vars.invalidateSegment();
    vars.status = "Waiting for the game";
}

shutdown
{
    timer.OnSkipSplit -= vars.segmentChanged;
    timer.OnUndoSplit -= vars.segmentChanged;
    timer.IsGameTimePaused = false;
}
