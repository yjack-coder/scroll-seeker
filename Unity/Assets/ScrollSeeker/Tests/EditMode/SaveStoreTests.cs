using System;
using System.IO;
using NUnit.Framework;
using UnityEngine;

namespace ScrollSeeker.Tests
{
    public sealed class SaveStoreTests
    {
        string directory;
        string path;
        SaveStore store;

        [SetUp]
        public void CreateIsolatedSaveDirectory()
        {
            directory = Path.Combine(Path.GetTempPath(), "scroll-seeker-edit-tests-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(directory);
            path = Path.Combine(directory, "journey.json");
            store = new SaveStore(path);
        }

        [TearDown]
        public void RemoveOnlyThisTestDirectory()
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, true);
        }

        [Test]
        public void MissingSaveStartsFreshWithoutWarningOrWritingFiles()
        {
            JourneyTestData.AssertEqual(new JourneyData(), store.Load());
            Assert.That(store.LastWarning, Is.Null);
            Assert.That(Directory.GetFiles(directory), Is.Empty);
        }

        [Test]
        public void FirstSaveCreatesParentDirectoryAndPublishesOnlyCompletePrimary()
        {
            var nestedPath = Path.Combine(directory, "nested", "journey.json");
            var nestedStore = new SaveStore(nestedPath);
            var data = JourneyTestData.ForStage(QuestStage.FindMerchant);
            Assert.That(nestedStore.Save(data), Is.True);
            Assert.That(File.Exists(nestedPath), Is.True);
            Assert.That(File.Exists(nestedPath + ".tmp"), Is.False);
            Assert.That(File.Exists(nestedPath + ".bak"), Is.False);
            Assert.That(nestedStore.LastWarning, Is.Null);
            JourneyTestData.AssertEqual(data, nestedStore.Load());
        }

        [Test]
        public void EveryStageAndPostureRoundTripsInventoryAndExactWorldPosition(
            [Values] QuestStage stage, [Values] Posture posture)
        {
            var data = JourneyTestData.ForStage(stage, posture);
            data.copper = 29;
            data.keepsakes = 5;
            data.x = -34.5f;
            data.y = 14.75f;
            data.z = 22.5f;
            Assert.That(store.Save(data), Is.True, store.LastWarning);
            var loaded = new SaveStore(path).Load();
            Assert.That(loaded, Is.Not.SameAs(data));
            JourneyTestData.AssertEqual(data, loaded);
            Assert.DoesNotThrow(() => Journey.Validate(loaded));
        }

        [Test]
        public void ReplacingSaveKeepsExactlyThePreviousValidJourneyAsBackup()
        {
            var first = JourneyTestData.ForStage(QuestStage.FindMerchant);
            var second = JourneyTestData.ForStage(QuestStage.FillBottle);
            var third = JourneyTestData.ForStage(QuestStage.ReturnHome);
            second.copper = 6;
            third.copper = 6;
            Assert.That(store.Save(first), Is.True);
            Assert.That(store.Save(second), Is.True);
            JourneyTestData.AssertEqual(first, new SaveStore(path + ".bak").Load());
            Assert.That(store.Save(third), Is.True);
            JourneyTestData.AssertEqual(third, store.Load());
            JourneyTestData.AssertEqual(second, new SaveStore(path + ".bak").Load());
            Assert.That(File.Exists(path + ".tmp"), Is.False);
            Assert.That(Directory.GetFiles(directory).Length, Is.EqualTo(2));
        }

        [Test]
        public void CompletedQuestAndSealRewardsCannotRepeatAfterRestartOrRepeatedSave()
        {
            var journey = new Journey();
            journey.Depart();
            journey.BuyBottle();
            journey.FillBottle();
            journey.Deliver(Posture.Folded, true);
            journey.Collect(0);
            Assert.That(store.Save(journey.Data), Is.True);
            Assert.That(store.Save(journey.Data), Is.True);
            var resumed = new Journey(new SaveStore(path).Load());
            Assert.That(resumed.Deliver(Posture.Folded, true), Is.False);
            Assert.That(resumed.Collect(0), Is.False);
            Assert.That(resumed.BuyBottle(), Is.False);
            Assert.That(resumed.Data.copper, Is.EqualTo(15));
            Assert.That(resumed.Data.keepsakes, Is.EqualTo(1));
            Assert.That(store.Save(resumed.Data), Is.True);
            JourneyTestData.AssertEqual(journey.Data, store.Load());
        }

        [Test]
        public void CappedAwardsStillPersistAndKeepQuestAndSealCompletion()
        {
            var data = JourneyTestData.ForStage(QuestStage.ReturnHome);
            data.copper = Journey.MaxCopper;
            var journey = new Journey(data);
            journey.Collect(2);
            journey.Deliver(Posture.Folded, true);
            Assert.That(store.Save(data), Is.True, store.LastWarning);
            var resumed = new Journey(store.Load());
            Assert.That(resumed.Data.copper, Is.EqualTo(Journey.MaxCopper));
            Assert.That(resumed.Data.stage, Is.EqualTo(QuestStage.Complete));
            Assert.That(resumed.Collect(2), Is.False);
            Assert.That(resumed.Deliver(Posture.Folded, true), Is.False);
        }

        [TestCase("{this is not JSON}")]
        [TestCase("{}")]
        [TestCase("{\"version\":0}")]
        [TestCase("{\"version\":2}")]
        [TestCase("{\"version\":1,\"copper\":-1}")]
        [TestCase("{\"version\":1,\"stage\":3,\"soySauce\":false}")]
        public void CorruptUnsupportedOrInconsistentPrimaryRecoversValidBackup(string invalidJson)
        {
            var recovery = JourneyTestData.ForStage(QuestStage.ReturnHome, Posture.Tent);
            recovery.x = 19;
            recovery.copper = 6;
            File.WriteAllText(path + ".bak", JsonUtility.ToJson(recovery));
            File.WriteAllText(path, invalidJson);
            JourneyTestData.AssertEqual(recovery, store.Load());
            Assert.That(store.LastWarning, Is.EqualTo("Recovered the previous save."));
            Assert.That(File.ReadAllText(path), Is.EqualTo(invalidJson), "Load must not rewrite the damaged source.");
        }

        [Test]
        public void MissingPrimaryCanRecoverBackup()
        {
            var recovery = JourneyTestData.ForStage(QuestStage.FillBottle, Posture.Laptop);
            File.WriteAllText(path + ".bak", JsonUtility.ToJson(recovery));
            JourneyTestData.AssertEqual(recovery, store.Load());
            Assert.That(store.LastWarning, Does.Contain("Recovered"));
        }

        [Test]
        public void SavingAfterRecoveryPreservesLastGoodBackupForAnotherCorruption()
        {
            var recovery = JourneyTestData.ForStage(QuestStage.FillBottle);
            var current = JourneyTestData.ForStage(QuestStage.ReturnHome);
            Assert.That(store.Save(recovery), Is.True);
            Assert.That(store.Save(current), Is.True);
            File.WriteAllText(path, "damaged primary");
            var recovered = store.Load();
            JourneyTestData.AssertEqual(recovery, recovered);
            var backupBytes = File.ReadAllBytes(path + ".bak");
            recovered.posture = Posture.Book;
            Assert.That(store.Save(recovered), Is.True);
            Assert.That(store.LastWarning, Is.Null);
            Assert.That(File.ReadAllBytes(path + ".bak"), Is.EqualTo(backupBytes));
            File.WriteAllText(path, "damaged again");
            JourneyTestData.AssertEqual(recovery, store.Load());
            Assert.That(store.LastWarning, Does.Contain("Recovered"));
        }

        [Test]
        public void ValidPrimaryWinsOverBackupAndClearsPriorRecoveryWarning()
        {
            var primary = JourneyTestData.ForStage(QuestStage.Complete, Posture.Folded);
            var backup = JourneyTestData.ForStage(QuestStage.FindMerchant);
            File.WriteAllText(path + ".bak", JsonUtility.ToJson(backup));
            store.Load();
            Assert.That(store.LastWarning, Is.Not.Null);
            File.WriteAllText(path, JsonUtility.ToJson(primary));
            JourneyTestData.AssertEqual(primary, store.Load());
            Assert.That(store.LastWarning, Is.Null);
        }

        [Test]
        public void InvalidPrimaryAndBackupStartFreshWithWarning()
        {
            File.WriteAllText(path, "broken");
            File.WriteAllText(path + ".bak", "{\"version\":99}");
            JourneyTestData.AssertEqual(new JourneyData(), store.Load());
            Assert.That(store.LastWarning, Is.Not.Null.And.Not.Empty);
        }

        [TestCase(0)]
        [TestCase(2)]
        [TestCase(int.MaxValue)]
        public void UnsupportedVersionWithoutBackupCannotBeLoadedOrSaved(int version)
        {
            var data = new JourneyData { version = version };
            var json = JsonUtility.ToJson(data);
            File.WriteAllText(path, json);
            JourneyTestData.AssertEqual(new JourneyData(), store.Load());
            Assert.That(store.LastWarning, Is.Not.Null);
            Assert.That(store.Save(data), Is.False);
            Assert.That(File.ReadAllText(path), Is.EqualTo(json));
            Assert.That(File.Exists(path + ".tmp"), Is.False);
        }

        [Test]
        public void InvalidStateOrNullSaveCannotOverwriteLastGoodFiles()
        {
            Assert.That(store.Save(new JourneyData()), Is.True);
            Assert.That(store.Save(JourneyTestData.ForStage(QuestStage.FindMerchant)), Is.True);
            var primary = File.ReadAllBytes(path);
            var backup = File.ReadAllBytes(path + ".bak");
            var invalid = JourneyTestData.ForStage(QuestStage.Complete);
            invalid.rewardClaimed = false;
            foreach (var data in new[] { invalid, null })
            {
                Assert.That(store.Save(data), Is.False);
                Assert.That(store.LastWarning, Does.StartWith("Could not save:"));
                Assert.That(File.ReadAllBytes(path), Is.EqualTo(primary));
                Assert.That(File.ReadAllBytes(path + ".bak"), Is.EqualTo(backup));
                Assert.That(File.Exists(path + ".tmp"), Is.False);
            }
        }

        [Test]
        public void BlockedParentDirectoryReportsIoFailureWithoutDestroyingBlockingFile()
        {
            var blockingFile = Path.Combine(directory, "blocked");
            File.WriteAllText(blockingFile, "keep this file");
            var blockedStore = new SaveStore(Path.Combine(blockingFile, "journey.json"));
            Assert.That(blockedStore.Save(new JourneyData()), Is.False);
            Assert.That(blockedStore.LastWarning, Does.StartWith("Could not save:"));
            Assert.That(File.ReadAllText(blockingFile), Is.EqualTo("keep this file"));
        }

        [Test]
        public void FailedAtomicReplacementKeepsPrimaryAndRemovesTemporaryFile()
        {
            var original = JourneyTestData.ForStage(QuestStage.FindMerchant);
            Assert.That(store.Save(original), Is.True);
            var bytes = File.ReadAllBytes(path);
            // An existing directory cannot receive the previous primary as a backup.
            Directory.CreateDirectory(path + ".bak");
            Assert.That(store.Save(JourneyTestData.ForStage(QuestStage.FillBottle)), Is.False);
            Assert.That(store.LastWarning, Does.StartWith("Could not save:"));
            Assert.That(File.ReadAllBytes(path), Is.EqualTo(bytes));
            Assert.That(File.Exists(path + ".tmp"), Is.False);
            JourneyTestData.AssertEqual(original, store.Load());
        }

        [Test]
        public void LockedPrimaryReadRecoversBackupAndDoesNotThrow()
        {
            var original = JourneyTestData.ForStage(QuestStage.FindMerchant);
            Assert.That(store.Save(original), Is.True);
            Assert.That(store.Save(JourneyTestData.ForStage(QuestStage.FillBottle)), Is.True);
            using (var exclusiveHandle = new FileStream(path, FileMode.Open, FileAccess.ReadWrite, FileShare.None))
            {
                JourneyTestData.AssertEqual(original, store.Load());
                Assert.That(store.LastWarning, Does.Contain("Recovered"));
            }
        }
    }
}
