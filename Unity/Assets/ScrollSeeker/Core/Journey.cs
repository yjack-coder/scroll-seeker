using System;
namespace ScrollSeeker
{
    public enum Posture { Open, Folded, Book, Tent, Laptop }
    public enum QuestStage { LeaveHome, FindMerchant, FillBottle, ReturnHome, Complete }

    [Serializable]
    public sealed class JourneyData
    {
        public int version = 1;
        public QuestStage stage;
        public int copper = 10;
        public bool emptyBottle, soySauce, rewardClaimed;
        public int keepsakes;
        public float x = -23, y = 0.2f, z = 0;
        public Posture posture;
    }

    /// <summary>Pure quest rules. Arrival and dialogue alone never pay rewards.</summary>
    public sealed class Journey
    {
        public JourneyData Data { get; }
        public const int SaucePrice = 4, DeliveryReward = 8, MaxCopper = 10000;
        public Journey(JourneyData data = null) { Data = data ?? new JourneyData(); Validate(Data); }
        public static void Validate(JourneyData d)
        {
            if (d == null || d.version != 1 || !Enum.IsDefined(typeof(QuestStage), d.stage) ||
                !Enum.IsDefined(typeof(Posture), d.posture) || d.copper < 0 || d.copper > MaxCopper ||
                d.keepsakes < 0 || d.keepsakes > 7 || !Finite(d.x) || !Finite(d.y) || !Finite(d.z) ||
                Math.Abs(d.x) > 35 || Math.Abs(d.z) > 23 || d.y < -5 || d.y > 15)
                throw new ArgumentException("Invalid journey save");
            bool purchased = d.stage == QuestStage.FillBottle;
            bool returning = d.stage == QuestStage.ReturnHome;
            bool complete = d.stage == QuestStage.Complete;
            if (d.emptyBottle != purchased || d.soySauce != returning || d.rewardClaimed != complete)
                throw new ArgumentException("Inconsistent inventory or reward state");
        }
        static bool Finite(float v) => !float.IsNaN(v) && !float.IsInfinity(v);
        public bool Depart()
        {
            if (Data.stage != QuestStage.LeaveHome) return false;
            Data.stage = QuestStage.FindMerchant; return true;
        }
        public bool BuyBottle()
        {
            if (Data.stage != QuestStage.FindMerchant || Data.copper < SaucePrice) return false;
            Data.copper -= SaucePrice; Data.emptyBottle = true; Data.stage = QuestStage.FillBottle; return true;
        }
        public bool FillBottle()
        {
            if (Data.stage != QuestStage.FillBottle || !Data.emptyBottle) return false;
            Data.emptyBottle = false; Data.soySauce = true; Data.stage = QuestStage.ReturnHome; return true;
        }
        public bool Deliver(Posture posture, bool nearMother)
        {
            if (posture != Posture.Folded || !nearMother || Data.stage != QuestStage.ReturnHome || !Data.soySauce || Data.rewardClaimed) return false;
            Data.soySauce = false; Data.rewardClaimed = true;
            Data.copper = Math.Min(MaxCopper, Data.copper + DeliveryReward); Data.stage = QuestStage.Complete; return true;
        }
        public bool Collect(int index)
        {
            if (index < 0 || index > 2 || (Data.keepsakes & (1 << index)) != 0) return false;
            Data.keepsakes |= 1 << index; Data.copper = Math.Min(MaxCopper, Data.copper + 1); return true;
        }
        public string Objective => Data.stage switch
        {
            QuestStage.LeaveHome => "Speak to Mother at the farmhouse.",
            QuestStage.FindMerchant => "Cross Willow Bridge. Find the soy merchant.",
            QuestStage.FillBottle => "At the counter: use Laptop [5] to fill the bottle.",
            QuestStage.ReturnHome => "Walk home. Fold [2] beside Mother to deliver.",
            _ => "A promise kept. Explore the river and collect ink seals."
        };
    }
}
