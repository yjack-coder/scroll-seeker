using System;
using System.IO;
using UnityEngine;
namespace ScrollSeeker
{
    [DefaultExecutionOrder(-100)]
    public sealed class GameSession : MonoBehaviour
    {
        [Tooltip("Optional isolated save destination for automated scene checks.")]
        public string SavePathOverride;
        public Journey Journey { get; private set; }
        public ThirdPersonMotor Player { get; private set; }
        public Posture Posture => Journey.Data.posture;
        public Interactable Nearby { get; private set; }
        [NonSerialized] public string DialogueTitle, Dialogue, Toast;
        public bool DialogueOpen => !string.IsNullOrEmpty(Dialogue);
        public bool Paused => DialogueOpen || Posture == Posture.Folded || Posture == Posture.Book || Posture == Posture.Tent || Pouring;
        public bool Pouring { get; private set; }
        [NonSerialized] public float Balance = .5f, PourProgress;
        public string SavePath { get; private set; }
        SaveStore saves;
        Interactable speaker;
        float saveClock, toastClock;
        AudioSource sound;
        AudioClip chime;
        [NonSerialized] public bool SoundEnabled;
        void Awake()
        {
            DialogueTitle = Dialogue = Toast = null;
            speaker = null;
            Pouring = false;
            Balance = .5f;
            PourProgress = 0;
            Application.targetFrameRate = 60;
            string[] args = Environment.GetCommandLineArgs();
            int at = Array.IndexOf(args, "-seekerSavePath");
            SavePath = !string.IsNullOrEmpty(SavePathOverride) ? SavePathOverride : at >= 0 && at + 1 < args.Length ? args[at + 1] : Path.Combine(Application.persistentDataPath, "journey-v1.json");
            saves = new SaveStore(SavePath); Journey = new Journey(saves.Load());
            WorldBuilder.Build(this);
            Player = FindFirstObjectByType<ThirdPersonMotor>();
            Player.Teleport(new Vector3(Journey.Data.x, Journey.Data.y, Journey.Data.z));
            sound = gameObject.AddComponent<AudioSource>();
            var samples = new float[11025];
            for (int i = 0; i < samples.Length; i++) samples[i] = Mathf.Sin(i * 2 * Mathf.PI * 660 / 22050) * Mathf.Exp(-i / 1800f) * .12f;
            chime = AudioClip.Create("Porcelain chime", samples.Length, 1, 22050, false); chime.SetData(samples, 0);
            if (saves.LastWarning != null) Notify(saves.LastWarning);
            else Notify("A LIFE ALONG THE RIVER  /  " + Journey.Objective);
            gameObject.AddComponent<ScrollHUD>();
        }
        void Update()
        {
            for (int i = 0; i < 5; i++) if (Input.GetKeyDown((KeyCode)((int)KeyCode.Alpha1 + i))) SetPosture((Posture)i);
            if (Input.GetKeyDown(KeyCode.Escape))
            { if (DialogueOpen) CloseDialogue(); else if (Pouring) { Pouring = false; ApplyPause(); } else SetPosture(Posture.Open); }
            if (Input.GetKeyDown(KeyCode.F5) && Save()) Notify("Journey saved  /  Position, satchel and memories kept.");
            if (Input.GetKeyDown(KeyCode.M)) { SoundEnabled = !SoundEnabled; Notify("Interaction chime " + (SoundEnabled ? "on" : "off")); }
            Nearby = FindNearby();
            if (Input.GetKeyDown(KeyCode.E))
            { if (DialogueOpen) ConfirmDialogue(); else if (Nearby && !Pouring && (Posture == Posture.Open || Posture == Posture.Laptop)) Interact(Nearby); }
            if (Pouring)
            {
                Balance = Mathf.Clamp01(Balance + Input.GetAxisRaw("Horizontal") * Time.deltaTime * .6f);
                float target = .5f + Mathf.Sin(Time.time * 1.4f) * .27f;
                PourProgress = Mathf.Clamp(PourProgress + (Mathf.Abs(Balance - target) < PourTolerance ? Time.deltaTime : -Time.deltaTime * .6f), 0, 3);
                if (PourProgress >= 3) CompletePour();
            }
            ApplyPause();
            saveClock += Time.deltaTime;
            if (saveClock > 8) Save();
            toastClock -= Time.deltaTime; if (toastClock <= 0) Toast = null;
            foreach (var item in FindObjectsByType<Interactable>(FindObjectsSortMode.None))
                if (item.Kind == InteractionKind.Seal && !item.Available(Journey)) item.gameObject.SetActive(false);
        }
        public const float PourTolerance = .11f;
        public float PourTarget => .5f + Mathf.Sin(Time.time * 1.4f) * .27f;
        public const float InteractionRadius = 3.3f;
        public bool NearMother => Vector3.Distance(Player.transform.position, WorldBuilder.MotherPosition) < InteractionRadius;
        void ApplyPause()
        {
            if (Player) Player.Paused = Paused;
            if (Camera.main) Camera.main.GetComponent<OrbitCamera>().Locked = Paused;
        }
        public void SetPosture(Posture posture)
        {
            if (Posture == posture) return;
            Journey.Data.posture = posture; CloseDialogue(); Pouring = false; ApplyPause();
            Notify(posture + "  /  " + (posture switch
            {
                Posture.Open => "Unfold the journey.",
                Posture.Folded => "A letter home. Deliver beside Mother.",
                Posture.Book => "Two pages, one journey.",
                Posture.Tent => "Memories in shadow.",
                _ => "A steady hand at the merchant counter."
            }));
            Save();
        }
        public Interactable FindNearby()
        {
            Interactable best = null; float distance = InteractionRadius;
            foreach (var item in FindObjectsByType<Interactable>(FindObjectsSortMode.None))
            {
                if (!item.Available(Journey)) continue;
                float d = Vector3.Distance(Player.transform.position, item.transform.position);
                if (d < distance) { best = item; distance = d; }
            }
            return best;
        }
        public void Interact(Interactable item)
        {
            if (Pouring || (Posture != Posture.Open && Posture != Posture.Laptop) || !item || !item.Available(Journey) || Vector3.Distance(Player.transform.position, item.transform.position) > InteractionRadius) return;
            if (item.Kind == InteractionKind.Seal)
            { if (Journey.Collect(item.SealIndex)) { Notify("Ink seal found  /  +1 copper"); Save(); } return; }
            speaker = item; DialogueTitle = item.DisplayName;
            Dialogue = item.Kind switch
            {
                InteractionKind.Mother => Journey.Data.stage == QuestStage.LeaveHome ? "Xiao An, take these ten copper. Cross Willow Bridge and ask Master Chen for a bottle of soy sauce. Come home before the evening mist." : Journey.Data.stage == QuestStage.ReturnHome ? "You are home! Fold the scroll [2], then give me the bottle. A small promise can carry a long journey." : Journey.Data.stage == QuestStage.Complete ? "The supper is warm, and so is my heart. Keep this seal: A promise kept." : "Follow the stone path across the bridge. Master Chen's red awning is on the far bank.",
                InteractionKind.Merchant => Journey.Data.stage == QuestStage.FindMerchant ? "Good afternoon, little traveler. A bottle is four copper. Steady your hand at my counter and we will fill it together." : Journey.Data.stage == QuestStage.FillBottle ? "Set the scroll like a desk: Laptop [5]. Then speak to me to begin pouring. Keep the marker inside the moving ink band." : Journey.Data.stage == QuestStage.LeaveHome ? "Your mother may have an errand for you. Speak to her first." : "A full bottle, a fair price. Follow the bridge back home; your mother is waiting.",
                _ => "This river remembers every footstep. Book [3] opens your journal. Tent [4] stages only the memories you have earned. Three small ink seals wait along the banks."
            };
            if (item.Kind == InteractionKind.Merchant && Journey.Data.stage == QuestStage.FillBottle && Posture == Posture.Laptop)
            { CloseDialogue(); Pouring = true; Balance = .5f; PourProgress = 0; }
            ApplyPause();
        }
        public void ConfirmDialogue()
        {
            if (!speaker) { CloseDialogue(); return; }
            if (speaker.Kind == InteractionKind.Mother && Journey.Depart()) Notify("The errand begins  /  Find Master Chen beyond the bridge.");
            else if (speaker.Kind == InteractionKind.Merchant && Journey.BuyBottle()) Notify("Paid 4 copper  /  Bottle acquired. Use Laptop [5] at the counter.");
            CloseDialogue(); Save();
        }
        public void CloseDialogue() { Dialogue = null; speaker = null; ApplyPause(); }
        public void CompletePour()
        {
            if (!Pouring || PourProgress < 3 || Posture != Posture.Laptop || Nearby == null || Nearby.Kind != InteractionKind.Merchant) return;
            if (Journey.FillBottle()) { Pouring = false; ApplyPause(); Notify("Soy sauce bottled  /  Walk home and Fold [2] beside Mother."); Save(); }
        }
        public void Deliver()
        { if (Journey.Deliver(Posture, NearMother)) { Notify("A PROMISE KEPT  /  +8 copper · Homecoming seal earned"); Save(); } }
        public void Notify(string message)
        { Toast = message; toastClock = 5; if (SoundEnabled && sound && chime) sound.PlayOneShot(chime); }
        public bool Save()
        {
            if (!Player) return false;
            Vector3 p = Player.transform.position; Journey.Data.x = p.x; Journey.Data.y = p.y; Journey.Data.z = p.z;
            saveClock = 0; bool ok = saves.Save(Journey.Data); if (!ok) Notify(saves.LastWarning); return ok;
        }
        void OnApplicationPause(bool paused) { if (paused) Save(); }
        void OnApplicationQuit() { Save(); }
        void OnDestroy() { if (chime) Destroy(chime); }
    }
}
