using System.Diagnostics;
using System.Security.Cryptography;
using System.Text.Json;
using Gua.Core;
using Gua.Testing;
using NUnit.Framework;

namespace Factory.Regression;

/// <summary>Opt-in packaging compatibility check, not a Playtest runner or game acceptance suite.</summary>
[TestFixture, NonParallelizable, Category("ExeMigrationSmoke")]
public sealed class ExeMigrationSmoke
{
    [Test]
    public async Task DevelopmentPackageConnectsAndAcceptsOrdinaryInput()
    {
        var executable = Environment.GetEnvironmentVariable("FACTORY_SMOKE_EXE")
            ?? throw new InvalidOperationException("Set FACTORY_SMOKE_EXE explicitly.");
        Assert.That(System.Net.NetworkInformation.IPGlobalProperties.GetIPGlobalProperties().GetActiveTcpListeners()
            .Any(endpoint => endpoint.Port == 18245), Is.False, "Port 18245 occupied; refusing to attach.");
        var directory = Path.Combine(SourceScene.Root, "output", "exe-migration-smoke", DateTime.UtcNow.ToString("yyyyMMddTHHmmssfff"));
        Directory.CreateDirectory(directory);
        var log = Path.Combine(directory, "startup.log");
        var start = new ProcessStartInfo(executable) { UseShellExecute = false, CreateNoWindow = true };
        foreach (var arg in new[] { "--headless", "--log-file", log }) start.ArgumentList.Add(arg);
        start.Environment["GUA_BRIDGE_PORT"] = "18245";
        start.Environment["FACTORY_SAVE_DIR"] = directory;
        start.Environment["APPDATA"] = Path.Combine(directory, "appdata");
        start.Environment["LOCALAPPDATA"] = Path.Combine(directory, "localappdata");
        Directory.CreateDirectory(start.Environment["APPDATA"]!);
        Directory.CreateDirectory(start.Environment["LOCALAPPDATA"]!);
        using var process = Process.Start(start) ?? throw new InvalidOperationException("EXE did not start");
        try
        {
            var readyDeadline = DateTime.UtcNow.AddSeconds(10);
            var startup = "";
            while (DateTime.UtcNow < readyDeadline && !process.HasExited)
            {
                if (File.Exists(log)) startup = File.ReadAllText(log);
                Assert.That(startup, Does.Not.Contain("ERROR:"));
                if (startup.Contains("FACTORY_READY bridge=ws://127.0.0.1:18245 gua=1.2.0 fixed_clock=false")) break;
                await Task.Delay(20);
            }
            Assert.That(process.HasExited, Is.False, "Owned EXE exited before connection");
            Assert.That(startup, Does.Contain("FACTORY_READY bridge=ws://127.0.0.1:18245 gua=1.2.0 fixed_clock=false"));
            using var client = new GuaWebSocketContext("ws://127.0.0.1:18245");
            client.WaitUntilAvailable(TimeSpan.FromSeconds(10));
            Assert.That(client.GetVersion().GodotPluginVersion, Is.EqualTo("1.2.0"));
            await Task.Delay(100);
            var node = await GuaAssertions.Query(client).ById("start").ResolveAsync();
            node.ToBeVisible().ToBeEnabled();
            using var session = client.CreateGuardedDispatchSession();
            async Task Complete(GuaRemoteDispatchAttempt attempt)
            {
                var deadline = DateTime.UtcNow.AddSeconds(5);
                while (attempt.State == GuaRemoteDispatchState.Enqueued && DateTime.UtcNow < deadline)
                { session.Poll(attempt); await Task.Delay(5); }
                Assert.That(attempt.State, Is.EqualTo(GuaRemoteDispatchState.Completed), attempt.Error);
                Assert.That(attempt.Completion!.Value.GetProperty("succeeded").GetBoolean(), Is.True);
            }
            GuaDispatchGuard Guard(string json)
            {
                using var doc = JsonDocument.Parse(json);
                return new(doc.RootElement.GetProperty("sessionEpoch").GetUInt64(), GuaObservationProfile.Debug,
                    doc.RootElement.GetProperty("revision").GetUInt64(), session.SourceId);
            }
            await Complete(session.SendUi(Guard(client.GetUiTreeJson()), new GuaActionRequest(GuaActionType.Click, "start")));
            double X()
            {
                using var world = JsonDocument.Parse(client.GetWorldObjectTreeJson());
                return world.RootElement.GetProperty("objects").EnumerateArray().Single(x => x.GetProperty("id").GetString() == "robot").GetProperty("position").GetProperty("x").GetDouble();
            }
            await Task.Delay(100);
            var before = X();
            await Complete(session.SendGameInput(Guard(session.GetGameInputActionsJson()),
                new GuaRemoteGameInputRequest("set_game_input_action", "move", 1.0, LeaseMs: 30000)));
            await Task.Delay(150);
            // Scope: one accepted ordinary movement and observable displacement.
            // Release receipt/lease/reconnect cleanup is not certified by this
            // packaging check. Disposal disconnects this SDK owner before kill.
            Assert.That(X(), Is.GreaterThan(before + 1));
            File.WriteAllText(Path.Combine(directory, "observe.json"), client.GetObserveSnapshotJson());
            File.WriteAllText(Path.Combine(directory, "exe-sha256.txt"), Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(executable))));
            Assert.That(File.ReadAllText(log), Does.Not.Contain("ERROR:"));
            TestContext.AddTestAttachment(log);
            TestContext.AddTestAttachment(Path.Combine(directory, "observe.json"));
        }
        finally
        {
            // Only the process created by this small compatibility check is owned here.
            if (!process.HasExited) { process.Kill(); process.WaitForExit(5000); }
        }
    }
}
