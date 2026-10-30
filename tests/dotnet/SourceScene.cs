using System.Text.Json;
using Gua.Core;
using Gua.Testing;
using Gua.Testing.Godot;
using NUnit.Framework;

namespace Factory.Regression;

/// <summary>Test-only convenience around the released source-scene host. No EXE runner,
/// Scenario evaluator, Planner, Trace format or replay scheduler lives here.</summary>
internal sealed class SourceScene : IDisposable
{
    public const int Port = 18241;
    public static readonly string[] Bugs = ["B01_PLATFORM_RESPAWN", "B02_CARGO_LOSS", "B03_DOUBLE_RESULT"];
    public static string Root => Environment.GetEnvironmentVariable("FACTORY_PROJECT_DIR")
        ?? throw new InvalidOperationException("Set FACTORY_PROJECT_DIR to this checkout.");
    public string Directory { get; }
    public GodotSceneTestHost Host { get; }
    public GuaWebSocketContext Client { get; }
    private GuaRemoteGuardedSession? input;
    private readonly HashSet<string> heldInputs = [];

    public SourceScene(string directory, string instance = "scene")
    {
        Directory = directory;
        System.IO.Directory.CreateDirectory(directory);
        var appData = Path.Combine(directory, "appdata");
        var localData = Path.Combine(directory, "localappdata");
        System.IO.Directory.CreateDirectory(appData);
        System.IO.Directory.CreateDirectory(localData);
        Host = GodotSceneTestHost.Load("res://main.tscn", new GodotSceneTestHostOptions
        {
            ProjectPath = Root,
            GodotExecutablePath = Environment.GetEnvironmentVariable("GODOT_EXECUTABLE"),
            BridgeUrl = $"ws://127.0.0.1:{Port}",
            Headless = true,
            AdditionalArguments = ["--log-file", Path.Combine(directory, instance + ".log"), "--", "--fixed-clock"],
            EnvironmentVariables = new Dictionary<string, string>
            {
                ["FACTORY_SAVE_DIR"] = directory, ["APPDATA"] = appData, ["LOCALAPPDATA"] = localData,
            },
        });
        try
        {
            // Use the common SDK client for Observe/guarded input; the scene
            // host still owns process lifetime. Do not retain an unused socket.
            Host.RemoteContext.Dispose();
            Client = new GuaWebSocketContext($"ws://127.0.0.1:{Port}");
            Client.WaitUntilAvailable(TimeSpan.FromSeconds(10));
            var version = Client.GetVersion();
            Assert.That(version.CoreVersion, Is.EqualTo("1.1.2"));
            Assert.That(version.RuntimeVersion, Is.EqualTo("1.1.2"));
            Assert.That(version.GodotPluginVersion, Is.EqualTo("1.1.2"));
            Published(Client.GetContextStatus().SessionEpoch).GetAwaiter().GetResult();
            Assert.That(State().GetProperty("seed").GetInt64(), Is.EqualTo(112));
            input = Client.CreateGuardedDispatchSession();
            using var map = JsonDocument.Parse(input.GetGameInputActionsJson());
            var actions = map.RootElement.GetProperty("actions").EnumerateArray().ToArray();
            Assert.That(actions.Length, Is.EqualTo(3));
            foreach (var (id, type) in new[] { ("move", "axis1d"), ("jump", "button"), ("interact", "button") })
                Assert.That(actions.Single(a => a.GetProperty("id").GetString() == id).GetProperty("valueType").GetString(), Is.EqualTo(type));
        }
        catch { Client?.Dispose(); Host.Dispose(); throw; }
    }

    public async Task Click(string id)
    {
        await Ui(new GuaActionRequest(GuaActionType.Click, id));
    }

    public async Task Start(string bug = "")
    {
        foreach (var id in Bugs) await Ui(new GuaActionRequest(GuaActionType.SetChecked, id, BoolValue: id == bug));
        await Click("start");
        Assert.That(State().GetProperty("mode").GetString(), Is.EqualTo("play"));
    }

    private async Task Ui(GuaActionRequest request)
    {
        var beforePublication = Client.GetContextStatus();
        input ??= Client.CreateGuardedDispatchSession();
        GuaRemoteDispatchAttempt attempt;
        var refresh = 0;
        do
        {
            var node = await GuaAssertions.Query(Client).ById(request.NodeId!).ResolveAsync();
            node.ToBeVisible().ToBeEnabled();
            using var tree = JsonDocument.Parse(Client.GetUiTreeJson());
            var epoch = tree.RootElement.GetProperty("sessionEpoch").GetUInt64();
            Assert.That(epoch, Is.EqualTo(beforePublication.SessionEpoch));
            var guard = new GuaDispatchGuard(epoch, GuaObservationProfile.Debug,
                tree.RootElement.GetProperty("revision").GetUInt64(), input.SourceId);
            attempt = input.SendUi(guard, request);
            if (attempt.State != GuaRemoteDispatchState.Rejected ||
                attempt.Error?.Contains("stale_guard", StringComparison.Ordinal) != true) break;
            if (refresh == 2) break;
            // A stale guard is rejected before enqueue, so this action did not
            // execute. Re-observe and re-check the target, never replay an
            // enqueued/completed/timed-out action or cross a changed epoch.
            TestContext.WriteLine($"UI {request.NodeId}: rejected stale guard; refreshing observation {refresh + 1}/2.");
            await Task.Delay(10);
        } while (++refresh <= 2);
        var deadline = DateTime.UtcNow + TimeSpan.FromSeconds(5);
        while (attempt.State == GuaRemoteDispatchState.Enqueued && DateTime.UtcNow < deadline)
        {
            input.Poll(attempt);
            if (attempt.State == GuaRemoteDispatchState.Enqueued) await Task.Delay(5);
        }
        Assert.That(attempt.State, Is.EqualTo(GuaRemoteDispatchState.Completed), attempt.Error);
        Assert.That(attempt.Completion!.Value.GetProperty("succeeded").GetBoolean(), Is.True);
        await Published(beforePublication.SessionEpoch);
    }

    public async Task Input(string id, object? value = null, bool release = false)
    {
        var beforePublication = Client.GetContextStatus();
        input ??= Client.CreateGuardedDispatchSession();
        using var map = JsonDocument.Parse(input.GetGameInputActionsJson());
        var guard = new GuaDispatchGuard(map.RootElement.GetProperty("sessionEpoch").GetUInt64(),
            GuaObservationProfile.Debug, map.RootElement.GetProperty("revision").GetUInt64(), input.SourceId);
        var attempt = input.SendGameInput(guard, new GuaRemoteGameInputRequest(
            release ? "release_game_input_action" : "set_game_input_action", id, value, LeaseMs: 30000));
        var deadline = DateTime.UtcNow + TimeSpan.FromSeconds(5);
        while (attempt.State == GuaRemoteDispatchState.Enqueued && DateTime.UtcNow < deadline)
        {
            input.Poll(attempt);
            if (attempt.State == GuaRemoteDispatchState.Enqueued) await Task.Delay(5);
        }
        Assert.That(attempt.State, Is.EqualTo(GuaRemoteDispatchState.Completed), attempt.Error);
        Assert.That(attempt.Completion!.Value.GetProperty("succeeded").GetBoolean(), Is.True);
        if (release) heldInputs.Remove(id); else heldInputs.Add(id);
        await Published(beforePublication.SessionEpoch);
    }

    public async Task Release()
    {
        // Only this SDK input session owns these actions. No release-all wire tunnel.
        foreach (var id in heldInputs.ToArray()) await Input(id, release: true);
    }

    public JsonElement State()
    {
        using var snapshot = JsonDocument.Parse(Client.GetObserveSnapshotJson());
        var document = snapshot.RootElement.GetProperty("document");
        Assert.That(document.GetProperty("profile").GetString(), Is.EqualTo("debug"));
        var values = new Dictionary<string, JsonElement>();
        foreach (var entry in document.GetProperty("entries").EnumerateArray())
        {
            Assert.That(entry.GetProperty("status").GetString(), Is.EqualTo("available"));
            values.Add(entry.GetProperty("name").GetString()!, entry.GetProperty("value").GetProperty("value").Clone());
        }
        Assert.That(values.Count, Is.GreaterThanOrEqualTo(18));
        return JsonSerializer.SerializeToElement(values);
    }

    public (double X, double Y) Position(string id = "robot")
    {
        using var world = JsonDocument.Parse(Client.GetWorldObjectTreeJson());
        var node = world.RootElement.GetProperty("objects").EnumerateArray().Single(x => x.GetProperty("id").GetString() == id);
        var position = node.GetProperty("position");
        return (position.GetProperty("x").GetDouble(), position.GetProperty("y").GetDouble());
    }

    public async Task Step(int ticks)
    {
        Assert.That(ticks, Is.GreaterThan(0));
        // TimeSpan has 100ns resolution. Round 1/60s upward instead of repeatedly
        // truncating it below the game's fixed DT. This is a test clock quantum,
        // not a second physics scheduler (game.tick remains the sole simulation).
        var beforePublication = Client.GetContextStatus();
        var step = TimeSpan.FromTicks(166667);
        await Client.RunClockForAsync(TimeSpan.FromTicks(166667L * ticks), step);

        // The SDK correlates operation/epoch/UI completion. Also require a fresh
        // World publication before inspecting position/Observe from that step.
        await Published(beforePublication.SessionEpoch);
    }

    private async Task Published(ulong epoch)
    {
        // The action/clock receipt precedes Observe publication. Require a
        // complete later host cycle, including the Observe document, rather
        // than accepting frames that advanced before dispatch completed.
        var before = Client.GetContextStatus();
        Assert.That(before.SessionEpoch, Is.EqualTo(epoch));
        var last = before;
        var deadline = DateTime.UtcNow + TimeSpan.FromSeconds(5);
        while (DateTime.UtcNow < deadline)
        {
            await Task.Delay(5);
            var after = Client.GetContextStatus();
            last = after;
            Assert.That(after.SessionEpoch, Is.EqualTo(epoch));
            if (after.FrameSequence <= before.FrameSequence || after.WorldFrameSequence <= before.WorldFrameSequence) continue;
            using var snapshot = JsonDocument.Parse(Client.GetObserveSnapshotJson());
            var document = snapshot.RootElement.GetProperty("document");
            var entries = document.GetProperty("entries").EnumerateArray().ToArray();
            if (document.GetProperty("sessionEpoch").GetUInt64() == epoch &&
                document.GetProperty("uiFrame").GetUInt64() > before.FrameSequence &&
                document.GetProperty("worldFrame").GetUInt64() > before.WorldFrameSequence &&
                entries.Length >= 18 && entries.All(e => e.GetProperty("status").GetString() == "available")) return;
        }
        throw new AssertionException($"No fresh UI/World/Observe publication. before={JsonSerializer.Serialize(before)} last={JsonSerializer.Serialize(last)} observe={Client.GetObserveSnapshotJson()}");
    }

    public async Task Approach(double target, double speed = 245)
    {
        for (var tick = 0; tick < 180; tick++)
        {
            var delta = target - Position().X;
            if (Math.Abs(delta) < 0.005) { await Input("move", 0); return; }
            await Input("move", Math.Clamp(delta / (speed / 60), -1, 1));
            await Step(1);
        }
        throw new AssertionException("Ordinary movement did not reach the fixed regression boundary.");
    }

    public void Evidence(string name)
    {
        foreach (var (suffix, json) in new[] {
            ("observe", Client.GetObserveSnapshotJson()), ("world", Client.GetWorldObjectTreeJson()),
            ("diagnostics", Client.GetDiagnosticsJson()) })
        {
            var path = Path.Combine(Directory, $"{name}-{suffix}.json");
            File.WriteAllText(path, json);
            TestContext.AddTestAttachment(path);
        }
    }

    public void Dispose()
    {
        input?.Dispose(); // Released SDK owner disconnects its held inputs.
        Client.Dispose();
        Host.Dispose();
    }
}
