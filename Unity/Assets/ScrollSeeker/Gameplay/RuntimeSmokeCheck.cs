#if UNITY_EDITOR || DEVELOPMENT_BUILD
using System;
using System.Collections;
using System.IO;
using UnityEngine;
namespace ScrollSeeker
{
    /// <summary>Opt-in real-scene route check, isolated via -seekerSavePath. Never runs in ordinary play.</summary>
    public sealed class RuntimeSmokeCheck : MonoBehaviour
    {
        GameSession session;
        string directory;
        int checks;
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Boot()
        {
            var args = Environment.GetCommandLineArgs();
            if (Array.IndexOf(args, "-seekerSmokeTest") < 0) return;
            if (Array.IndexOf(args, "-seekerSavePath") < 0)
            { Debug.LogError("Smoke test requires a separate -seekerSavePath"); return; }
            new GameObject("Explicit runtime verification").AddComponent<RuntimeSmokeCheck>();
        }
        IEnumerator Start()
        {
            session = FindFirstObjectByType<GameSession>();
            directory = Path.Combine(Path.GetDirectoryName(session.SavePath), "screenshots");
            Directory.CreateDirectory(directory);
            Application.logMessageReceived += OnLog;
            yield return null;
            Check(session.Journey.Data.stage == QuestStage.LeaveHome, "fresh isolated journey");
            Check(!session.DialogueOpen && !session.Paused, "serialized scene starts ready to explore");
            yield return Shot("01-home");
            // Use the same interaction and movement routes as gameplay, without teleporting.
            yield return WalkTo(WorldBuilder.MotherPosition + Vector3.back * 1.7f);
            session.Interact(Find(InteractionKind.Mother)); session.ConfirmDialogue();
            Check(session.Journey.Data.stage == QuestStage.FindMerchant, "mother starts errand");
            Vector3 held = session.Player.transform.position;
            foreach (Posture posture in Enum.GetValues(typeof(Posture)))
            { session.SetPosture(posture); yield return null; Check(Vector3.Distance(held, session.Player.transform.position) < .08f, "pose preserves position " + posture); }
            session.SetPosture(Posture.Open);
            yield return WalkTo(new Vector3(-8, .1f, 0));
            yield return Shot("02-river");
            yield return WalkTo(new Vector3(8, .1f, 0));
            Check(session.Player.transform.position.y > -.2f, "bridge supports player");
            yield return Shot("03-bridge");
            yield return WalkTo(WorldBuilder.MerchantPosition + Vector3.back * 1.7f);
            session.Interact(Find(InteractionKind.Merchant)); session.ConfirmDialogue();
            Check(session.Journey.Data.copper == 6 && session.Journey.Data.emptyBottle, "purchase debits once");
            session.SetPosture(Posture.Laptop); session.Interact(Find(InteractionKind.Merchant));
            Check(session.Pouring, "Laptop starts fill challenge");
            yield return Shot("04a-pouring");
            float timeout = Time.realtimeSinceStartup + 10;
            while (session.Pouring && Time.realtimeSinceStartup < timeout)
            { session.Balance = session.PourTarget; yield return null; }
            Check(session.Journey.Data.soySauce && session.Journey.Data.stage == QuestStage.ReturnHome, "real timed pour completes");
            yield return Shot("04-merchant");
            session.SetPosture(Posture.Book); yield return Shot("04b-journal");
            session.SetPosture(Posture.Folded); session.Deliver();
            Check(session.Journey.Data.stage == QuestStage.ReturnHome, "remote fold cannot deliver");
            session.SetPosture(Posture.Open);
            yield return WalkTo(new Vector3(8, .1f, 0));
            yield return WalkTo(new Vector3(-8, .1f, 0));
            yield return WalkTo(WorldBuilder.MotherPosition + Vector3.back * 1.7f);
            session.SetPosture(Posture.Folded); session.Deliver();
            Check(session.Journey.Data.stage == QuestStage.Complete && session.Journey.Data.copper == 14, "home delivery pays eight copper");
            session.Deliver(); Check(session.Journey.Data.copper == 14, "delivery reward is idempotent");
            yield return Shot("05-homecoming");
            session.SetPosture(Posture.Tent); yield return Shot("06-shadow-theater");
            session.SetPosture(Posture.Open);
            yield return WalkTo(new Vector3(-14, .1f, -9));
            Interactable seal = null;
            foreach (var item in FindObjectsByType<Interactable>(FindObjectsSortMode.None))
                if (item.Kind == InteractionKind.Seal && item.SealIndex == 0) seal = item;
            session.Interact(seal);
            Check(session.Journey.Data.keepsakes == 1 && session.Journey.Data.copper == 15, "scene seal collection rewards once");
            session.Interact(seal);
            Check(session.Journey.Data.copper == 15, "scene seal cannot repeat");
            yield return Shot("07-ink-seal");
            Check(session.Save(), "final save succeeds");
            var recovered = new Journey(new SaveStore(session.SavePath).Load());
            Check(recovered.Data.stage == QuestStage.Complete && recovered.Data.copper == 15 && recovered.Data.rewardClaimed, "disk reload preserves reward");
            File.WriteAllText(Path.Combine(Path.GetDirectoryName(session.SavePath), "runtime-result.json"), "{\"passed\":true,\"checks\":" + checks + ",\"route\":\"walked home-bridge-merchant-bridge-home\",\"copper\":15}");
            Debug.Log("SCROLL_SEEKER_RUNTIME_PASS " + checks);
            Application.logMessageReceived -= OnLog;
            Application.Quit(0);
        }
        IEnumerator WalkTo(Vector3 target)
        {
            float limit = Time.realtimeSinceStartup + 30;
            while (true)
            {
                Vector3 delta = target - session.Player.transform.position; delta.y = 0;
                if (delta.magnitude < .18f) break;
                if (Time.realtimeSinceStartup > limit) { Check(false, "route blocked at " + session.Player.transform.position + " toward " + target); yield break; }
                session.Player.DrivenDirection = delta.normalized;
                yield return null;
            }
            session.Player.DrivenDirection = Vector3.zero; yield return null;
        }
        IEnumerator Shot(string name)
        {
            yield return new WaitForSeconds(.5f);
            yield return new WaitForEndOfFrame();
            ScreenCapture.CaptureScreenshot(Path.Combine(directory, name + ".png"));
            yield return null;
        }
        Interactable Find(InteractionKind kind)
        { foreach (var item in FindObjectsByType<Interactable>(FindObjectsSortMode.None)) if (item.Kind == kind) return item; return null; }
        void Check(bool condition, string label)
        {
            if (!condition) { Debug.LogError("SCROLL_SEEKER_RUNTIME_FAIL " + label); throw new InvalidOperationException(label); }
            checks++; Debug.Log("SCROLL_SEEKER_CHECK " + label);
        }
        void OnLog(string message, string trace, LogType type)
        {
            if (type != LogType.Exception && type != LogType.Error) return;
            File.WriteAllText(Path.Combine(Path.GetDirectoryName(session.SavePath), "runtime-failure.txt"), message + "\n" + trace);
            Application.logMessageReceived -= OnLog; Application.Quit(1);
        }
    }
}
#endif
