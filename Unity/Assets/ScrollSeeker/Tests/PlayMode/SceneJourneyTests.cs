using System.Collections;
using System.IO;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;
namespace ScrollSeeker.Tests
{
    public sealed class SceneJourneyTests
    {
        GameObject root;
        GameSession session;
        string folder;
        [UnitySetUp]
        public IEnumerator SetUp()
        {
            folder = Path.Combine(Path.GetTempPath(), "scroll-seeker-scene-" + System.Guid.NewGuid());
            root = new GameObject("Isolated test session"); root.SetActive(false);
            session = root.AddComponent<GameSession>(); session.SavePathOverride = Path.Combine(folder, "journey.json");
            root.SetActive(true); yield return new WaitForSeconds(.35f);
        }
        [UnityTearDown]
        public IEnumerator TearDown()
        {
            Object.Destroy(root);
            foreach (var go in Object.FindObjectsByType<GameObject>(FindObjectsSortMode.None))
                if (go && go.scene.IsValid() && go.transform.parent == null && (go.name.Contains("Scroll") || go.GetComponent<Camera>() || go.GetComponent<Light>())) Object.Destroy(go);
            yield return null;
            if (Directory.Exists(folder)) Directory.Delete(folder, true);
        }
        [UnityTest]
        public IEnumerator DistantInteractionsDoNotSkipTheJourney()
        {
            var merchant = Find(InteractionKind.Merchant);
            session.Interact(merchant); session.ConfirmDialogue();
            Assert.That(session.Journey.Data.stage, Is.EqualTo(QuestStage.LeaveHome));
            Assert.That(session.Journey.Data.copper, Is.EqualTo(10));
            yield return null;
        }
        [UnityTest]
        public IEnumerator EmptySerializedDialogueCannotPauseFreshJourneyMovement()
        {
            // Older saved scene components encoded null public strings as empty
            // strings. Reproduce that payload without using any player save file.
            string serialized = JsonUtility.ToJson(session);
            Assert.That(serialized, Does.Not.Contain("\"Dialogue\""), "Transient dialogue must not be serialized again.");
            JsonUtility.FromJsonOverwrite("{\"Dialogue\":\"\",\"DialogueTitle\":\"\",\"Toast\":\"\"}", session);
            Assert.That(session.Posture, Is.EqualTo(Posture.Open));
            Assert.That(session.DialogueOpen, Is.False);
            Assert.That(session.Paused, Is.False);
            Vector3 start = session.Player.transform.position;
            session.Player.DrivenDirection = Vector3.right;
            yield return new WaitForSeconds(.25f);
            Assert.That(session.Player.Paused, Is.False);
            Assert.That(Camera.main.GetComponent<OrbitCamera>().Locked, Is.False);
            Assert.That(session.Player.transform.position.x, Is.GreaterThan(start.x + .5f));
            Assert.That(session.Journey.Data.stage, Is.EqualTo(QuestStage.LeaveHome));
        }
        [UnityTest]
        public IEnumerator BookPausesMotorAndResumesAtTheSamePlace()
        {
            session.SetPosture(Posture.Book); yield return null;
            var point = session.Player.transform.position;
            session.Player.DrivenDirection = Vector3.right;
            yield return new WaitForSeconds(.25f);
            Assert.That(Vector3.Distance(point, session.Player.transform.position), Is.LessThan(.08f));
            session.SetPosture(Posture.Open);
            yield return new WaitForSeconds(.25f);
            Assert.That(session.Player.transform.position.x, Is.GreaterThan(point.x + .5f));
        }
        [UnityTest]
        public IEnumerator LaptopRequiresCounterAndCannotFillAtHome()
        {
            session.Journey.Depart(); session.Journey.BuyBottle(); session.SetPosture(Posture.Laptop);
            session.Interact(Find(InteractionKind.Merchant)); session.CompletePour();
            Assert.That(session.Pouring, Is.False);
            Assert.That(session.Journey.Data.emptyBottle, Is.True);
            yield return null;
        }
        [UnityTest]
        public IEnumerator ReadOnlyPosturesRejectDialoguePurchaseAndSealCollection()
        {
            var mother = Find(InteractionKind.Mother);
            var merchant = Find(InteractionKind.Merchant);
            var seal = Find(InteractionKind.Seal);
            var modes = new[] { Posture.Book, Posture.Tent, Posture.Folded };
            session.Player.Teleport(WorldBuilder.MotherPosition + Vector3.back * 1.7f);
            foreach (var mode in modes)
            {
                session.SetPosture(mode);
                session.Interact(mother);
                session.ConfirmDialogue();
                Assert.That(session.DialogueOpen, Is.False, "Dialogue opened behind " + mode);
                Assert.That(session.Journey.Data.stage, Is.EqualTo(QuestStage.LeaveHome));
            }
            session.SetPosture(Posture.Open);
            session.Journey.Depart();
            session.Player.Teleport(WorldBuilder.MerchantPosition + Vector3.back * 1.7f);
            foreach (var mode in modes)
            {
                session.SetPosture(mode);
                session.Interact(merchant);
                session.ConfirmDialogue();
                Assert.That(session.DialogueOpen, Is.False, "Merchant opened behind " + mode);
                Assert.That(session.Journey.Data.stage, Is.EqualTo(QuestStage.FindMerchant));
                Assert.That(session.Journey.Data.copper, Is.EqualTo(10));
            }
            session.Player.Teleport(seal.transform.position + Vector3.up * .2f);
            foreach (var mode in modes)
            {
                session.SetPosture(mode);
                session.Interact(seal);
                Assert.That(session.Journey.Data.keepsakes, Is.Zero, "Seal collected behind " + mode);
                Assert.That(session.Journey.Data.copper, Is.EqualTo(10));
            }
            yield return null;
        }
        [UnityTest]
        public IEnumerator PouringCannotRestartThroughRepeatedInteraction()
        {
            session.Journey.Depart();
            session.Journey.BuyBottle();
            session.Player.Teleport(WorldBuilder.MerchantPosition + Vector3.back * 1.7f);
            session.SetPosture(Posture.Laptop);
            var merchant = Find(InteractionKind.Merchant);
            session.Interact(merchant);
            Assert.That(session.Pouring, Is.True);
            Assert.That(session.Player.Paused, Is.True, "Challenge pause must apply synchronously.");
            Assert.That(Camera.main.GetComponent<OrbitCamera>().Locked, Is.True);
            session.PourProgress = 1.5f;
            session.Balance = .23f;
            session.Interact(merchant);
            Assert.That(session.Pouring, Is.True);
            Assert.That(session.PourProgress, Is.EqualTo(1.5f), "Repeated E must not reset the challenge.");
            Assert.That(session.Balance, Is.EqualTo(.23f));
            Assert.That(session.DialogueOpen, Is.False);
            Assert.That(session.Journey.Data.emptyBottle, Is.True);
            Assert.That(session.Journey.Data.soySauce, Is.False);
            yield return null;
        }
        [UnityTest]
        public IEnumerator OpeningAndClosingDialogueApplyMotorAndCameraPauseSynchronously()
        {
            session.Interact(Find(InteractionKind.Mother));
            Assert.That(session.DialogueOpen, Is.True);
            Assert.That(session.Player.Paused, Is.True, "No Update frame should be needed to pause.");
            Assert.That(Camera.main.GetComponent<OrbitCamera>().Locked, Is.True);
            Vector3 held = session.Player.transform.position;
            session.Player.DrivenDirection = Vector3.right;
            yield return new WaitForSeconds(.25f);
            Assert.That(Vector3.Distance(held, session.Player.transform.position), Is.LessThan(.08f));
            session.CloseDialogue();
            Assert.That(session.Player.Paused, Is.False, "No Update frame should be needed to resume.");
            Assert.That(Camera.main.GetComponent<OrbitCamera>().Locked, Is.False);
            yield return new WaitForSeconds(.25f);
            Assert.That(session.Player.transform.position.x, Is.GreaterThan(held.x + .5f));
            Assert.That(session.Journey.Data.stage, Is.EqualTo(QuestStage.LeaveHome), "Closing must not accept the errand.");
        }
        [UnityTest]
        public IEnumerator BridgeHasAContinuousWalkableSurface()
        {
            // A physical controller traverses every step, testing supports rather than only mesh existence.
            session.Player.Teleport(new Vector3(-8, .2f, 0));
            session.Player.DrivenDirection = Vector3.right;
            float end = Time.realtimeSinceStartup + 7;
            while (session.Player.transform.position.x < 8 && Time.realtimeSinceStartup < end)
            { Assert.That(session.Player.transform.position.y, Is.GreaterThan(-.5f)); yield return null; }
            session.Player.DrivenDirection = Vector3.zero;
            Assert.That(session.Player.transform.position.x, Is.GreaterThanOrEqualTo(8));
        }
        static Interactable Find(InteractionKind kind)
        { foreach (var item in Object.FindObjectsByType<Interactable>(FindObjectsSortMode.None)) if (item.Kind == kind) return item; Assert.Fail("Missing " + kind); return null; }
    }
}
