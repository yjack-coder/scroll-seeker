using System;
using System.Collections.Generic;
using NUnit.Framework;
using UnityEngine;

namespace ScrollSeeker.Tests
{
    public sealed class JourneyTests
    {
        [Test]
        public void NewJourneyHasUnclaimedQuestAndTenCopper()
        {
            var journey = new Journey();
            Assert.That(journey.Data.stage, Is.EqualTo(QuestStage.LeaveHome));
            Assert.That(journey.Data.copper, Is.EqualTo(10));
            Assert.That(journey.Data.emptyBottle || journey.Data.soySauce || journey.Data.rewardClaimed, Is.False);
            Assert.That(journey.Data.keepsakes, Is.Zero);
            Assert.DoesNotThrow(() => Journey.Validate(journey.Data));
        }

        [Test]
        public void DepartureOnlyOpensMerchantObjectiveAndCannotRepeat()
        {
            var journey = new Journey();
            Assert.That(journey.Depart(), Is.True);
            Assert.That(journey.Data.stage, Is.EqualTo(QuestStage.FindMerchant));
            Assert.That(journey.Data.copper, Is.EqualTo(10));
            var after = JsonUtility.ToJson(journey.Data);
            Assert.That(journey.Depart(), Is.False);
            Assert.That(JsonUtility.ToJson(journey.Data), Is.EqualTo(after));
        }

        [Test]
        public void ArrivalAndPostureChangesDoNotGrantQuestRewards()
        {
            var journey = new Journey(JourneyTestData.ForStage(QuestStage.FindMerchant));
            foreach (Posture posture in Enum.GetValues(typeof(Posture)))
            {
                // Position and selected posture are the only data changed by exploration.
                journey.Data.x = 20;
                journey.Data.z = -8;
                journey.Data.posture = posture;
                Journey.Validate(journey.Data);
                Assert.That(journey.Data.stage, Is.EqualTo(QuestStage.FindMerchant));
                Assert.That(journey.Data.copper, Is.EqualTo(10));
                Assert.That(journey.Data.rewardClaimed || journey.Data.emptyBottle || journey.Data.soySauce, Is.False);
            }
            journey.Data.x = -23;
            journey.Data.z = 0;
            Assert.That(journey.Deliver(Posture.Folded, true), Is.False);
            Assert.That(journey.Data.copper, Is.EqualTo(10));
        }

        [TestCase(0)]
        [TestCase(Journey.SaucePrice - 1)]
        public void PurchaseRequiresEnoughCopperAndLeavesStateIntact(int copper)
        {
            var data = JourneyTestData.ForStage(QuestStage.FindMerchant);
            data.copper = copper;
            var journey = new Journey(data);
            var before = JsonUtility.ToJson(data);
            Assert.That(journey.BuyBottle(), Is.False);
            Assert.That(JsonUtility.ToJson(data), Is.EqualTo(before));
        }

        [Test]
        public void PurchaseChargesExactlyOnceAndAcceptsExactPrice()
        {
            var data = JourneyTestData.ForStage(QuestStage.FindMerchant);
            data.copper = Journey.SaucePrice;
            var journey = new Journey(data);
            Assert.That(journey.BuyBottle(), Is.True);
            Assert.That(data.copper, Is.Zero);
            Assert.That(data.stage, Is.EqualTo(QuestStage.FillBottle));
            Assert.That(data.emptyBottle, Is.True);
            Assert.That(data.soySauce || data.rewardClaimed, Is.False);
            var after = JsonUtility.ToJson(data);
            Assert.That(journey.BuyBottle(), Is.False);
            Assert.That(JsonUtility.ToJson(data), Is.EqualTo(after));
            Assert.DoesNotThrow(() => Journey.Validate(data));
        }

        [Test]
        public void FillingConsumesEmptyBottleAndNeverPaysCopper()
        {
            var journey = new Journey(JourneyTestData.ForStage(QuestStage.FillBottle));
            Assert.That(journey.FillBottle(), Is.True);
            Assert.That(journey.Data.emptyBottle, Is.False);
            Assert.That(journey.Data.soySauce, Is.True);
            Assert.That(journey.Data.stage, Is.EqualTo(QuestStage.ReturnHome));
            Assert.That(journey.Data.copper, Is.EqualTo(10));
            var after = JsonUtility.ToJson(journey.Data);
            Assert.That(journey.FillBottle(), Is.False);
            Assert.That(JsonUtility.ToJson(journey.Data), Is.EqualTo(after));
        }

        [TestCase(Posture.Open, true)]
        [TestCase(Posture.Book, true)]
        [TestCase(Posture.Tent, true)]
        [TestCase(Posture.Laptop, true)]
        [TestCase(Posture.Folded, false)]
        public void DeliveryRequiresFoldedPostureAndMotherProximity(Posture posture, bool nearMother)
        {
            var journey = new Journey(JourneyTestData.ForStage(QuestStage.ReturnHome));
            var before = JsonUtility.ToJson(journey.Data);
            Assert.That(journey.Deliver(posture, nearMother), Is.False);
            Assert.That(JsonUtility.ToJson(journey.Data), Is.EqualTo(before));
        }

        [Test]
        public void DeliveryConsumesSauceAndAwardsEightCopperExactlyOnce()
        {
            var journey = new Journey(JourneyTestData.ForStage(QuestStage.ReturnHome));
            Assert.That(journey.Deliver(Posture.Folded, true), Is.True);
            Assert.That(journey.Data.stage, Is.EqualTo(QuestStage.Complete));
            Assert.That(journey.Data.soySauce || journey.Data.emptyBottle, Is.False);
            Assert.That(journey.Data.rewardClaimed, Is.True);
            Assert.That(journey.Data.copper, Is.EqualTo(10 + Journey.DeliveryReward));
            var after = JsonUtility.ToJson(journey.Data);
            Assert.That(journey.Deliver(Posture.Folded, true), Is.False);
            Assert.That(JsonUtility.ToJson(journey.Data), Is.EqualTo(after));
            Assert.DoesNotThrow(() => Journey.Validate(journey.Data));
        }

        [TestCaseSource(nameof(WrongStageActions))]
        public void OutOfOrderActionsCannotSkipQuestOrModifyInventory(QuestStage stage, string action)
        {
            var journey = new Journey(JourneyTestData.ForStage(stage));
            var before = JsonUtility.ToJson(journey.Data);
            bool result = action == "depart" ? journey.Depart() :
                action == "buy" ? journey.BuyBottle() :
                action == "fill" ? journey.FillBottle() : journey.Deliver(Posture.Folded, true);
            Assert.That(result, Is.False);
            Assert.That(JsonUtility.ToJson(journey.Data), Is.EqualTo(before));
        }

        static IEnumerable<TestCaseData> WrongStageActions()
        {
            var allowed = new Dictionary<string, QuestStage>
            {
                { "depart", QuestStage.LeaveHome }, { "buy", QuestStage.FindMerchant },
                { "fill", QuestStage.FillBottle }, { "deliver", QuestStage.ReturnHome }
            };
            foreach (var action in allowed)
                foreach (QuestStage stage in Enum.GetValues(typeof(QuestStage)))
                    if (stage != action.Value)
                        yield return new TestCaseData(stage, action.Key).SetName($"Reject_{action.Key}_during_{stage}");
        }

        [TestCase(-1)]
        [TestCase(3)]
        [TestCase(int.MinValue)]
        [TestCase(int.MaxValue)]
        public void SealIndexMustIdentifyAnExistingSeal(int index)
        {
            var journey = new Journey();
            var before = JsonUtility.ToJson(journey.Data);
            Assert.That(journey.Collect(index), Is.False);
            Assert.That(JsonUtility.ToJson(journey.Data), Is.EqualTo(before));
        }

        [Test]
        public void ThreeDistinctSealsEachAwardOneCopperAndCannotBeCollectedTwice()
        {
            var journey = new Journey();
            foreach (var index in new[] { 2, 0, 1 })
            {
                int copper = journey.Data.copper;
                Assert.That(journey.Collect(index), Is.True);
                Assert.That(journey.Data.keepsakes & (1 << index), Is.Not.Zero);
                Assert.That(journey.Data.copper, Is.EqualTo(copper + 1));
                Assert.That(journey.Collect(index), Is.False);
                Assert.That(journey.Data.copper, Is.EqualTo(copper + 1));
            }
            Assert.That(journey.Data.keepsakes, Is.EqualTo(7));
            Assert.That(journey.Data.copper, Is.EqualTo(13));
            Assert.That(journey.Data.stage, Is.EqualTo(QuestStage.LeaveHome));
            Assert.DoesNotThrow(() => Journey.Validate(journey.Data));
        }

        [TestCase(Journey.MaxCopper)]
        [TestCase(Journey.MaxCopper - 1)]
        public void AwardsSaturateAtSaveableCopperLimitWithoutLosingCompletion(int copper)
        {
            var data = JourneyTestData.ForStage(QuestStage.ReturnHome);
            data.copper = copper;
            var journey = new Journey(data);
            Assert.That(journey.Collect(0), Is.True);
            Assert.That(journey.Deliver(Posture.Folded, true), Is.True);
            Assert.That(data.copper, Is.EqualTo(Journey.MaxCopper));
            Assert.That(data.rewardClaimed, Is.True);
            Assert.That(data.keepsakes, Is.EqualTo(1));
            Assert.DoesNotThrow(() => Journey.Validate(data));
        }

        [Test]
        public void FullQuestLoopPaysOnlyForDeliveryAndSeals()
        {
            var journey = new Journey();
            Assert.That(journey.Depart(), Is.True);
            Assert.That(journey.BuyBottle(), Is.True);
            Assert.That(journey.Data.copper, Is.EqualTo(6));
            Assert.That(journey.FillBottle(), Is.True);
            Assert.That(journey.Data.copper, Is.EqualTo(6));
            Assert.That(journey.Deliver(Posture.Folded, true), Is.True);
            for (int i = 0; i < 3; i++) Assert.That(journey.Collect(i), Is.True);
            Assert.That(journey.Data.copper, Is.EqualTo(17));
            Assert.That(journey.Data.stage, Is.EqualTo(QuestStage.Complete));
            Assert.DoesNotThrow(() => Journey.Validate(journey.Data));
        }

        [Test]
        public void EveryStageAcceptsOnlyItsMatchingInventoryAndRewardFlags([Values] QuestStage stage)
        {
            var valid = JourneyTestData.ForStage(stage);
            Assert.DoesNotThrow(() => Journey.Validate(valid));
            foreach (string flag in new[] { "bottle", "sauce", "reward" })
            {
                var invalid = JourneyTestData.ForStage(stage);
                if (flag == "bottle") invalid.emptyBottle = !invalid.emptyBottle;
                if (flag == "sauce") invalid.soySauce = !invalid.soySauce;
                if (flag == "reward") invalid.rewardClaimed = !invalid.rewardClaimed;
                Assert.Throws<ArgumentException>(() => Journey.Validate(invalid), $"Stage {stage}, flag {flag}");
            }
        }

        [TestCaseSource(nameof(InvalidSaves))]
        public void InvalidSaveValuesAreRejected(JourneyData data)
        {
            Assert.Throws<ArgumentException>(() => Journey.Validate(data));
            if (data != null) Assert.Throws<ArgumentException>(() => new Journey(data));
        }

        static IEnumerable<TestCaseData> InvalidSaves()
        {
            yield return new TestCaseData(new object[] { null }).SetName("Reject_null_data");
            var changes = new Dictionary<string, Action<JourneyData>>
            {
                { "old_version", d => d.version = 0 }, { "future_version", d => d.version = 2 },
                { "negative_stage", d => d.stage = (QuestStage)(-1) }, { "unknown_stage", d => d.stage = (QuestStage)5 },
                { "negative_posture", d => d.posture = (Posture)(-1) }, { "unknown_posture", d => d.posture = (Posture)5 },
                { "negative_copper", d => d.copper = -1 }, { "too_many_copper", d => d.copper = Journey.MaxCopper + 1 },
                { "negative_seals", d => d.keepsakes = -1 }, { "unknown_seal_bit", d => d.keepsakes = 8 },
                { "nan_x", d => d.x = float.NaN }, { "nan_y", d => d.y = float.NaN }, { "nan_z", d => d.z = float.NaN },
                { "infinite_x", d => d.x = float.PositiveInfinity }, { "infinite_y", d => d.y = float.NegativeInfinity },
                { "infinite_z", d => d.z = float.PositiveInfinity },
                { "x_below_world", d => d.x = -35.01f }, { "x_above_world", d => d.x = 35.01f },
                { "y_below_world", d => d.y = -5.01f }, { "y_above_world", d => d.y = 15.01f },
                { "z_below_world", d => d.z = -23.01f }, { "z_above_world", d => d.z = 23.01f }
            };
            foreach (var change in changes)
            {
                var data = new JourneyData();
                change.Value(data);
                yield return new TestCaseData(data).SetName("Reject_" + change.Key);
            }
        }

        [TestCase(-35, -5, -23, 0, 0)]
        [TestCase(35, 15, 23, Journey.MaxCopper, 7)]
        public void InclusiveWorldAndInventoryBoundsRemainValid(float x, float y, float z, int copper, int seals)
        {
            var data = new JourneyData { x = x, y = y, z = z, copper = copper, keepsakes = seals };
            Assert.DoesNotThrow(() => Journey.Validate(data));
        }
    }

    internal static class JourneyTestData
    {
        internal static JourneyData ForStage(QuestStage stage, Posture posture = Posture.Open)
        {
            return new JourneyData
            {
                stage = stage, posture = posture,
                emptyBottle = stage == QuestStage.FillBottle,
                soySauce = stage == QuestStage.ReturnHome,
                rewardClaimed = stage == QuestStage.Complete
            };
        }

        internal static void AssertEqual(JourneyData expected, JourneyData actual)
        {
            Assert.That(actual.version, Is.EqualTo(expected.version));
            Assert.That(actual.stage, Is.EqualTo(expected.stage));
            Assert.That(actual.copper, Is.EqualTo(expected.copper));
            Assert.That(actual.emptyBottle, Is.EqualTo(expected.emptyBottle));
            Assert.That(actual.soySauce, Is.EqualTo(expected.soySauce));
            Assert.That(actual.rewardClaimed, Is.EqualTo(expected.rewardClaimed));
            Assert.That(actual.keepsakes, Is.EqualTo(expected.keepsakes));
            Assert.That(actual.posture, Is.EqualTo(expected.posture));
            Assert.That(actual.x, Is.EqualTo(expected.x).Within(0.0001f));
            Assert.That(actual.y, Is.EqualTo(expected.y).Within(0.0001f));
            Assert.That(actual.z, Is.EqualTo(expected.z).Within(0.0001f));
        }
    }
}
