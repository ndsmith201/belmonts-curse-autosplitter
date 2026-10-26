// Castlevania: Belmont's Curse -- ten-boss route, Windows Steam build 1.1.3.
// Reads live progression flags; does not write to the game or save files.
// A new save arms auto-start; the first accepted movement input starts timing.
// Reset manually between attempts.
// Use the accompanying ten-segment .lss file and enable Starting in the layout.
// Game Time removes loading screens; Real Time is also recorded by LiveSplit.
// GameAssembly.dll SHA256: 4904978ba2c15884185cfaea8d348dfb8ffe69d466fafed1f46fb963a7276152
// Defeat GUIDs were extracted from this installed build's actual assets.

state("Castlevania Belmont's Curse") {}

startup
{
    refreshRate = 30;
    vars.names = new string[] {
        "The Fallen", "Joan", "Medusa", "Death 1", "Isaac 1",
        "Talos", "Carmilla", "Death 2", "Isaac 2", "Dracula"
    };
    vars.ids = new string[] {
        "20c378a72ad9c664686476a360b99777", // Leon / The Fallen
        "641325fec3360bb459c879275fdee639", // Jeanne
        "ac985fb3574b3cc4eadaf3a79793112e", // Medusa
        "769b38ad62fa14249b54a74ef889998c", // DeathCatacombs
        "99cd7d3d4e286c84da47e29d2fbb7e83", // IsaacIntro
        "3c8796f7f58e2634eb4bcc8fe8a49746", // Talos
        "4a7b39e0c582899409003620d44f5712", // Carmilla
        "c94c4e1cc1f8dbf4fb525f2c6b94920c", // Death
        "e47322c821f3eda4999f654f86dad494", // Isaac
        "402628a8ae258e240a8fe5feca62e65d"  // DraculaBeast -- final form
    };
    vars.idBits = new Dictionary<string, int>();
    for (int i = 0; i < 10; i++) vars.idBits.Add(vars.ids[i], 1 << i);
    vars.mask = 0;
    vars.valid = false;
    vars.supported = false;
    vars.baselineNeeded = true;
    vars.firedMask = 0;
    vars.trigger = -1;
    vars.startRequested = false;
    vars.startArmed = false;
    vars.armedSaveObject = 0L;
    vars.saveBaselineReady = false;
    vars.lastSaveObject = 0L;
    vars.loading = false;
    vars.loadingValid = false;
    timer.CurrentTimingMethod = TimingMethod.GameTime;
    vars.saveStatus = "Waiting to observe the current save";
    vars.status = "Waiting for the game";
}

init
{
    vars.valid = false;
    vars.baselineNeeded = true;
    vars.trigger = -1;
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
        try
        {
        // AFM begins loading before the next scene/player is ready.
        long afmType = vars.ptr((long)vars.baseAddress + 0x3F5F570);
        if (afmType >= 0x10000 && (afmType & 7) == 0)
        {
            long fields = vars.ptr(afmType + 0xB8);
            if (fields != 0 && vars.loadingFlag(fields)) return true;
        }
        }
        catch { unknown = true; }
        try
        {
        // The game's loading state lasts through the final reveal, after
        // AFM.IsLoading clears. Verified against two live fast travels.
        long gameType = vars.ptr((long)vars.baseAddress + 0x3F23D78);
        if (gameType >= 0x10000 && (gameType & 7) == 0)
        {
            long fields = vars.ptr(gameType + 0xB8);
            long manager = fields == 0 ? 0L : (long)vars.ptr(fields);
            if (manager != 0)
            {
                long loadingState = vars.ptr(manager + 0x68);
                long states = vars.ptr(manager + 0xA0);
                if (states != 0 && loadingState != 0)
                {
                    int count = vars.i32(states + 0x18);
                    if (count < 0 || count > 128) throw new Exception("Invalid game state stack");
                    if (count > 0)
                    {
                        long items = vars.ptr(states + 0x10);
                        if (count > vars.i32(items + 0x18)) throw new Exception("Incomplete game state stack");
                        long top = vars.ptr(items + 0x20 + (count - 1) * 8);
                        if (top != 0 && vars.ptr(top + 0x18) == loadingState) return true;
                    }
                }
            }
        }
        }
        catch { unknown = true; }
        // Room transitions have a separate visible loading icon. The engine's
        // background room-prefetch flag is deliberately not used here.
        try { if ((bool)vars.roomLoadingVisible(0x3F082C8L)) return true; }
        catch { unknown = true; }
        try { if ((bool)vars.roomLoadingVisible(0x3F08390L)) return true; }
        catch { unknown = true; }
        if (unknown) throw new Exception("Loading screen data is temporarily unavailable");
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
        int cacheVersion = vars.i32(cache + 0x24);
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
            int indexVersion = vars.i32(indexMap + 0x24);
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
                || indexVersion != (int)vars.i32(indexMap + 0x24)
                || entries != (long)vars.ptr(cache + 0x18)
                || count != (int)vars.i32(cache + 0x20)
                || cacheVersion != (int)vars.i32(cache + 0x24))
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
            || cacheVersion != (int)vars.i32(cache + 0x24)
            || vars.read(playerInput + 0x70, 1)[0] != 1 || !controlsReady())
            throw new Exception("Gameplay input changed during sample");
        return true;
    });
}

update
{
    vars.trigger = -1;
    vars.startRequested = false;
    vars.valid = false;
    if (!vars.supported) return false;
    // Loading screens can replace or temporarily remove the player entity.
    // Read their state before the player; retain the last sample on a transient
    // read failure instead of treating missing player data as a loading screen.
    try
    {
        vars.loading = (bool)vars.loadingSnapshot();
        vars.loadingValid = true;
    }
    catch
    {
        vars.loadingValid = false;
    }
    // Save creation happens before an MC entity is available. Observe it
    // independently, including while an attempt is running or already ended.
    bool saveValid = false;
    try
    {
        object[] saveSample = vars.saveSnapshot();
        long saveObject = (long)saveSample[0];
        bool fresh = (bool)saveSample[1];
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
        int mask = 0;
        for (int i = 0; i < size; i++)
        {
            long key = BitConverter.ToInt64(pointers, i * 8);
            string guid = vars.guid(vars.ptr(key + 0x18));
            int bit;
            if (vars.idBits.TryGetValue(guid, out bit)) mask |= bit;
        }
        // Reject a sample if the game changed the list while we read it.
        if (list != vars.ptr(component + 0x28) || items != vars.ptr(list + 0x10)
            || size != vars.i32(list + 0x18) || listVersion != vars.i32(list + 0x1C)
            || mc != vars.ptr(manager + 0xB0))
            throw new Exception("Player progression changed during sample");

        int previous = vars.mask;
        vars.mask = mask;
        vars.valid = true;
        vars.status = "Reading live boss flags";
        if (vars.baselineNeeded || (previous & ~mask) != 0)
        {
            // Attach, player replacement, failed reads and save rollback must
            // establish a baseline instead of replaying completed bosses.
            vars.baselineNeeded = false;
            return;
        }
        int index = timer.CurrentSplitIndex;
        if (timer.CurrentPhase == TimerPhase.Running && index >= 0 && index < 10)
        {
            int bit = 1 << index;
            if (((mask & ~previous) & bit) != 0 && (((int)vars.firedMask & bit) == 0))
                vars.trigger = index;
        }
    }
    catch
    {
        vars.baselineNeeded = true;
        vars.component = 0L;
        vars.status = "Waiting for stable player data";
        // Continue the independent loading clock and new-save detector even
        // when the player is absent. Split is guarded by vars.valid below.
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
    if (timer.CurrentPhase != TimerPhase.Running || !vars.valid || index < 0 || index >= 10
        || (int)vars.trigger != index) return false;
    vars.firedMask = (int)vars.firedMask | (1 << index);
    vars.trigger = -1;
    print("Boss defeated: " + vars.names[index]);
    return true;
}

onStart
{
    timer.CurrentTimingMethod = TimingMethod.GameTime;
    vars.startRequested = false;
    vars.startArmed = false;
    vars.armedSaveObject = 0L;
    vars.firedMask = 0;
    vars.trigger = -1;
    vars.baselineNeeded = true;
}

onReset
{
    vars.startRequested = false;
    vars.startArmed = false;
    vars.armedSaveObject = 0L;
    vars.firedMask = 0;
    vars.trigger = -1;
    vars.baselineNeeded = true;
}

exit
{
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
    vars.trigger = -1;
    vars.status = "Waiting for the game";
}

shutdown
{
    timer.IsGameTimePaused = false;
}
