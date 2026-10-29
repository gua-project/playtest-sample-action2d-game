using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Nodes;
using NUnit.Framework;

namespace Factory.Regression;

[TestFixture, NonParallelizable, Category("SourceRegression")]
public sealed class FactoryRegressionTests
{
    private SourceScene scene = null!;
    private string directory = "";

    [SetUp]
    public void OpenSourceScene()
    {
        scene = null!; // A failed constructor must not leave the previous disposed test host.
        var name = string.Concat(TestContext.CurrentContext.Test.Name.Select(c => char.IsLetterOrDigit(c) ? c : '_'));
        directory = Path.Combine(SourceScene.Root, "output", "source-regression", DateTime.UtcNow.ToString("yyyyMMddTHHmmssfff") + "-" + name);
        scene = new SourceScene(directory);
    }

    [TearDown]
    public void CaptureAndClose()
    {
        if (scene == null) return;
        try { scene.Evidence("final"); }
        finally { scene.Dispose(); }
    }

    [Test]
    public async Task MenuPauseSaveLoadAndSourceRestart()
    {
        await scene.Start(); await scene.Step(6); await scene.Click("pause");
        var savedFrame = scene.State().GetProperty("frame").GetInt64();
        var savedPosition = scene.Position();
        await scene.Step(60);
        Assert.That(scene.State().GetProperty("frame").GetInt64(), Is.EqualTo(savedFrame));
        await scene.Click("save");
        await scene.Click("resume"); await scene.Input("move", 1); await scene.Step(30); await scene.Release();
        Assert.That(scene.Position().X, Is.GreaterThan(savedPosition.X));
        await scene.Click("pause"); await scene.Click("language"); await scene.Click("size");
        Assert.That(ResumeLabel(), Is.EqualTo("Resume"));
        AssertSettings("en", 1);
        await scene.Click("load");
        AssertSavedState(savedFrame, savedPosition);
        Assert.That(ResumeLabel(), Is.EqualTo("再開"));
        AssertSettings("ja", 0);
        scene.Evidence("loaded");
        scene.Dispose();
        scene = null!;
        scene = new SourceScene(directory, "restarted-source-scene");
        Assert.That(scene.State().GetProperty("mode").GetString(), Is.EqualTo("title"));
        await scene.Click("load");
        AssertSavedState(savedFrame, savedPosition);
        Assert.That(ResumeLabel(), Is.EqualTo("再開"));
        AssertSettings("ja", 0);
        await scene.Click("reset");
        Assert.That(scene.State().GetProperty("mode").GetString(), Is.EqualTo("title"));
        Assert.That(scene.State().GetProperty("seed").GetInt64(), Is.EqualTo(112));
    }

    private void AssertSettings(string locale, int size)
    {
        using var settings = JsonDocument.Parse(File.ReadAllText(Path.Combine(directory, "settings.json")));
        Assert.That(settings.RootElement.GetProperty("locale").GetString(), Is.EqualTo(locale));
        Assert.That(settings.RootElement.GetProperty("size").GetDouble(), Is.EqualTo(size));
    }

    private string? ResumeLabel()
    {
        using var ui = JsonDocument.Parse(scene.Client.GetUiTreeJson());
        return ui.RootElement.GetProperty("nodes").EnumerateArray().Single(n => n.GetProperty("id").GetString() == "resume").GetProperty("label").GetString();
    }

    private void AssertSavedState(long frame, (double X, double Y) position)
    {
        var state = scene.State();
        Assert.That(state.GetProperty("frame").GetInt64(), Is.EqualTo(frame));
        Assert.That(state.GetProperty("paused").GetBoolean(), Is.True);
        Assert.That(scene.Position(), Is.EqualTo(position));
    }

    [Test]
    public async Task LanguageMenusFitTheLogicalViewport()
    {
        AssertVisibleBounds(); await scene.Click("language"); AssertVisibleBounds();
        await scene.Start(); AssertVisibleBounds();
        await scene.Click("pause"); AssertVisibleBounds();
        await scene.Click("language"); AssertVisibleBounds();
        PrepareDockSave(128, ""); await scene.Click("load");
        await scene.Click("resume"); await scene.Input("move", 1); await scene.Step(1); await scene.Release();
        Assert.That(scene.State().GetProperty("mode").GetString(), Is.EqualTo("result"));
        AssertVisibleBounds(); await scene.Click("language"); AssertVisibleBounds();
    }

    private void AssertVisibleBounds()
    {
        using var ui = JsonDocument.Parse(scene.Client.GetUiTreeJson());
        var visible = ui.RootElement.GetProperty("nodes").EnumerateArray().Where(n => n.GetProperty("visible").GetBoolean()).ToArray();
        Assert.That(visible, Is.Not.Empty);
        foreach (var node in visible)
        {
            var bounds = node.GetProperty("bounds");
            Assert.That(bounds.GetProperty("x").GetDouble(), Is.GreaterThanOrEqualTo(0), node.GetProperty("id").GetString());
            Assert.That(bounds.GetProperty("y").GetDouble(), Is.GreaterThanOrEqualTo(0));
            Assert.That(bounds.GetProperty("x").GetDouble() + bounds.GetProperty("w").GetDouble(), Is.LessThanOrEqualTo(1152));
            Assert.That(bounds.GetProperty("y").GetDouble() + bounds.GetProperty("h").GetDouble(), Is.LessThanOrEqualTo(720));
        }
    }

    [Test]
    public async Task InvalidSaveDoesNotChangeTheLiveState()
    {
        await scene.Start(); await scene.Step(3); await scene.Click("pause");
        var before = scene.State(); var position = scene.Position();
        File.WriteAllText(Path.Combine(directory, "factory-save.json"), "{broken-json");
        await scene.Click("load");
        Assert.That(scene.State().GetRawText(), Is.EqualTo(before.GetRawText()));
        Assert.That(scene.Position(), Is.EqualTo(position));
        Assert.That(scene.Client.GetUiTreeJson(), Does.Contain("LOAD ERROR"));
    }

    [TestCase(2, true), TestCase(8, false)]
    public async Task EdgeJumpRespectsCoyoteBoundary(int delayTicks, bool shouldJump)
    {
        await scene.Start(); await scene.Approach(505); await scene.Input("move", 1);
        for (var i = 0; i < 5 && scene.State().GetProperty("grounded").GetBoolean(); i++) { await scene.Input("move", 1); await scene.Step(1); }
        Assert.That(scene.State().GetProperty("grounded").GetBoolean(), Is.False);
        await scene.Step(delayTicks); await scene.Input("move", 0);
        var before = scene.Position(); scene.Evidence("before-jump");
        await scene.Input("jump", true); await scene.Step(1); await scene.Release();
        var after = scene.Position();
        Assert.That(shouldJump ? after.Y < before.Y : after.Y > before.Y, Is.True);
        Assert.That(scene.State().GetProperty("deaths").GetInt64(), Is.Zero);
    }

    [Test]
    public async Task DeathThenPauseDefersExactlyOneRespawn()
    {
        await scene.Start(); await scene.Input("move", 1);
        for (var i = 0; i < 300 && scene.State().GetProperty("deaths").GetInt64() == 0; i++) { await scene.Input("move", 1); await scene.Step(1); }
        Assert.That(scene.State().GetProperty("deaths").GetInt64(), Is.EqualTo(1));
        Assert.That(scene.State().GetProperty("pending_respawn").GetBoolean(), Is.True);
        await scene.Release(); await scene.Click("pause");
        var frame = scene.State().GetProperty("frame").GetInt64();
        await scene.Step(60);
        Assert.That(scene.State().GetProperty("frame").GetInt64(), Is.EqualTo(frame));
        Assert.That(scene.State().GetProperty("pending_respawn").GetBoolean(), Is.True);
        await scene.Click("resume"); await scene.Step(1);
        Assert.That(scene.State().GetProperty("pending_respawn").GetBoolean(), Is.False);
        Assert.That(scene.Position(), Is.EqualTo((64.0, 478.0)));
        await scene.Step(5);
        Assert.That(scene.State().GetProperty("deaths").GetInt64(), Is.EqualTo(1));
        Assert.That(scene.State().GetProperty("softlocked").GetBoolean(), Is.False);
    }

    [TestCase("", false, false)]
    [TestCase("B01_PLATFORM_RESPAWN", true, false)]
    [TestCase("B02_CARGO_LOSS", false, true)]
    public async Task CargoFallDetectsOnlyTheSelectedKnownBug(string bug, bool softlocked, bool cargoLost)
    {
        await scene.Start(bug); await scene.Approach(145); await scene.Input("interact", true); await scene.Step(1); await scene.Release();
        Assert.That(scene.State().GetProperty("carrying").GetBoolean(), Is.True);
        await scene.Input("move", 1);
        for (var i = 0; i < 350 && scene.State().GetProperty("deaths").GetInt64() == 0; i++) { await scene.Input("move", 1); await scene.Step(2); }
        await scene.Release(); await scene.Step(2);
        var state = scene.State();
        Assert.That(state.GetProperty("deaths").GetInt64(), Is.EqualTo(1));
        Assert.That(state.GetProperty("softlocked").GetBoolean(), Is.EqualTo(softlocked));
        Assert.That(state.GetProperty("cargo_lost").GetBoolean(), Is.EqualTo(cargoLost));
        Assert.That(state.GetProperty("carrying").GetBoolean(), Is.False);
        Assert.That(state.GetProperty("bugs").GetArrayLength(), Is.EqualTo(bug == "" ? 0 : 1));
        if (!softlocked) Assert.That(scene.Position(), Is.EqualTo((64.0, 478.0)));
        if (!cargoLost && !softlocked) Assert.That(scene.Position("cargo").Y, Is.LessThanOrEqualTo(500));
    }

    [TestCase("", 2, 3), TestCase("B03_DOUBLE_RESULT", 3, 4)]
    public async Task PreparedDockContactGivesDeathPriorityUnlessBugEnabled(string bug, int deliveries, int outcomes)
    {
        PrepareDockSave(67, bug);
        await scene.Click("load"); AssertDockFixture(67);
        scene.Evidence("prepared-contact");
        await scene.Click("resume"); await scene.Input("move", 1); await scene.Step(1); await scene.Release();
        var state = scene.State();
        Assert.That(state.GetProperty("deaths").GetInt64(), Is.EqualTo(1));
        Assert.That(state.GetProperty("deliveries").GetInt64(), Is.EqualTo(deliveries));
        Assert.That(state.GetProperty("outcomes").GetInt64(), Is.EqualTo(outcomes));
    }

    [Test]
    public async Task ResultScreenReplayResetsProgress()
    {
        PrepareDockSave(128, ""); // Safe press phase. This tests the final transition, not a full journey.
        await scene.Click("load"); AssertDockFixture(128);
        await scene.Click("resume"); await scene.Input("move", 1); await scene.Step(1); await scene.Release();
        Assert.That(scene.State().GetProperty("mode").GetString(), Is.EqualTo("result"));
        Assert.That(scene.State().GetProperty("deliveries").GetInt64(), Is.EqualTo(3));
        Assert.That(scene.State().GetProperty("deaths").GetInt64(), Is.Zero);
        await scene.Click("replay");
        Assert.That(scene.State().GetProperty("mode").GetString(), Is.EqualTo("play"));
        Assert.That(scene.State().GetProperty("stage").GetInt64(), Is.Zero);
        Assert.That(scene.State().GetProperty("deliveries").GetInt64(), Is.Zero);
        Assert.That(scene.Position(), Is.EqualTo((64.0, 478.0)));
    }

    private void PrepareDockSave(int frame, string bug)
    {
        var fixturePath = Path.Combine(SourceScene.Root, "tests", "fixtures", "dock-save.json");
        TestContext.WriteLine("Prepared save SHA256: " + Convert.ToHexStringLower(SHA256.HashData(File.ReadAllBytes(fixturePath))));
        var document = JsonNode.Parse(File.ReadAllText(fixturePath))!;
        document["game"]!["frame"] = frame;
        document["game"]!["bugs"] = bug == "" ? new JsonArray() : new JsonArray(JsonValue.Create(bug));
        var savePath = Path.Combine(directory, "factory-save.json");
        File.WriteAllText(savePath, document.ToJsonString());
        TestContext.AddTestAttachment(savePath, "Explicit prepared initial condition; not normal full-play evidence.");
    }

    private void AssertDockFixture(int frame)
    {
        var state = scene.State();
        Assert.That(state.GetProperty("stage").GetInt64(), Is.EqualTo(2));
        Assert.That(state.GetProperty("frame").GetInt64(), Is.EqualTo(frame));
        Assert.That(state.GetProperty("carrying").GetBoolean(), Is.True);
        Assert.That(state.GetProperty("paused").GetBoolean(), Is.True);
        Assert.That(state.GetProperty("deliveries").GetInt64(), Is.EqualTo(2));
        Assert.That(scene.Position(), Is.EqualTo((1499.0, 478.0)));
    }
}
