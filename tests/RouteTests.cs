// The runner inserts the actual ASL bodies below. These tests never reimplement
// setting selection, event routing, progression edges, or HP edge detection.
using System;
using System.Collections.Generic;
using System.Dynamic;
using System.IO;
using System.Linq;
using System.Text;

public enum TimerPhase { NotRunning, Running, Paused, Ended }
public enum TimingMethod { RealTime, GameTime }
public class Segment
{
    private string name;
    public bool RejectNameReads;
    public string Name
    {
        get { if (RejectNameReads) throw new Exception("Segment names must be cosmetic"); return name; }
        set { name = value; }
    }
    public Segment(string name) { Name = name; }
}
public class Run : List<Segment>
{
    public Run(IEnumerable<string> labels) : base(labels.Select(label => new Segment(label))) { }
}
public class Timer
{
    public Run Run { get; set; }
    public int CurrentSplitIndex { get; set; }
    public TimerPhase CurrentPhase { get; set; }
    public TimingMethod CurrentTimingMethod { get; set; }
    public bool IsGameTimePaused { get; set; }
    public event EventHandler OnSkipSplit;
    public event EventHandler OnUndoSplit;
    public int SkipSubscribers => OnSkipSplit?.GetInvocationList().Length ?? 0;
    public int UndoSubscribers => OnUndoSplit?.GetInvocationList().Length ?? 0;
    // LiveSplit changes its index before raising these native events.
    public void Skip()
    {
        if (CurrentSplitIndex >= Run.Count - 1) throw new Exception("Cannot skip the final segment");
        CurrentSplitIndex++;
        OnSkipSplit?.Invoke(this, EventArgs.Empty);
    }
    public void Undo()
    {
        if (CurrentSplitIndex <= 0) throw new Exception("Cannot undo at the first segment");
        CurrentSplitIndex--;
        if (CurrentPhase == TimerPhase.Ended) CurrentPhase = TimerPhase.Running;
        OnUndoSplit?.Invoke(this, EventArgs.Empty);
    }
}

public class Module
{
    public string ModuleName { get; set; }
    public IntPtr BaseAddress { get; set; }
    public string FileName { get; set; }
}
public class Game
{
    public byte[] ReadBytes(IntPtr address, int length) { throw new Exception("Native game access is unavailable in tests"); }
}
public class TestSettings
{
    public class Registration
    {
        public string Id, Label, Parent;
        public bool DefaultValue, Value;
    }
    public Dictionary<string, Registration> Entries = new Dictionary<string, Registration>();
    public void Add(string id, bool defaultValue, string label, string parent = null)
    {
        if (parent != null && !Entries.ContainsKey(parent)) throw new Exception("Register parent settings first");
        Entries.Add(id, new Registration { Id = id, Label = label, Parent = parent, DefaultValue = defaultValue, Value = defaultValue });
    }
    public bool this[string id]
    {
        get { var entry = Entries[id]; return entry.Value && (entry.Parent == null || this[entry.Parent]); }
        set { Entries[id].Value = value; }
    }
}
public class ActualASL
{
    public dynamic vars = new ExpandoObject();
    public Timer timer;
    public double refreshRate;
    public string version;
    public Game game = new Game();
    public TestSettings settings = new TestSettings();
    public List<Module> modules = new List<Module>();
    public List<string> Messages = new List<string>();
    public ActualASL(Timer timer) { this.timer = timer; }
    public void print(string message) { Messages.Add(message); }
    // INSERT_ACTUAL_ASL_ACTIONS
    // INSERT_ACTUAL_COMPONENT_READER
}

// A small byte-addressable IL2CPP graph containing a player, component cache,
// ProgressionComponent, and progression-key list. The real update traverses it.
public class Memory
{
    public const long Base = 0x10000000, Klass = 0x200000, Fields = 0x210000;
    public const long Manager = 0x220000, Player = 0x230000, Component = 0x240000;
    public const long ComponentClass = 0x250000, Name = 0x260000, List = 0x270000;
    public const long Items = 0x280000, Cache = 0x290000, Entries = 0x2A0000;
    private readonly Dictionary<long, byte> bytes = new Dictionary<long, byte>();
    private readonly Dictionary<long, string> guids = new Dictionary<long, string>();
    private readonly Dictionary<string, string> checkGuids;
    private int stamp;
    public bool Fail;
    public Memory(Dictionary<string, string> flagChecks)
    {
        checkGuids = flagChecks.ToDictionary(item => item.Value, item => item.Key);
        WriteLong(Base + 0x3F23D78, Klass);
        WriteLong(Klass + 0xB8, Fields);
        WriteLong(Fields, Manager);
        WriteLong(Manager + 0xB0, Player);
        WriteLong(Player + 0x30, Cache);
        WriteLong(Cache + 0x18, Entries);
        WriteInt(Cache + 0x20, 1);
        WriteInt(Entries + 0x18, 1);
        WriteInt(Entries + 0x20, 0);
        WriteLong(Entries + 0x30, Component);
        WriteLong(Component, ComponentClass);
        WriteLong(Component + 0x10, Player);
        WriteLong(ComponentClass + 0x10, Name);
        Write(Name, Encoding.ASCII.GetBytes("ProgressionComponent\0"));
        WriteLong(Component + 0x28, List);
        WriteLong(List + 0x10, Items);
        SetFlags();
    }
    public void Write(long address, byte[] value)
    {
        for (int i = 0; i < value.Length; i++) bytes[address + i] = value[i];
    }
    public void WriteLong(long address, long value) { Write(address, BitConverter.GetBytes(value)); }
    public void WriteInt(long address, int value) { Write(address, BitConverter.GetBytes(value)); }
    public byte[] Read(long address, int length)
    {
        if (Fail) throw new Exception("Synthetic progression read failed");
        byte[] result = new byte[length];
        for (int i = 0; i < length; i++) bytes.TryGetValue(address + i, out result[i]);
        return result;
    }
    public long Ptr(long address) { return BitConverter.ToInt64(Read(address, 8), 0); }
    public int Int(long address) { return BitConverter.ToInt32(Read(address, 4), 0); }
    public string Guid(long address) { if (Fail) throw new Exception("GUID read failed"); return guids[address]; }
    public void SetFlags(params string[] checks)
    {
        WriteInt(List + 0x18, checks.Length);
        WriteInt(List + 0x1C, ++stamp);
        WriteInt(Items + 0x18, checks.Length);
        for (int i = 0; i < checks.Length; i++)
        {
            long key = 0x300000L + i * 0x1000, guid = 0x400000L + i * 0x1000;
            WriteLong(Items + 0x20 + i * 8, key);
            WriteLong(key + 0x18, guid);
            guids[guid] = checkGuids[checks[i]];
        }
    }
    public void ReplacePlayer()
    {
        WriteLong(Manager + 0xB0, Player + 0x800);
        WriteLong(Player + 0x800 + 0x30, Cache);
    }
}

public class Fixture
{
    public readonly ActualASL S;
    public readonly Timer T;
    public readonly Memory M;
    public bool Loading, LoadingFail, Flow, SaveFail, Moving, HpFail, HpPresent;
    public bool FlowKnown = true, Fresh;
    public long SaveId = 0x500000, Entity = 0x600000, Stat = 0x610000, Context = 0x620000;
    public float Hp, Maximum = 100;
    public Queue<long> SaveSequence = new Queue<long>();
    public int Splits, HpReads;
    public Fixture(params string[] labels)
    {
        T = new Timer { Run = new Run(labels), CurrentSplitIndex = 0, CurrentPhase = TimerPhase.Running };
        S = new ActualASL(T);
        S.startup();
        M = new Memory((Dictionary<string, string>)S.vars.flagChecks);
        S.vars.baseAddress = Memory.Base;
        S.vars.mc = 0L;
        S.vars.component = 0L;
        S.vars.componentClass = 0L;
        S.vars.supported = true;
        S.vars.ptr = (Func<long, long>)M.Ptr;
        S.vars.i32 = (Func<long, int>)M.Int;
        S.vars.read = (Func<long, int, byte[]>)M.Read;
        S.vars.guid = (Func<long, string>)M.Guid;
        S.vars.loadingSnapshot = (Func<bool>)(() => {
            S.vars.loadingArtworkFlowActive = Flow;
            S.vars.loadingArtworkFlowKnown = FlowKnown;
            if (LoadingFail) throw new Exception("Loading sample failed");
            return Loading;
        });
        S.vars.saveSnapshot = (Func<object[]>)(() => {
            if (SaveFail) throw new Exception("Save sample failed");
            return new object[] { SaveSequence.Count > 0 ? SaveSequence.Dequeue() : SaveId, Fresh };
        });
        S.vars.movementSnapshot = (Func<bool>)(() => Moving);
        S.vars.draculaSnapshot = (Func<object[]>)(() => {
            HpReads++;
            if (HpFail) throw new Exception("HP sample failed");
            return HpPresent ? new object[] { Entity, Stat, Context, Hp, Maximum } : null;
        });
    }
    public void Baseline(params string[] flags) { M.SetFlags(flags); Update(); Expect.False(S.split(), "baseline must not queue a split"); }
    public void Update() { S.update(); }
    public bool Tick()
    {
        object result = S.update();
        if (result is bool && !(bool)result) return false;
        T.IsGameTimePaused = (bool)S.isLoading();
        bool split = (bool)S.split();
        if (split) Advance();
        return split;
    }
    public void Advance()
    {
        Splits++;
        T.CurrentSplitIndex++;
        if (T.CurrentSplitIndex == T.Run.Count) T.CurrentPhase = TimerPhase.Ended;
        S.onSplit();
    }
    public void Start()
    {
        T.CurrentPhase = TimerPhase.Running;
        T.CurrentSplitIndex = 0;
        S.onStart();
    }
    public void Reset()
    {
        T.CurrentPhase = TimerPhase.NotRunning;
        T.CurrentSplitIndex = -1;
        S.onReset();
    }
    public void Health(float health) { HpPresent = true; Hp = health; }
    public void Select(params string[] checks)
    {
        foreach (string key in ((Dictionary<string, string>)S.vars.checkNames).Keys) S.settings["boss_" + key] = false;
        foreach (string key in checks) S.settings["boss_" + key] = true;
    }
}

// This calls the exact draculaComponents delegate extracted from native init.
// Only its memory transport and class-name lookup are controlled by the tests.
public class ComponentFixture
{
    public readonly ActualASL S;
    public readonly Memory M;
    public const long Entity = 0x700000, FirstComponent = 0x800000;
    public long Native = 0x710000, Context = 0x720000, Cache = 0x730000, Entries = 0x740000;
    public int Version = 1, Classifications;
    public List<string> Names;
    public HashSet<long> Unknown = new HashSet<long>();
    public Action DuringClassification;
    private readonly Dictionary<long, string> componentNames = new Dictionary<long, string>();
    public ComponentFixture(params string[] names)
    {
        S = new ActualASL(new Timer { Run = new Run(new[] { "Custom" }) }); S.startup();
        M = new Memory((Dictionary<string, string>)S.vars.flagChecks);
        S.vars.ptr = (Func<long, long>)M.Ptr;
        S.vars.i32 = (Func<long, int>)M.Int;
        S.vars.read = (Func<long, int, byte[]>)M.Read;
        S.vars.draculaComponentHandles = new Dictionary<long, long[]>();
        S.vars.draculaComponentContext = 0L;
        S.vars.draculaClassName = (Func<long, string>)(component => {
            Classifications++; DuringClassification?.Invoke();
            if (Unknown.Contains(component)) throw new Exception("Synthetic class unavailable");
            return componentNames[component];
        });
        Names = names.ToList(); WriteGraph(); S.InstallDraculaComponents();
    }
    public void WriteGraph()
    {
        M.WriteLong(Entity + 0x10, Native); M.WriteLong(Entity + 0x28, Context); M.WriteLong(Entity + 0x30, Cache);
        M.WriteLong(Cache + 0x18, Entries); M.WriteInt(Cache + 0x20, Names.Count); M.WriteInt(Cache + 0x2C, Version);
        M.WriteInt(Entries + 0x18, Names.Count);
        for (int i = 0; i < Names.Count; i++)
        {
            long component = FirstComponent + i * 0x100;
            M.WriteInt(Entries + 0x20 + i * 0x18, i);
            M.WriteLong(Entries + 0x30 + i * 0x18, component);
            componentNames[component] = Names[i];
        }
    }
    public long[] Read(long entity = Entity) { return (long[])S.vars.draculaComponents(entity); }
    public Dictionary<long, long[]> Handles => (Dictionary<long, long[]>)S.vars.draculaComponentHandles;
}

public static class Expect
{
    public static void True(object actual, string reason = "expected true") { if (!(actual is bool && (bool)actual)) throw new Exception(reason); }
    public static void False(object actual, string reason = "expected false") { if (!(actual is bool && !(bool)actual)) throw new Exception(reason); }
    public static void Equal<T>(T expected, T actual, string reason = "")
    {
        if (!EqualityComparer<T>.Default.Equals(expected, actual)) throw new Exception($"{reason}: expected {expected}, got {actual}");
    }
    public static void Throws(Action action)
    {
        try { action(); } catch { return; }
        throw new Exception("Expected the unstable sample to be rejected");
    }
}
public static class Program
{
    private static int passed, failed;
    private static readonly string[] Checks = { "fallen", "joan", "medusa", "death_1", "isaac_1", "talos", "carmilla", "death_2", "isaac_2", "dracula" };
    private static void Test(string name, Action test)
    {
        try { test(); passed++; Console.WriteLine("PASS: " + name); }
        catch (Exception error) { failed++; Console.WriteLine("FAIL: " + name + "\n" + error); }
    }
    private static Fixture Ready(params string[] labels) { var f = new Fixture(labels); f.Baseline(); return f; }
    private static void QueuedMutation(string name, Action<Fixture> mutate)
    {
        Test(name, () => {
            var f = Ready("First", "Second");
            f.M.SetFlags("fallen"); f.Update(); mutate(f);
            Expect.False(f.S.split());
        });
    }
    private static void DraculaGap(string name, Action<Fixture> gap, Action<Fixture> restore)
    {
        Test(name, () => {
            var f = Ready("Finale");
            f.Health(20); Expect.False(f.Tick());
            gap(f); Expect.False(f.Tick()); restore(f);
            f.Health(0); Expect.False(f.Tick());
        });
    }
    public static int Main()
    {
        Test("native subreader reuses fully classified non-boss dictionaries", () => {
            var f = new ComponentFixture("Transform"); var first = f.Read(); var second = f.Read();
            Expect.True(ReferenceEquals(first, second)); Expect.Equal(1, f.Classifications);
            Expect.Equal(0L, first[0]); Expect.Equal(0L, first[1]); Expect.Equal(0L, first[2]);
        });
        foreach (string identity in new[] { "cache", "entries", "count", "version", "native", "context" })
            Test("native component cache invalidates after changing " + identity, () => {
                var f = new ComponentFixture("Transform"); var first = f.Read();
                int classifications = f.Classifications;
                if (identity == "cache") f.Cache += 0x100000;
                if (identity == "entries") f.Entries += 0x100000;
                if (identity == "count") f.Names.Add("Renderer");
                if (identity == "version") f.Version++;
                if (identity == "native") f.Native++;
                if (identity == "context") f.Context++;
                f.WriteGraph(); var second = f.Read();
                Expect.False(ReferenceEquals(first, second)); Expect.True(f.Classifications > classifications);
            });
        Test("native context replacement clears other entity classifications", () => {
            var f = new ComponentFixture("Transform"); f.Read();
            long other = ComponentFixture.Entity + 0x1000;
            f.M.WriteLong(other + 0x10, f.Native + 1); f.M.WriteLong(other + 0x28, f.Context); f.M.WriteLong(other + 0x30, f.Cache);
            f.Read(other); Expect.Equal(2, f.Handles.Count);
            f.Context++; f.WriteGraph(); f.Read();
            Expect.Equal(1, f.Handles.Count); Expect.False(f.Handles.ContainsKey(other));
        });
        Test("native unknown class samples are retried without a version change", () => {
            var f = new ComponentFixture("Transform"); f.Unknown.Add(ComponentFixture.FirstComponent);
            Expect.Equal(1L, f.Read()[3]); Expect.Equal(1L, f.Read()[3]); Expect.Equal(2, f.Classifications);
            Expect.Equal(0, f.Handles.Count);
            f.Unknown.Clear(); var known = f.Read(); Expect.Equal(3, f.Classifications);
            Expect.True(ReferenceEquals(known, f.Read())); Expect.Equal(3, f.Classifications);
        });
        foreach (long pointer in new[] { 0L, 0x20L })
            Test("native occupied invalid component pointer is retried: " + pointer, () => {
                var f = new ComponentFixture("Transform"); f.M.WriteLong(f.Entries + 0x30, pointer);
                Expect.Equal(1L, f.Read()[3]); Expect.Equal(1L, f.Read()[3]); Expect.Equal(0, f.Handles.Count);
                f.WriteGraph(); f.Read(); Expect.Equal(1, f.Classifications); Expect.Equal(1, f.Handles.Count);
            });
        foreach (string absent in new[] { "native", "context" })
            Test("native incomplete identity is not negatively cached: " + absent, () => {
                var f = new ComponentFixture("Transform");
                if (absent == "native") f.Native = 0; else f.Context = 0;
                f.WriteGraph(); f.Read(); f.Read(); Expect.Equal(2, f.Classifications); Expect.Equal(0, f.Handles.Count);
            });
        Test("native complete Dracula handles remain positively cached", () => {
            var f = new ComponentFixture("DraculaBeastState", "Damageable", "MobComponent");
            var handles = f.Read(); Expect.Equal(ComponentFixture.FirstComponent, handles[0]);
            Expect.Equal(ComponentFixture.FirstComponent + 0x100, handles[1]); Expect.Equal(ComponentFixture.FirstComponent + 0x200, handles[2]);
            Expect.True(ReferenceEquals(handles, f.Read())); Expect.Equal(3, f.Classifications);
        });
        Test("native dictionary changes during classification are rejected", () => {
            var f = new ComponentFixture("Transform");
            f.DuringClassification = () => f.M.WriteInt(f.Cache + 0x2C, f.Version + 1);
            Expect.Throws(() => f.Read()); Expect.Equal(0, f.Handles.Count);
            f.DuringClassification = null; f.Version++; f.WriteGraph(); f.Read(); Expect.Equal(1, f.Handles.Count);
        });
        Test("catalog contains exactly the ten supported checks", () => {
            var f = new Fixture("manual");
            var catalog = (Dictionary<string, string>)f.S.vars.checkNames;
            Expect.Equal(string.Join(",", Checks.OrderBy(x => x)), string.Join(",", catalog.Keys.OrderBy(x => x)));
            Expect.Equal(9, ((Dictionary<string, string>)f.S.vars.flagChecks).Count);
        });
        Test("startup registers the boss group and ten enabled child settings", () => {
            var f = new Fixture("Opening");
            Expect.Equal(11, f.S.settings.Entries.Count);
            var group = f.S.settings.Entries["bosses"];
            Expect.True(group.DefaultValue); Expect.Equal<string>(null, group.Parent);
            Expect.Equal("Boss defeats", group.Label);
            foreach (string key in Checks)
            {
                var setting = f.S.settings.Entries["boss_" + key];
                Expect.True(setting.DefaultValue); Expect.Equal("bosses", setting.Parent);
                Expect.True(setting.Label.Length > 0); Expect.True(f.S.settings["boss_" + key]);
            }
        });
        Test("parent settings disable effective children without erasing their choices", () => {
            var f = Ready("Opening"); f.S.settings["bosses"] = false;
            foreach (string key in Checks)
            {
                Expect.False(f.S.settings["boss_" + key]);
                Expect.True(f.S.settings.Entries["boss_" + key].Value);
            }
            f.M.SetFlags("fallen"); Expect.False(f.Tick());
            f.S.settings["bosses"] = true; Expect.False(f.Tick());
        });
        foreach (string label in new[] { "", "Anything", "Talos", "[unknown]", "[fallen] [joan]", "[fallen", "[[fallen]]" })
            Test("segment labels are cosmetic: " + label, () => {
                var f = Ready(label); f.M.SetFlags("fallen"); Expect.True(f.Tick());
                Expect.Equal(label, f.T.Run[0].Name);
            });
        Test("the actual actions never read any segment names", () => {
            var timer = new Timer { Run = new Run(new[] { "Uninspectable" }) };
            timer.Run[0].RejectNameReads = true; new ActualASL(timer).startup();
            var f = new Fixture("Opening", "Opening");
            foreach (var row in f.T.Run) row.RejectNameReads = true;
            f.Baseline(); f.M.SetFlags("talos"); Expect.True(f.Tick());
            f.M.SetFlags("talos", "joan"); Expect.True(f.Tick());
        });
        foreach (bool carmillaFirst in new[] { false, true })
            Test("complete route: " + (carmillaFirst ? "Carmilla first" : "Talos first"), () => {
                var order = Checks.ToArray();
                if (carmillaFirst) { order[5] = "carmilla"; order[6] = "talos"; }
                var catalog = (Dictionary<string, string>)new Fixture("Catalog").S.vars.checkNames;
                var f = Ready(order.Select(x => catalog[x]).ToArray());
                var flags = new List<string>();
                foreach (string key in order.Take(9)) { flags.Add(key); f.M.SetFlags(flags.ToArray()); Expect.True(f.Tick(), key); }
                f.Health(100); Expect.False(f.Tick()); f.Health(0); Expect.True(f.Tick());
                Expect.Equal(10, f.Splits); Expect.Equal(TimerPhase.Ended, f.T.CurrentPhase);
            });
        Test("selected subset follows event order with arbitrary clean labels", () => {
            var f = Ready("Opening", "Finale"); f.Select("talos", "fallen");
            f.M.SetFlags("talos"); Expect.True(f.Tick());
            f.M.SetFlags("talos", "joan"); Expect.False(f.Tick());
            f.M.SetFlags("talos", "joan", "fallen"); Expect.True(f.Tick());
        });
        Test("selected bosses work with manual transitions and Dracula finish", () => {
            var f = Ready("Opening", "Manual pause", "Snake", "Finale");
            f.Select("fallen", "medusa", "dracula");
            f.M.SetFlags("fallen"); Expect.True(f.Tick()); Expect.False(f.Tick());
            f.Advance();
            f.M.SetFlags("fallen", "joan"); Expect.False(f.Tick());
            f.M.SetFlags("fallen", "joan", "medusa"); Expect.True(f.Tick());
            f.Health(50); Expect.False(f.Tick()); f.Health(0); Expect.True(f.Tick());
            Expect.Equal(TimerPhase.Ended, f.T.CurrentPhase);
        });
        Test("all child settings can be disabled and later select a fresh event", () => {
            var f = Ready("Opening"); f.Select();
            f.M.SetFlags("fallen", "joan"); Expect.False(f.Tick());
            f.Select("medusa"); f.M.SetFlags("fallen", "joan", "medusa"); Expect.True(f.Tick());
        });
        Test("enabling a checkbox before a fresh event allows that event", () => {
            var f = Ready("Opening"); f.S.settings["boss_talos"] = false; Expect.False(f.Tick());
            f.S.settings["boss_talos"] = true; f.M.SetFlags("talos"); Expect.True(f.Tick());
        });
        Test("more than ten segments and manual hotkey transitions", () => {
            var labels = Enumerable.Repeat("Custom", 14).ToArray();
            var f = Ready(labels);
            for (int i = 0; i < 12; i++) f.T.Skip();
            f.Update(); f.M.SetFlags("medusa"); Expect.True(f.Tick()); Expect.Equal(13, f.T.CurrentSplitIndex);
        });
        Test("an enabled defeat advances the current row regardless of its label", () => {
            var f = Ready("Joan", "Talos");
            f.M.SetFlags("talos"); Expect.True(f.Tick());
            f.M.SetFlags("talos", "joan"); Expect.True(f.Tick()); Expect.False(f.Tick());
        });
        Test("disabled events stay consumed after enabling, rollback and re-addition", () => {
            var f = Ready("Opening", "Finale"); f.S.settings["boss_talos"] = false;
            f.M.SetFlags("talos"); Expect.False(f.Tick());
            f.S.settings["boss_talos"] = true; Expect.False(f.Tick());
            f.M.SetFlags(); Expect.False(f.Tick());
            f.M.SetFlags("talos"); Expect.False(f.Tick());
        });
        Test("simultaneous enabled events coalesce without delayed catch-up", () => {
            var f = Ready("Opening", "Next");
            f.M.SetFlags("fallen", "joan"); Expect.True(f.Tick()); Expect.False(f.Tick()); Expect.Equal(1, f.Splits);
            Expect.True(f.S.vars.seenChecks.Contains("fallen")); Expect.True(f.S.vars.seenChecks.Contains("joan"));
        });
        Test("a simultaneous disabled event cannot block an enabled event", () => {
            var f = Ready("Opening", "Next"); f.Select("joan");
            f.M.SetFlags("fallen", "joan"); Expect.True(f.Tick()); Expect.False(f.Tick());
            Expect.True(f.S.vars.seenChecks.Contains("fallen")); Expect.True(f.S.vars.seenChecks.Contains("joan"));
        });
        Test("simultaneous Dracula and progression defeats advance only once", () => {
            var f = Ready("Opening", "Next"); f.Health(40); Expect.False(f.Tick());
            f.Health(0); f.M.SetFlags("fallen"); Expect.True(f.Tick()); Expect.False(f.Tick());
            Expect.True(f.S.vars.seenChecks.Contains("dracula")); Expect.True(f.S.vars.seenChecks.Contains("fallen"));
        });
        Test("duplicate names and repeated polls cannot repeat one defeat", () => {
            var f = Ready("Fight", "Fight");
            f.M.SetFlags("fallen"); Expect.True(f.Tick());
            for (int i = 0; i < 3; i++) Expect.False(f.Tick());
            f.M.SetFlags(); Expect.False(f.Tick()); f.M.SetFlags("fallen"); Expect.False(f.Tick());
        });
        QueuedMutation("pending event rejects an index change", f => f.T.CurrentSplitIndex = 1);
        QueuedMutation("unchecking a boss rejects its pending event", f => f.S.settings["boss_fallen"] = false);
        QueuedMutation("unchecking the parent rejects a pending event", f => f.S.settings["bosses"] = false);
        QueuedMutation("pending event rejects a replaced segment", f => f.T.Run[0] = new Segment("First"));
        QueuedMutation("pending event rejects a replaced run", f => f.T.Run = new Run(new[] { "First", "Second" }));
        QueuedMutation("pending event rejects a paused timer", f => f.T.CurrentPhase = TimerPhase.Paused);
        QueuedMutation("native skip/undo with net-zero index clears pending event", f => { f.T.Skip(); f.T.Undo(); });
        QueuedMutation("manual split followed by undo clears pending event", f => { f.Advance(); f.T.Undo(); });
        Test("re-enabling a rejected pending event cannot replay it", () => {
            var f = Ready("Opening"); f.M.SetFlags("fallen"); f.Update();
            f.S.settings["boss_fallen"] = false; Expect.False(f.S.split());
            f.S.settings["boss_fallen"] = true; Expect.False(f.Tick());
        });
        Test("events observed while paused are discarded", () => {
            var f = Ready("Opening"); f.T.CurrentPhase = TimerPhase.Paused;
            f.M.SetFlags("fallen"); Expect.False(f.Tick());
            f.T.CurrentPhase = TimerPhase.Running; Expect.False(f.Tick());
        });
        Test("renaming a segment to blank preserves its pending event", () => {
            var f = Ready("Before"); f.M.SetFlags("fallen"); f.Update();
            f.T.Run[0].Name = ""; Expect.True(f.S.split()); Expect.False(f.S.split());
        });
        Test("attach establishes a baseline for existing flags", () => {
            var f = new Fixture("Opening"); f.Baseline("fallen"); Expect.False(f.Tick());
        });
        Test("manual start baselines existing flags", () => {
            var f = Ready("Opening"); f.M.SetFlags("fallen"); f.Start(); Expect.False(f.Tick());
        });
        Test("reset clears event history and baselines the next attempt", () => {
            var f = Ready("Opening"); f.M.SetFlags("fallen"); f.Update(); f.Reset();
            Expect.False(f.S.split()); f.M.SetFlags(); f.Start(); Expect.False(f.Tick());
            f.M.SetFlags("fallen"); Expect.True(f.Tick());
        });
        Test("loading and its first restored frame baseline flags", () => {
            var f = Ready("Opening"); f.Loading = true; f.M.SetFlags("fallen"); Expect.False(f.Tick());
            f.Loading = false; Expect.False(f.Tick()); Expect.False(f.Tick());
        });
        Test("loading artwork flow baselines flags while the clock runs", () => {
            var f = Ready("Opening"); f.Flow = true; f.M.SetFlags("fallen"); Expect.False(f.Tick());
            Expect.False(f.S.isLoading()); f.Flow = false; Expect.False(f.Tick());
        });
        Test("unreadable loading state baselines restored flags", () => {
            var f = Ready("Opening"); f.LoadingFail = true; f.M.SetFlags("fallen"); Expect.False(f.Tick());
            f.LoadingFail = false; Expect.False(f.Tick());
        });
        Test("progression read failure establishes a fresh baseline", () => {
            var f = Ready("Opening"); f.M.Fail = true; Expect.False(f.Tick());
            f.M.Fail = false; f.M.SetFlags("fallen"); Expect.False(f.Tick()); Expect.True((bool)f.S.vars.valid);
        });
        Test("save identity changes baseline newly loaded flags", () => {
            var f = Ready("Opening"); f.SaveId++; f.M.SetFlags("fallen"); Expect.False(f.Tick());
        });
        Test("save read failure baselines restored flags", () => {
            var f = Ready("Opening"); f.SaveFail = true; Expect.False(f.Tick());
            f.SaveFail = false; f.M.SetFlags("fallen"); Expect.False(f.Tick());
        });
        Test("player replacement baselines progression", () => {
            var f = Ready("Opening"); f.M.ReplacePlayer(); f.M.SetFlags("fallen"); Expect.False(f.Tick());
        });
        Test("rollback establishes a baseline without replaying checks", () => {
            var f = new Fixture("Opening"); f.Baseline("joan");
            f.M.SetFlags("fallen"); Expect.False(f.Tick()); Expect.False(f.Tick());
        });
        Test("new run object establishes a baseline", () => {
            var f = Ready("Opening"); f.T.Run = new Run(new[] { "Opening" });
            f.M.SetFlags("fallen"); Expect.False(f.Tick());
        });
        Test("Dracula final positive-to-zero HP triggers", () => {
            var f = Ready("Finale"); f.Health(1); Expect.False(f.Tick()); f.Health(0); Expect.True(f.Tick());
        });
        Test("Dracula triggers independently of failed player progression reads", () => {
            var f = Ready("Finale"); f.Health(40); Expect.False(f.Tick());
            f.M.Fail = true; f.Health(0); Expect.True(f.Tick());
        });
        Test("initial zero Dracula HP is not a defeat", () => {
            var f = Ready("Finale"); f.Health(0); Expect.False(f.Tick()); Expect.False(f.Tick());
        });
        Test("one HP Dracula is alive", () => {
            var f = Ready("Finale"); f.Health(100); Expect.False(f.Tick()); f.Health(1); Expect.False(f.Tick());
        });
        DraculaGap("missing Dracula sample breaks its HP edge", f => f.HpPresent = false, f => f.HpPresent = true);
        DraculaGap("unreadable Dracula HP breaks its HP edge", f => f.HpFail = true, f => f.HpFail = false);
        DraculaGap("unreadable save breaks Dracula's HP edge", f => f.SaveFail = true, f => f.SaveFail = false);
        DraculaGap("unreadable loading sample breaks Dracula's HP edge", f => f.LoadingFail = true, f => f.LoadingFail = false);
        DraculaGap("loading breaks Dracula's HP edge", f => f.Loading = true, f => f.Loading = false);
        DraculaGap("loading artwork flow breaks Dracula's HP edge", f => f.Flow = true, f => f.Flow = false);
        DraculaGap("unknown artwork flow breaks Dracula's HP edge", f => f.FlowKnown = false, f => f.FlowKnown = true);
        DraculaGap("disabling Dracula breaks its HP edge", f => f.S.settings["boss_dracula"] = false, f => f.S.settings["boss_dracula"] = true);
        DraculaGap("disabling the boss group breaks Dracula's HP edge", f => f.S.settings["bosses"] = false, f => f.S.settings["bosses"] = true);
        foreach (string identity in new[] { "entity", "stat", "context", "save" })
            Test("Dracula requires the same " + identity, () => {
                var f = Ready("Finale"); f.Health(30); Expect.False(f.Tick());
                if (identity == "entity") f.Entity++;
                if (identity == "stat") f.Stat++;
                if (identity == "context") f.Context++;
                if (identity == "save") f.SaveId++;
                f.Health(0); Expect.False(f.Tick());
            });
        Test("Dracula rejects a save change during its HP sample", () => {
            var f = Ready("Finale"); f.Health(30); Expect.False(f.Tick());
            f.SaveSequence.Enqueue(f.SaveId); f.SaveSequence.Enqueue(f.SaveId + 1);
            f.Health(0); Expect.False(f.Tick());
        });
        Test("disabled Dracula avoids HP reads and cannot replay an earlier zero sample", () => {
            var f = Ready("Opening"); f.S.settings["boss_dracula"] = false;
            int reads = f.HpReads; f.Health(30); Expect.False(f.Tick());
            f.Health(0); Expect.False(f.Tick()); Expect.Equal(reads, f.HpReads);
            f.S.settings["boss_dracula"] = true; Expect.False(f.Tick());
            f.Health(30); Expect.False(f.Tick()); f.Health(0); Expect.True(f.Tick());
        });
        Test("disabled boss group avoids Dracula HP reads", () => {
            var f = Ready("Opening"); f.S.settings["bosses"] = false;
            int reads = f.HpReads; f.Health(30); Expect.False(f.Tick()); f.Health(0); Expect.False(f.Tick());
            Expect.Equal(reads, f.HpReads);
        });
        Test("enabled Dracula can finish any current segment with a clean label", () => {
            var f = Ready("Custom finale"); f.Health(30); Expect.False(f.Tick());
            f.Health(0); Expect.True(f.Tick());
        });
        Test("consumed Dracula cannot split another segment or continue polling", () => {
            var f = Ready("Fight", "Fight"); f.Health(30); Expect.False(f.Tick());
            f.Health(0); Expect.True(f.Tick()); int reads = f.HpReads;
            f.Health(30); Expect.False(f.Tick()); f.Health(0); Expect.False(f.Tick()); Expect.Equal(reads, f.HpReads);
        });
        Test("skip/undo breaks Dracula positive health continuity", () => {
            var f = Ready("Finale", "Manual"); f.Health(30); Expect.False(f.Tick());
            f.T.Skip(); f.T.Undo(); f.Health(0); Expect.False(f.Tick());
        });
        foreach (string label in new[] { "Manual", "[unknown]", "[talos] [joan]" })
            Test("new-save movement start works with all boss settings disabled: " + label, () => {
                var f = new Fixture(label); f.T.CurrentPhase = TimerPhase.NotRunning; f.T.CurrentSplitIndex = -1;
                f.S.settings["bosses"] = false;
                f.Update(); Expect.False(f.S.start()); f.SaveId++; f.Fresh = true;
                f.Update(); Expect.False(f.S.start()); f.Moving = true; f.M.Fail = true;
                f.Update(); Expect.True(f.S.start()); Expect.False(f.S.start());
                f.Start(); Expect.Equal(TimingMethod.GameTime, f.T.CurrentTimingMethod);
            });
        Test("attaching to an already fresh save cannot auto-start", () => {
            var f = new Fixture("Manual"); f.T.CurrentPhase = TimerPhase.NotRunning; f.T.CurrentSplitIndex = -1;
            f.Fresh = true; f.Moving = true; f.Update(); Expect.False(f.S.start());
        });
        Test("loading suppresses new-save movement start until control returns", () => {
            var f = new Fixture("Manual"); f.T.CurrentPhase = TimerPhase.NotRunning; f.T.CurrentSplitIndex = -1;
            f.Update(); f.SaveId++; f.Fresh = true; f.Moving = true; f.Loading = true;
            f.Update(); Expect.False(f.S.start()); f.Loading = false; f.Update(); Expect.True(f.S.start());
        });
        Test("load removal works with all boss settings disabled", () => {
            var f = Ready("Custom"); f.Select(); f.Loading = true; f.Update(); Expect.True(f.S.isLoading());
            f.Loading = false; f.Update(); Expect.False(f.S.isLoading());
        });
        Test("unsupported game disables update and auto-start", () => {
            var f = Ready("Opening"); f.S.vars.supported = false; f.S.vars.startRequested = true;
            f.T.CurrentPhase = TimerPhase.NotRunning; Expect.False(f.S.update()); Expect.False(f.S.start());
        });
        Test("exit clears pending events and releases game-time pause", () => {
            var f = Ready("Opening"); f.M.SetFlags("fallen"); f.Update(); f.T.IsGameTimePaused = true;
            f.S.exit(); Expect.False(f.S.split()); Expect.False(f.T.IsGameTimePaused);
            Expect.True((bool)f.S.vars.baselineNeeded); Expect.False((bool)f.S.vars.saveBaselineReady);
        });
        Test("shutdown unsubscribes native skip/undo handlers", () => {
            var f = Ready("Manual", "Manual"); Expect.Equal(1, f.T.SkipSubscribers); Expect.Equal(1, f.T.UndoSubscribers);
            f.T.IsGameTimePaused = true; f.S.shutdown();
            Expect.Equal(0, f.T.SkipSubscribers); Expect.Equal(0, f.T.UndoSubscribers); Expect.False(f.T.IsGameTimePaused);
            int revision = f.S.vars.segmentRevision; f.T.Skip(); f.T.Undo(); Expect.Equal(revision, (int)f.S.vars.segmentRevision);
        });
        Console.WriteLine($"\n{passed} passed; {failed} failed. Every ASL action (including native init) compiled from the current source.");
        return failed == 0 ? 0 : 1;
    }
}
