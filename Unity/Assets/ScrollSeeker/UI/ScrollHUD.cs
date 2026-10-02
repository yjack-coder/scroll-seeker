using UnityEngine;
using System.Collections.Generic;

namespace ScrollSeeker
{
    /// <summary>Parchment desktop interface. All quest changes go through GameSession.</summary>
    public sealed class ScrollHUD : MonoBehaviour
    {
        readonly Color ink = new Color(.14f, .20f, .21f);
        readonly Color muted = new Color(.37f, .40f, .36f);
        readonly Color paper = new Color(.95f, .92f, .82f);
        readonly Color seal = new Color(.64f, .22f, .17f);
        readonly Color jade = new Color(.30f, .47f, .43f);
        GameSession session;
        Texture2D paperTexture, circleTexture;
        GUIStyle title, heading, body, small, tiny, button, activeButton, quietButton, slider, thumb;
        int story;
        const float CanvasWidth = 1280, CanvasHeight = 800;
        float height;
        bool initialized;
        readonly List<Texture2D> swatches = new List<Texture2D>();
        readonly List<Font> generatedFonts = new List<Font>();

        void Awake() { session = GetComponent<GameSession>(); }

        void Initialize()
        {
            if (initialized) return;
            initialized = true;
            var installedFonts = new HashSet<string>(Font.GetOSInstalledFontNames(), System.StringComparer.OrdinalIgnoreCase);
            Font serif = NativeFont(new[] { "Georgia", "Times New Roman", "Liberation Serif" }, 24, installedFonts);
            Font sans = NativeFont(new[] { "Helvetica Neue", "Arial", "Liberation Sans" }, 18, installedFonts);
            paperTexture = new Texture2D(128, 128, TextureFormat.RGBA32, false) { name = "Procedural rice paper" };
            var pixels = new Color[128 * 128];
            for (int y = 0; y < 128; y++) for (int x = 0; x < 128; x++)
            {
                float grain = Mathf.PerlinNoise(x * .43f, y * .53f) * .028f;
                pixels[y * 128 + x] = TextureColor(new Color(paper.r - grain, paper.g - grain, paper.b - grain, .97f));
            }
            paperTexture.SetPixels(pixels); paperTexture.Apply();
            circleTexture = new Texture2D(64, 64, TextureFormat.RGBA32, false) { name = "Ink silhouette disc" };
            pixels = new Color[4096];
            for (int y = 0; y < 64; y++) for (int x = 0; x < 64; x++)
                pixels[y * 64 + x] = new Color(1, 1, 1, Mathf.Clamp01((31 - Vector2.Distance(new Vector2(x, y), new Vector2(31.5f, 31.5f))) * 2));
            circleTexture.SetPixels(pixels); circleTexture.Apply();
            title = TextStyle(serif, 36, ink);
            heading = TextStyle(serif, 27, ink);
            body = TextStyle(sans, 18, ink);
            small = TextStyle(sans, 15, muted);
            tiny = TextStyle(sans, 12, muted);
            button = ButtonStyle(sans, ink, paper);
            activeButton = ButtonStyle(sans, seal, paper);
            quietButton = ButtonStyle(sans, new Color(.82f, .80f, .70f), ink);
            slider = new GUIStyle(GUI.skin.horizontalSlider);
            slider.normal.background = Flat(ink);
            slider.fixedHeight = 5;
            slider.margin = new RectOffset(0, 0, 14, 14);
            thumb = new GUIStyle(GUI.skin.horizontalSliderThumb);
            thumb.normal.background = Flat(seal);
            thumb.hover.background = Flat(seal * 1.1f);
            thumb.active.background = Flat(seal);
            thumb.fixedWidth = 22; thumb.fixedHeight = 30;
            thumb.margin = new RectOffset(0, 0, -12, 0);
        }

        Font NativeFont(string[] families, int size, HashSet<string> installed)
        {
            foreach (string family in families)
            {
                if (!installed.Contains(family)) continue;
                Font font = Font.CreateDynamicFontFromOSFont(family, size);
                if (!font) continue;
                generatedFonts.Add(font); return font;
            }
            // Unity 6 ships this font; the OS fonts are never copied into the project.
            return Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        }

        GUIStyle TextStyle(Font font, int size, Color color)
        {
            var result = new GUIStyle(GUI.skin.label) { font = font, fontSize = size, wordWrap = true, richText = false };
            result.normal.textColor = color;
            result.padding = new RectOffset(0, 0, 0, 0);
            return result;
        }
        GUIStyle ButtonStyle(Font font, Color background, Color foreground)
        {
            var result = new GUIStyle(GUI.skin.button) { font = font, fontSize = 16, alignment = TextAnchor.MiddleCenter };
            result.normal.background = Flat(background); result.normal.textColor = foreground;
            result.hover.background = Flat(Color.Lerp(background, Color.white, .13f)); result.hover.textColor = foreground;
            result.active.background = Flat(Color.Lerp(background, Color.black, .10f)); result.active.textColor = foreground;
            result.focused.background = result.hover.background; result.focused.textColor = foreground;
            result.border = new RectOffset(0, 0, 0, 0);
            result.padding = new RectOffset(12, 12, 8, 8);
            return result;
        }
        Texture2D Flat(Color color)
        {
            var texture = new Texture2D(1, 1) { name = "HUD swatch", hideFlags = HideFlags.HideAndDontSave };
            texture.SetPixel(0, 0, TextureColor(color)); texture.Apply(); swatches.Add(texture); return texture;
        }
        void OnDestroy()
        {
            if (paperTexture) Destroy(paperTexture);
            if (circleTexture) Destroy(circleTexture);
            foreach (var texture in swatches) if (texture) Destroy(texture);
            foreach (var font in generatedFonts) if (font) Destroy(font);
        }

        void OnGUI()
        {
            if (!session || session.Journey == null) return;
            Initialize();
            float scale = Mathf.Min(Screen.width / CanvasWidth, Screen.height / CanvasHeight);
            height = Screen.height / scale;
            float width = Screen.width / scale;
            Matrix4x4 previous = GUI.matrix;
            Color previousColor = GUI.color;
            GUI.matrix = Matrix4x4.TRS(new Vector3((width - CanvasWidth) * scale * .5f, 0, 0), Quaternion.identity, Vector3.one * scale);
            GUI.color = Color.white;
            DrawHeader();
            if (!session.DialogueOpen) switch (session.Posture)
            {
                case Posture.Folded: DrawFolded(); break;
                case Posture.Book: DrawBook(); break;
                case Posture.Tent: DrawTheater(); break;
                case Posture.Laptop: DrawLaptop(); break;
            }
            if (session.Posture == Posture.Open || session.Posture == Posture.Laptop && !session.Pouring) DrawInteraction();
            if (!string.IsNullOrEmpty(session.Toast)) DrawToast();
            DrawFooter();
            if (session.DialogueOpen) DrawDialogue();
            GUI.matrix = previous;
            GUI.color = previousColor;
        }

        void DrawHeader()
        {
            Panel(new Rect(28, 24, 364, 100));
            Solid(new Rect(44, 40, 44, 64), seal);
            Label(new Rect(47, 49, 38, 52), "S\nS", 20, paper, TextAnchor.MiddleCenter);
            GUI.Label(new Rect(104, 38, 270, 42), "Scroll Seeker", title);
            GUI.Label(new Rect(105, 84, 270, 24), "A LIFE ALONG THE RIVER", tiny);
            Panel(new Rect(828, 24, 424, 146));
            GUI.Label(new Rect(850, 41, 380, 20), "THE SMALL PROMISE", tiny);
            GUI.Label(new Rect(850, 68, 380, 58), session.Journey.Objective, body);
            Rule(850, 132, 380);
            var data = session.Journey.Data;
            GUI.Label(new Rect(850, 141, 93, 24), data.copper + " copper", small);
            GUI.Label(new Rect(949, 141, 190, 24), InventoryName(), small);
            GUI.Label(new Rect(1150, 141, 80, 24), SealCount() + "/3 seals", small);
        }

        void DrawFooter()
        {
            float y = height - 105;
            Panel(new Rect(28, y, 1224, 81));
            string[] names = { "1  Open", "2  Folded", "3  Book", "4  Tent", "5  Laptop" };
            for (int i = 0; i < names.Length; i++)
                if (GUI.Button(new Rect(43 + i * 150, y + 13, 140, 40), names[i], (int)session.Posture == i ? activeButton : quietButton))
                    session.SetPosture((Posture)i);
            GUI.Label(new Rect(817, y + 12, 416, 22), "WASD move  ·  Shift run  ·  E interact", small);
            GUI.Label(new Rect(817, y + 39, 416, 22), "RMB orbit  ·  Wheel zoom  ·  F5 save  ·  M sound", small);
            string escape = session.DialogueOpen ? "Esc closes dialogue" : session.Pouring ? "Esc stops pouring" : "Esc returns to the river";
            GUI.Label(new Rect(45, y + 61, 745, 18), "Keyboard posture simulation  /  " + escape + "  /  Sound " + (session.SoundEnabled ? "on" : "off"), tiny);
        }

        void DrawInteraction()
        {
            if (session.DialogueOpen || !session.Nearby) return;
            string name = session.Nearby.DisplayName;
            if (string.IsNullOrEmpty(name)) name = session.Nearby.Kind == InteractionKind.Seal ? "Ink seal" : session.Nearby.Kind.ToString();
            var rect = new Rect(438, height - 176, 404, 52);
            Panel(rect);
            if (GUI.Button(new Rect(rect.x + 8, rect.y + 8, rect.width - 16, 36), "E  ·  " + name, button)) session.Interact(session.Nearby);
        }

        void DrawToast()
        {
            bool overlay = session.DialogueOpen || session.Posture == Posture.Folded || session.Posture == Posture.Book || session.Posture == Posture.Tent || session.Pouring;
            // Keep feedback outside the modal's reading and action areas.
            var rect = overlay ? new Rect(408, 42, 402, 76) : new Rect(336, height - 232, 608, 44);
            Solid(rect, new Color(ink.r, ink.g, ink.b, .93f));
            Label(new Rect(rect.x + 14, rect.y + 7, rect.width - 28, rect.height - 14), session.Toast, overlay ? 14 : 15, paper, TextAnchor.MiddleCenter);
        }

        Rect Modal(string eyebrow, string name, float width = 890, float modalHeight = 474)
        {
            Solid(new Rect(0, 180, CanvasWidth, height - 300), new Color(.09f, .15f, .16f, .20f));
            var r = new Rect((CanvasWidth - width) * .5f, Mathf.Max(186, (height - modalHeight) * .5f - 15), width, modalHeight);
            Panel(r);
            Solid(new Rect(r.x, r.y, 7, r.height), seal);
            GUI.Label(new Rect(r.x + 30, r.y + 23, r.width - 60, 20), eyebrow, tiny);
            GUI.Label(new Rect(r.x + 30, r.y + 49, r.width - 60, 40), name, title);
            Rule(r.x + 30, r.y + 101, r.width - 60);
            return r;
        }

        void DrawFolded()
        {
            var r = Modal("02  /  FOLDED", "A letter from home", 680, 470);
            string letter = session.Journey.Data.stage == QuestStage.Complete
                ? "A long river, a short errand, and a promise kept. Leave your bag by the door; supper is ready."
                : session.Journey.Data.stage == QuestStage.LeaveHome
                    ? "Xiao An, come speak with me at the farmhouse before you go. There is a small errand for you today."
                    : "Xiao An, follow the river past Willow Bridge. Master Chen will help you fill a bottle of soy sauce. I'll keep supper warm.";
            GUI.Label(new Rect(r.x + 32, r.y + 121, 616, 68), letter, body);
            Label(new Rect(r.x + 32, r.y + 193, 610, 22), "— Mother", 16, seal, TextAnchor.UpperRight);
            GUI.Label(new Rect(r.x + 32, r.y + 231, 616, 35), "Satchel  /  " + InventoryName() + "     ·     " + session.Journey.Data.copper + " copper", heading);
            string note = session.Journey.Data.stage == QuestStage.Complete
                ? "Homecoming seal earned. Mother has the bottle, and supper can begin."
                : session.Journey.Data.stage == QuestStage.ReturnHome
                    ? session.NearMother ? "Mother is beside you. Place the bottle in her hands." : "Bring the full bottle back to Mother. Delivery is available only beside her."
                    : "The scroll rests; the river waits. Open it to resume your journey from this very place.";
            GUI.Label(new Rect(r.x + 32, r.y + 286, 616, 58), note, body);
            bool canDeliver = session.Journey.Data.stage == QuestStage.ReturnHome && session.NearMother;
            if (canDeliver && GUI.Button(new Rect(r.x + 32, r.y + 365, 298, 52), "Deliver soy sauce  ·  +8 copper", activeButton)) session.Deliver();
            if (GUI.Button(new Rect(r.x + (canDeliver ? 350 : 32), r.y + 365, 298, 52), "1  ·  Return to the river", button)) session.SetPosture(Posture.Open);
        }

        void DrawBook()
        {
            var r = Modal("03  /  BOOK", "The river journal", 990, 485);
            float x = r.x + 30, y = r.y + 122;
            GUI.Label(new Rect(x, y, 394, 27), "An errand in five steps", heading);
            string[] steps = { "At home", "Across Willow Bridge", "At Master Chen's counter", "The journey back", "A promise kept" };
            string[] descriptions = { "Speak to Mother to accept her errand.", "Follow the path to the red merchant awning.", "Pay 4 copper. Laptop steadies the pouring hand.", "Carry the soy sauce home. Fold beside Mother.", "Deliver the bottle; receive 8 copper and a seal." };
            int current = (int)session.Journey.Data.stage;
            for (int i = 0; i < steps.Length; i++)
            {
                float rowY = y + 43 + i * 48;
                Dot(x + 9, rowY + 11, 6, i <= current ? seal : new Color(.70f, .70f, .61f));
                GUI.Label(new Rect(x + 27, rowY, 365, 23), steps[i] + (i < current ? "  /  recorded" : i == current ? "  /  now" : ""), body);
                GUI.Label(new Rect(x + 27, rowY + 23, 370, 23), descriptions[i], tiny);
            }
            DrawMap(new Rect(r.x + 464, y, 492, 290));
            GUI.Label(new Rect(x, r.y + 430, 675, 25), SealCount() + " of 3 riverside ink seals found. Each carries 1 copper.", small);
            if (GUI.Button(new Rect(r.x + r.width - 226, r.y + 417, 195, 44), "1  ·  Close the book", button)) session.SetPosture(Posture.Open);
        }

        void DrawMap(Rect r)
        {
            Solid(r, new Color(.86f, .85f, .74f));
            Solid(new Rect(r.center.x - 24, r.y, 48, r.height), new Color(.54f, .68f, .66f));
            for (int i = 0; i < 8; i++) Rule(r.center.x - 13, r.y + 18 + i * 37, 26, new Color(.69f, .77f, .70f));
            Solid(new Rect(r.x + 57, r.center.y - 8, r.width - 104, 16), new Color(.72f, .68f, .52f));
            Solid(new Rect(r.center.x - 30, r.center.y - 13, 60, 26), ink);
            Label(new Rect(r.x + 18, r.y + 12, r.width - 36, 22), "WILLOW RIVER  /  N ↑", 12, ink, TextAnchor.UpperRight);
            Label(new Rect(r.center.x - 86, r.center.y + 18, 172, 23), "Willow Bridge", 14, ink, TextAnchor.MiddleCenter);
            foreach (var item in FindObjectsByType<Interactable>(FindObjectsSortMode.None))
            {
                if (item.Kind == InteractionKind.Seal) continue;
                Vector2 p = MapPoint(r, item.transform.position);
                Dot(p.x, p.y, 6, seal);
                string label = item.Kind == InteractionKind.Mother ? "Home / Mother" : item.Kind == InteractionKind.Merchant ? "Master Chen" : "River elder";
                GUI.Label(new Rect(p.x - 48, p.y + 9, 130, 22), label, tiny);
            }
            Vector2 player = MapPoint(r, session.Player.transform.position);
            Dot(player.x, player.y, 9, paper); Dot(player.x, player.y, 5, jade);
            GUI.Label(new Rect(r.x + 16, r.yMax - 27, r.width - 32, 22), "● red: village folk     ● jade: your position", tiny);
        }
        Vector2 MapPoint(Rect r, Vector3 point) => new Vector2(Mathf.Lerp(r.x + 20, r.xMax - 20, Mathf.InverseLerp(-34, 34, point.x)), Mathf.Lerp(r.yMax - 34, r.y + 34, Mathf.InverseLerp(-21, 21, point.z)));

        void DrawTheater()
        {
            var r = Modal("04  /  TENT", "Memories in lamplight", 940, 478);
            int earned = Mathf.Clamp((int)session.Journey.Data.stage, 0, 4);
            story = Mathf.Clamp(story, 0, Mathf.Max(0, earned - 1));
            Rect stage = new Rect(r.x + 30, r.y + 124, 565, 260);
            Solid(stage, new Color(.77f, .67f, .47f));
            Solid(new Rect(stage.x, stage.y, stage.width, 11), ink);
            Solid(new Rect(stage.x, stage.yMax - 18, stage.width, 18), ink);
            for (int i = 0; i < 5; i++)
            {
                float sway = Mathf.Sin(Time.unscaledTime * .7f + i) * 8;
                Dot(stage.x + 40 + i * 124 + sway, stage.y + 28, 22, new Color(.83f, .76f, .58f, .25f));
            }
            if (earned == 0)
            {
                Label(new Rect(stage.x + 35, stage.y + 95, stage.width - 70, 66), "The stage awaits your first memory.\nSpeak to Mother and begin the errand.", 21, ink, TextAnchor.MiddleCenter);
            }
            else DrawShadowScene(stage, story);
            string[] names = { "The farewell", "The fair price", "The steady hand", "The homecoming" };
            string[] captions = { "Ten copper and a small promise. The path begins at the farmhouse.", "Across the river, a merchant offers a bottle for four copper.", "A steady hand fills the bottle. The long walk home begins.", "The bottle changes hands; an ordinary errand becomes a memory." };
            float x = r.x + 620;
            GUI.Label(new Rect(x, r.y + 125, 290, 26), "Your earned scenes", heading);
            for (int i = 0; i < 4; i++)
            {
                bool oldEnabled = GUI.enabled; GUI.enabled = earned > i;
                if (GUI.Button(new Rect(x, r.y + 166 + i * 48, 290, 38), names[i] + (earned <= i ? "  /  unrecorded" : ""), i == story && earned > 0 ? activeButton : quietButton)) story = i;
                GUI.enabled = oldEnabled;
            }
            GUI.Label(new Rect(r.x + 30, r.y + 398, 590, 56), earned == 0 ? "Story scenes unlock through the quest. Nothing is earned by waiting here." : captions[story], small);
            if (GUI.Button(new Rect(x, r.y + 403, 290, 45), "1  ·  Leave the theater", button)) session.SetPosture(Posture.Open);
        }

        void DrawShadowScene(Rect r, int index)
        {
            Color shadow = new Color(.19f, .22f, .20f, .92f);
            float floor = r.yMax - 18;
            if (index == 0 || index == 3)
            {
                Solid(new Rect(r.x + 40, floor - 82, 113, 82), shadow);
                Line(new Vector2(r.x + 23, floor - 81), new Vector2(r.x + 95, floor - 124), 16, shadow);
                Line(new Vector2(r.x + 95, floor - 124), new Vector2(r.x + 166, floor - 81), 16, shadow);
                Solid(new Rect(r.x + 91, floor - 46, 22, 46), new Color(.77f, .67f, .47f));
                ShadowPerson(r.x + 197, floor, 1, .15f, shadow);
                ShadowPerson(r.x + 300 + (index == 0 ? Mathf.Sin(Time.unscaledTime) * 20 : 0), floor, .8f, index == 0 ? 1 : .25f, shadow);
                if (index == 3) Dot(r.x + 253, floor - 51, 9, seal);
            }
            else
            {
                Solid(new Rect(r.x + 345, floor - 51, 170, 12), shadow);
                Solid(new Rect(r.x + 362, floor - 39, 9, 39), shadow);
                Solid(new Rect(r.x + 492, floor - 39, 9, 39), shadow);
                Line(new Vector2(r.x + 329, floor - 135), new Vector2(r.x + 527, floor - 135), 15, shadow);
                Solid(new Rect(r.x + 352, floor - 135, 7, 94), shadow);
                Solid(new Rect(r.x + 500, floor - 135, 7, 94), shadow);
                ShadowPerson(r.x + 455, floor, 1, .25f, shadow);
                ShadowPerson(r.x + 271, floor, .8f, index == 2 ? .5f : .2f, shadow);
                Dot(r.x + 393, floor - 67, 7, seal);
                if (index == 2) Line(new Vector2(r.x + 371, floor - 96), new Vector2(r.x + 393, floor - 70), 3, shadow);
            }
            Label(new Rect(r.x + 16, r.y + 22, r.width - 32, 22), "RIVER SHADOW THEATER", 12, shadow, TextAnchor.UpperCenter);
        }
        void ShadowPerson(float x, float floor, float scale, float movement, Color color)
        {
            float sway = Mathf.Sin(Time.unscaledTime * 2.4f) * movement;
            Dot(x, floor - 83 * scale, 14 * scale, color);
            Line(new Vector2(x, floor - 67 * scale), new Vector2(x, floor - 30 * scale), 24 * scale, color);
            Line(new Vector2(x - 1, floor - 53 * scale), new Vector2(x - 26 * scale, floor - (35 + sway * 6) * scale), 8 * scale, color);
            Line(new Vector2(x + 1, floor - 53 * scale), new Vector2(x + 27 * scale, floor - (41 - sway * 6) * scale), 8 * scale, color);
            Line(new Vector2(x - 5 * scale, floor - 31 * scale), new Vector2(x - (12 + sway * 7) * scale, floor), 10 * scale, color);
            Line(new Vector2(x + 5 * scale, floor - 31 * scale), new Vector2(x + (12 + sway * 7) * scale, floor), 10 * scale, color);
        }

        void DrawLaptop()
        {
            if (!session.Pouring)
            {
                Rect r = new Rect(828, 188, 424, 279); Panel(r);
                GUI.Label(new Rect(r.x + 22, r.y + 20, 380, 20), "05  /  LAPTOP", tiny);
                GUI.Label(new Rect(r.x + 22, r.y + 48, 380, 40), "A steady hand", heading);
                bool atCounter = session.Nearby && session.Nearby.Kind == InteractionKind.Merchant;
                string note = session.Journey.Data.stage == QuestStage.FillBottle
                    ? atCounter ? "The bottle is ready. Begin at the counter, then keep your hand inside the moving jade band for three seconds." : "Carry your empty bottle to Master Chen's counter. You can still walk in this posture."
                    : session.Journey.Data.stage == QuestStage.ReturnHome || session.Journey.Data.stage == QuestStage.Complete ? "The pouring is complete. Open the scroll and carry the memory onward." : "Master Chen supplies an empty bottle after you accept Mother's errand. Speak to him across the bridge.";
                GUI.Label(new Rect(r.x + 22, r.y + 101, 380, 104), note, body);
                if (atCounter && session.Journey.Data.stage == QuestStage.FillBottle)
                { if (GUI.Button(new Rect(r.x + 22, r.y + 211, 380, 46), "E  ·  Begin pouring", activeButton)) session.Interact(session.Nearby); }
                else if (GUI.Button(new Rect(r.x + 22, r.y + 211, 380, 46), "1  ·  Open the scroll", button)) session.SetPosture(Posture.Open);
                return;
            }
            var modal = Modal("05  /  LAPTOP", "Pour a little patience", 800, 432);
            GUI.Label(new Rect(modal.x + 30, modal.y + 121, 740, 62), "Keep the red hand inside the moving jade band. Use A / D, the arrow keys, or drag the slider below.", body);
            Rect track = new Rect(modal.x + 50, modal.y + 217, 700, 36);
            Solid(new Rect(track.x, track.y + 6, track.width, 24), new Color(.83f, .81f, .70f));
            float low = Mathf.Clamp01(session.PourTarget - GameSession.PourTolerance), high = Mathf.Clamp01(session.PourTarget + GameSession.PourTolerance);
            Solid(new Rect(track.x + track.width * low, track.y, track.width * (high - low), 36), jade);
            session.Balance = GUI.HorizontalSlider(new Rect(track.x, track.y + 14, track.width, 5), session.Balance, 0, 1, slider, thumb);
            bool steady = Mathf.Abs(session.Balance - session.PourTarget) < GameSession.PourTolerance;
            GUI.Label(new Rect(modal.x + 50, modal.y + 270, 700, 26), steady ? "A steady stream  /  filling the bottle" : "Follow the jade band  /  the stream is slowing", body);
            Solid(new Rect(modal.x + 50, modal.y + 310, 700, 12), new Color(.82f, .80f, .69f));
            Solid(new Rect(modal.x + 50, modal.y + 310, 700 * Mathf.Clamp01(session.PourProgress / 3), 12), seal);
            GUI.Label(new Rect(modal.x + 50, modal.y + 335, 470, 26), session.PourProgress.ToString("0.0") + " / 3.0 seconds of steady pouring", small);
            if (GUI.Button(new Rect(modal.x + 563, modal.y + 341, 187, 48), "1  ·  Put it down", quietButton)) session.SetPosture(Posture.Open);
        }

        void DrawDialogue()
        {
            Solid(new Rect(0, 180, CanvasWidth, height - 300), new Color(.09f, .15f, .16f, .18f));
            Rect r = new Rect(230, height - 388, 820, 254); Panel(r);
            Solid(new Rect(r.x, r.y, 6, r.height), seal);
            GUI.Label(new Rect(r.x + 30, r.y + 22, r.width - 60, 35), session.DialogueTitle, heading);
            Rule(r.x + 30, r.y + 66, r.width - 60);
            GUI.Label(new Rect(r.x + 30, r.y + 87, r.width - 60, 89), session.Dialogue, body);
            string action = "E  ·  Continue";
            if (session.Nearby && session.Nearby.Kind == InteractionKind.Mother && session.Journey.Data.stage == QuestStage.LeaveHome) action = "E  ·  Accept the errand";
            if (session.Nearby && session.Nearby.Kind == InteractionKind.Merchant && session.Journey.Data.stage == QuestStage.FindMerchant) action = "E  ·  Buy bottle  /  4 copper";
            if (GUI.Button(new Rect(r.x + 30, r.y + 187, 475, 46), action, button)) session.ConfirmDialogue();
            if (GUI.Button(new Rect(r.x + 525, r.y + 187, 265, 46), "Esc  ·  Close", quietButton)) session.CloseDialogue();
        }

        string InventoryName() => session.Journey.Data.soySauce ? "Soy sauce" : session.Journey.Data.emptyBottle ? "Empty bottle" : session.Journey.Data.rewardClaimed ? "Homecoming seal" : "Empty satchel";
        int SealCount() { int mask = session.Journey.Data.keepsakes; return (mask & 1) + ((mask >> 1) & 1) + ((mask >> 2) & 1); }
        void Panel(Rect r)
        {
            Solid(new Rect(r.x + 3, r.y + 5, r.width, r.height), new Color(.09f, .12f, .11f, .13f));
            GUI.DrawTexture(r, paperTexture, ScaleMode.StretchToFill);
            Solid(new Rect(r.x, r.y, r.width, 1), new Color(.70f, .67f, .56f, .5f));
            Solid(new Rect(r.x, r.yMax - 1, r.width, 1), new Color(.70f, .67f, .56f, .5f));
        }
        void Rule(float x, float y, float width) => Rule(x, y, width, new Color(.65f, .63f, .53f, .45f));
        void Rule(float x, float y, float width, Color color) => Solid(new Rect(x, y, width, 1), color);
        // IMGUI texture pixels/tints are gamma encoded by a Linear-space player;
        // text colors are handled by its font renderer. Keep the visible palette consistent.
        static Color TextureColor(Color color) => QualitySettings.activeColorSpace == ColorSpace.Linear ? color.linear : color;
        void Solid(Rect r, Color color) { Color old = GUI.color; GUI.color = TextureColor(color); GUI.DrawTexture(r, Texture2D.whiteTexture); GUI.color = old; }
        void Dot(float x, float y, float radius, Color color) { Color old = GUI.color; GUI.color = TextureColor(color); GUI.DrawTexture(new Rect(x - radius, y - radius, radius * 2, radius * 2), circleTexture); GUI.color = old; }
        void Label(Rect r, string text, int size, Color color, TextAnchor alignment)
        {
            var style = new GUIStyle(body) { fontSize = size, alignment = alignment };
            style.normal.textColor = color; GUI.Label(r, text, style);
        }
        void Line(Vector2 a, Vector2 b, float thickness, Color color)
        {
            Matrix4x4 old = GUI.matrix;
            Vector2 difference = b - a;
            // Compose inside the canvas transform so rotated silhouettes remain joined
            // when the whole HUD is scaled for the window's resolution.
            GUI.matrix = old * Matrix4x4.TRS(new Vector3(a.x, a.y, 0), Quaternion.Euler(0, 0, Mathf.Atan2(difference.y, difference.x) * Mathf.Rad2Deg), Vector3.one);
            Solid(new Rect(0, -thickness * .5f, difference.magnitude, thickness), color);
            GUI.matrix = old;
        }
    }
}
