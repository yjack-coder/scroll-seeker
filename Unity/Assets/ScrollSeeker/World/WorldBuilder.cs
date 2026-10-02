using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace ScrollSeeker
{
    /// <summary>Deterministic, original geometry for a complete riverside adventure scene.</summary>
    public sealed class WorldBuilder
    {
        public static readonly Vector3 MotherPosition = new(-24, 0, 3);
        public static readonly Vector3 MerchantPosition = new(22, 0, 1.6f);
        public static readonly Vector3 ElderPosition = new(-8.5f, 0, 8);
        readonly Transform root;
        readonly System.Random random = new(4107);
        readonly Material paper, path, ink, roof, wood, jade, leaves, red, skin, stone, river, lightPaper, moss;
        readonly GameSession session;
        readonly WorldResources resources;
        readonly List<GameObject> sceneryRenderers = new();
        bool movingHierarchy;

        WorldBuilder(GameSession game)
        {
            session = game;
            root = new GameObject("Willow River • original procedural village").transform;
            root.SetParent(game.transform, false);
            resources = root.gameObject.AddComponent<WorldResources>();
            var grain = resources.Own(PaperTexture());
            paper = Paint("Warm limewash", "#E4DEC4", grain, .07f);
            lightPaper = Paint("Rice paper", "#F2E9D3", grain, .04f);
            path = Paint("Old sandstone", "#C6B999", grain, .14f);
            ink = Paint("Blue black ink", "#283B40", grain, .05f);
            roof = Paint("Slate ink roof", "#475E60", grain, .12f);
            wood = Paint("Weathered elm", "#655346", grain, .12f);
            jade = Paint("River jade", "#789587", grain, .10f);
            leaves = Paint("Willow green", "#76917A", grain, .14f);
            red = Paint("Cinnabar", "#A64E3E", grain, .10f);
            skin = Paint("Warm peach", "#E1BA96", grain, .025f);
            stone = Paint("River stone", "#9DA694", grain, .13f);
            moss = Paint("Pale meadow", "#BBC4A4", grain, .12f);
            river = resources.Own(new Material(Shader.Find("ScrollSeeker/River Ink")) { name = "Jade water with moving ink ripples", enableInstancing = true });
            river.SetColor("_Color", ColorOf("#496F6A")); river.SetColor("_Foam", ColorOf("#D6DDC2"));
        }

        public static void Build(GameSession session)
        {
            var builder = new WorldBuilder(session);
            builder.Lighting(); builder.Landscape(); builder.Village(); builder.Garden(); builder.People();
            builder.CreateCamera();
            var rescue = builder.root.gameObject.AddComponent<RiverSafety>(); rescue.Session = session;
            // Only environment geometry is combined. Animated limbs and bobbing collectibles remain independent.
            StaticBatchingUtility.Combine(builder.sceneryRenderers.ToArray(), builder.root.gameObject);
        }

        void Lighting()
        {
            RenderSettings.skybox = null;
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = ColorOf("#D7DDCC");
            RenderSettings.ambientEquatorColor = ColorOf("#B4C0AD");
            RenderSettings.ambientGroundColor = ColorOf("#6C796C");
            RenderSettings.fog = true; RenderSettings.fogMode = FogMode.ExponentialSquared;
            RenderSettings.fogColor = ColorOf("#D2D9C9"); RenderSettings.fogDensity = .016f;
            QualitySettings.shadows = ShadowQuality.All; QualitySettings.shadowResolution = ShadowResolution.High;
            QualitySettings.shadowDistance = 65; QualitySettings.antiAliasing = 4;
            var sun = new GameObject("Late afternoon through rice paper"); sun.transform.SetParent(root);
            var light = sun.AddComponent<Light>(); light.type = LightType.Directional;
            light.color = ColorOf("#FFF1D0"); light.intensity = 1.05f;
            light.shadows = LightShadows.Soft; light.shadowStrength = .58f; light.shadowBias = .035f;
            sun.transform.rotation = Quaternion.Euler(42, -38, 0);
            RenderSettings.sun = light;
        }

        void Landscape()
        {
            Block("West bank", new Vector3(-19, -.6f, 0), new Vector3(31, 1.2f, 44), moss, true);
            Block("East bank", new Vector3(19, -.6f, 0), new Vector3(31, 1.2f, 44), moss, true);
            Block("Slow Willow River", new Vector3(0, -.21f, 0), new Vector3(7.08f, .09f, 64), river);
            Block("River bed", new Vector3(0, -1.8f, 0), new Vector3(7, .2f, 44), stone, true);
            Block("West stone lane", new Vector3(-19, .022f, 0), new Vector3(28, .038f, 3.4f), path);
            Block("East stone lane", new Vector3(19, .022f, 0), new Vector3(28, .038f, 3.4f), path);
            for (int i = 0; i < 45; i++)
            {
                float x = -32 + i * 1.45f;
                if (Mathf.Abs(x) < 5.6f) continue;
                var paver = Block("Worn stone paver", new Vector3(x, .051f, Jitter(-.11f, .11f)), new Vector3(1.17f, .025f, 2.83f), stone);
                paver.transform.rotation = Quaternion.Euler(0, Jitter(-4, 4), 0);
            }
            Bridge();
            for (int side = -1; side <= 1; side += 2)
            {
                for (int z = -21; z <= 21; z++)
                {
                    if (Mathf.Abs(z) < 3) continue;
                    float x = side * Jitter(3.7f, 4.25f);
                    Sphere("Soft river-bank stone", new Vector3(x, -.06f, z + Jitter(-.22f, .22f)), new Vector3(Jitter(.45f, .85f), Jitter(.25f, .4f), Jitter(.55f, .9f)), stone);
                    if (z % 3 == 0) Reeds(new Vector3(side * 4.55f, 0, z), 7);
                }
            }
            // Painted mountain silhouettes sit beyond all playable terrain.
            for (int i = 0; i < 20; i++)
            {
                var mountain = MeshObject("Distant ink mountain", MeshCraft.TaperedCylinder(Jitter(8, 15), Jitter(.4f, 2), Jitter(10, 22), 7), stone);
                mountain.transform.position = new Vector3(-70 + i * 7.5f, -3, 46 + Jitter(-3, 10));
                mountain.transform.rotation = Quaternion.Euler(0, Jitter(0, 360), 0);
                mountain.GetComponent<Renderer>().shadowCastingMode = ShadowCastingMode.Off;
            }
            for (int i = 0; i < 11; i++)
            {
                var hill = MeshObject("Low wash hill", MeshCraft.TaperedCylinder(Jitter(9, 15), 1, Jitter(5, 10), 8), jade);
                hill.transform.position = new Vector3(-58 + i * 11, -2, -40 - Jitter(0, 14));
                hill.GetComponent<Renderer>().shadowCastingMode = ShadowCastingMode.Off;
            }
            Boundaries();
        }

        void Bridge()
        {
            MeshObject("Willow Bridge • traversable stone arch", MeshCraft.Bridge(), path, true);
            for (int side = -1; side <= 1; side += 2)
            {
                for (int i = 0; i <= 8; i++)
                {
                    float x = -5.35f + i * 1.3375f, y = MeshCraft.BridgeHeight(x);
                    Block("Carved bridge post", new Vector3(x, y + .57f, side * 2.06f), new Vector3(.22f, 1.13f, .22f), stone, true);
                    Sphere("Post cap", new Vector3(x, y + 1.17f, side * 2.06f), Vector3.one * .3f, ink);
                    if (i < 8)
                    {
                        float nx = x + 1.3375f;
                        Beam("Dark bridge handrail", new Vector3(x, y + .94f, side * 2.06f), new Vector3(nx, MeshCraft.BridgeHeight(nx) + .94f, side * 2.06f), .14f, wood, true);
                        Beam("Lower rail", new Vector3(x, y + .4f, side * 2.06f), new Vector3(nx, MeshCraft.BridgeHeight(nx) + .4f, side * 2.06f), .09f, wood);
                    }
                }
            }
            for (int i = 0; i < 16; i++)
            {
                float x = -5.1f + i * .68f;
                Beam("Bridge paving seam", new Vector3(x, MeshCraft.BridgeHeight(x) + .014f, -1.93f), new Vector3(x, MeshCraft.BridgeHeight(x) + .014f, 1.93f), .017f, ink);
            }
            Lantern(new Vector3(-5.65f, 0, -2.5f)); Lantern(new Vector3(5.65f, 0, 2.5f));
        }

        void Village()
        {
            House("Xiao An's home", new Vector3(-24, 0, 7), 6, 4.3f, 3, false);
            House("Weaver's cottage", new Vector3(-15, 0, 8.8f), 5.2f, 4, 2.7f, false);
            House("Potter's courtyard", new Vector3(-23, 0, -8), 5.6f, 4.6f, 2.9f, true);
            House("Tea house", new Vector3(12.8f, 0, 7.2f), 6.6f, 4.6f, 3.2f, false);
            House("Merchant's storehouse", new Vector3(23, 0, 7.5f), 6.7f, 4.2f, 3.05f, false);
            House("River keeper's cottage", new Vector3(15.4f, 0, -8.2f), 5.6f, 4, 2.7f, true);
            House("East courtyard", new Vector3(28.5f, 0, -12.8f), 5.1f, 4.4f, 2.6f, true);
            Stall();
            for (int i = 0; i < 4; i++)
            {
                Vessel(new Vector3(-26 + i * .7f, 0, 4.3f), .3f, .65f, i % 2 == 0 ? wood : jade);
                Vessel(new Vector3(20 + i * .72f, 0, 5), .35f, .74f, wood);
            }
            Bench(new Vector3(-9, 0, 7.8f), 28);
            Bench(new Vector3(9.3f, 0, -4.1f), -20);
            Sign(new Vector3(-21, 0, 2.8f), "HOME", 18);
            Sign(new Vector3(7.3f, 0, 2.4f), "CHEN'S SOY  →", -13);
            for (int i = 0; i < 6; i++)
            {
                float z = 2.5f + i * .55f;
                Block("Home garden stepping stone", new Vector3(-24, .045f, z), new Vector3(.86f, .07f, .43f), stone);
            }
            // A boat and landing give the water edge a purpose and readable scale.
            Boat(new Vector3(2.35f, -.1f, 10.8f));
            Block("Timber fishing landing", new Vector3(4.55f, .13f, 11), new Vector3(3.5f, .24f, 3.6f), wood, true);
            for (int i = 0; i < 8; i++)
                Block("Landing plank seam", new Vector3(4.55f, .26f, 9.6f + i * .4f), new Vector3(3.46f, .025f, .025f), ink);
            Beam("Fishing rod", new Vector3(4.3f, .3f, 12), new Vector3(1.3f, 2.3f, 13), .055f, wood);
            for (int i = 0; i < 4; i++) Lantern(new Vector3(-29 + i * 17.5f, 0, -2.8f));
            Laundry();
        }

        void House(string name, Vector3 point, float width, float depth, float height, bool reverse)
        {
            var group = new GameObject(name).transform; group.SetParent(root); group.position = point;
            if (reverse) group.rotation = Quaternion.Euler(0, 180, 0);
            Block("Stone foundation", new Vector3(0, .22f, 0), new Vector3(width + .25f, .44f, depth + .25f), stone, true, group);
            Block("Paper plaster walls", new Vector3(0, height * .5f + .3f, 0), new Vector3(width, height, depth), paper, true, group);
            foreach (int sx in new[] { -1, 1 }) foreach (int sz in new[] { -1, 1 })
                Block("Dark timber column", new Vector3(sx * (width * .5f + .016f), height * .5f + .3f, sz * (depth * .5f + .025f)), new Vector3(.16f, height + .06f, .16f), wood, false, group);
            Block("Front lintel", new Vector3(0, height + .1f, -depth * .5f - .03f), new Vector3(width + .24f, .19f, .18f), wood, false, group);
            Block("Front sill", new Vector3(0, .65f, -depth * .5f - .03f), new Vector3(width, .1f, .1f), wood, false, group);
            var r = MeshObject("Swept slate roof", MeshCraft.Roof(width + 1.2f, depth + 1.35f, 1.4f), roof, true, group);
            r.transform.localPosition = new Vector3(0, height + .1f, 0);
            Beam("Ink ridge cap", new Vector3(-width * .5f - .55f, height + 1.55f, 0), new Vector3(width * .5f + .55f, height + 1.55f, 0), .17f, ink, false, group);
            for (int side = -1; side <= 1; side += 2)
            {
                Beam("Deep eave edge", new Vector3(-width * .5f - .55f, height + .5f, side * (depth * .5f + .67f)), new Vector3(width * .5f + .55f, height + .5f, side * (depth * .5f + .67f)), .1f, ink, false, group);
                for (int i = 0; i <= 10; i++)
                {
                    float x = -(width + .8f) * .5f + i * (width + .8f) / 10;
                    for (int row = 0; row < 8; row++)
                    {
                        float a = row / 8f, b = (row + 1) / 8f;
                        Vector3 first = RoofPoint(x, a, side, width, depth, height), second = RoofPoint(x, b, side, width, depth, height);
                        Beam("Ink tile stroke", first, second, .025f, ink, false, group);
                    }
                }
            }
            Block("Elm door", new Vector3(0, 1.25f, -depth * .5f - .055f), new Vector3(1.23f, 1.92f, .1f), wood, false, group);
            for (int i = 0; i < 6; i++) Block("Door plank", new Vector3(-.5f + .2f * i, 1.25f, -depth * .5f - .115f), new Vector3(.018f, 1.87f, .015f), ink, false, group);
            Sphere("Door latch", new Vector3(.36f, 1.14f, -depth * .5f - .15f), new Vector3(.07f, .07f, .04f), path, group);
            foreach (int side in new[] { -1, 1 }) Window(new Vector3(side * width * .3f, 1.85f, -depth * .5f - .068f), group);
            Block("Threshold", new Vector3(0, .1f, -depth * .5f - .6f), new Vector3(1.7f, .2f, .75f), stone, true, group);
            LanternLocal(new Vector3(1.05f, 2.4f, -depth * .5f - .45f), group);
        }

        static Vector3 RoofPoint(float x, float fraction, int side, float width, float depth, float height)
        {
            float nx = x / ((width + 1.2f) * .5f);
            return new Vector3(x, height + .117f + 1.4f * (1 - fraction) + .34f * Mathf.Pow(fraction, 5) + .13f * Mathf.Pow(Mathf.Abs(nx), 6), side * fraction * (depth + 1.35f) * .5f);
        }

        void Window(Vector3 p, Transform parent)
        {
            Block("Paper lattice window", p, new Vector3(1.2f, 1.15f, .085f), lightPaper, false, parent);
            for (int i = 0; i <= 4; i++)
            {
                Block("Window upright", p + new Vector3(-.6f + .3f * i, 0, -.055f), new Vector3(.05f, 1.24f, .035f), wood, false, parent);
                Block("Window crossbar", p + new Vector3(0, -.575f + .2875f * i, -.055f), new Vector3(1.28f, .045f, .035f), wood, false, parent);
            }
        }

        void Stall()
        {
            var stall = new GameObject("Master Chen's soy sauce counter").transform; stall.SetParent(root); stall.position = new Vector3(22, 0, 3.8f);
            for (int sx = -1; sx <= 1; sx += 2) for (int sz = -1; sz <= 1; sz += 2)
                Block("Market awning post", new Vector3(sx * 2.25f, 1.65f, sz * 1.25f), new Vector3(.15f, 3.3f, .15f), wood, true, stall);
            var canopy = MeshObject("Cinnabar swept market canopy", MeshCraft.Roof(5.6f, 3.5f, .53f), red, false, stall); canopy.transform.localPosition = Vector3.up * 3;
            Block("Low soy counter", new Vector3(0, .62f, -.9f), new Vector3(3.6f, 1.24f, .7f), wood, true, stall);
            Block("Counter slab", new Vector3(0, 1.28f, -.9f), new Vector3(3.86f, .1f, .87f), path, false, stall);
            for (int i = 0; i < 5; i++) Vessel(new Vector3(-1.35f + i * .66f, 1.33f, -.95f), .16f, .35f, jade, stall);
            for (int i = 0; i < 3; i++) Vessel(new Vector3(-1.5f + i * 1.4f, 0, 1.5f), .52f, 1.2f, wood, stall);
            Block("Soy shop sign", new Vector3(0, 2.58f, -1.31f), new Vector3(2.8f, .6f, .12f), lightPaper, false, stall);
            Text("CHEN'S SOY", new Vector3(0, 2.59f, -1.385f), .10f, ink.color, stall);
            LanternLocal(new Vector3(-1.65f, 2.5f, -1.55f), stall);
            LanternLocal(new Vector3(1.65f, 2.5f, -1.55f), stall);
        }

        void Garden()
        {
            Willow(new Vector3(-6.3f, 0, 12), 5.5f);
            Willow(new Vector3(6.6f, 0, -9.8f), 5.1f);
            Willow(new Vector3(-7.2f, 0, -12), 4.6f);
            Willow(new Vector3(8.5f, 0, 15.8f), 4.5f);
            Tree(new Vector3(-30, 0, 12), 4.6f); Tree(new Vector3(-16.5f, 0, -14), 4.3f);
            Tree(new Vector3(30, 0, 12), 4.8f); Tree(new Vector3(24, 0, -17), 4.1f);
            for (int side = -1; side <= 1; side += 2)
                for (int i = 0; i < 32; i++)
                {
                    float x = side * Jitter(7, 32), z = Jitter(-20, 20);
                    if (Mathf.Abs(z) < 3 || Occupied(x, z)) continue;
                    Grass(new Vector3(x, .01f, z));
                    if (i % 4 == 0) Sphere("Weathered garden rock", new Vector3(x + .65f, .18f, z), new Vector3(.95f, .5f, .7f), stone);
                }
            Bamboo(new Vector3(-30, 0, -4), 9); Bamboo(new Vector3(30, 0, 17), 12); Bamboo(new Vector3(12, 0, -16), 8);
            Fence(new Vector3(-29, 0, 3.8f), new Vector3(-27, 0, 3.8f));
            Fence(new Vector3(-20.5f, 0, 3.8f), new Vector3(-18.3f, 0, 3.8f));
            Fence(new Vector3(-28, 0, 10), new Vector3(-28, 0, 15));
            for (int i = 0; i < 7; i++)
                for (int j = 0; j < 3; j++)
                    Sphere("Vegetable patch leaf", new Vector3(-26.5f + i * .42f, .18f, 11.2f + j * .48f), new Vector3(.4f, .25f, .33f), leaves);
            Seal(new Vector3(-14, .34f, -9), 0, "The river's first mark");
            Seal(new Vector3(9.5f, .4f, 9), 1, "Tea garden ink seal");
            Seal(new Vector3(27, .35f, -7), 2, "East courtyard ink seal");
        }

        static bool Occupied(float x, float z) =>
            (Mathf.Abs(x + 24) < 4 && Mathf.Abs(z - 7) < 3.5f) ||
            (Mathf.Abs(x + 15) < 3.5f && Mathf.Abs(z - 8.8f) < 3) ||
            (Mathf.Abs(x + 23) < 4 && Mathf.Abs(z + 8) < 3.5f) ||
            (Mathf.Abs(x - 12.8f) < 4.2f && Mathf.Abs(z - 7.2f) < 3.5f) ||
            (Mathf.Abs(x - 23) < 4.5f && Mathf.Abs(z - 6.5f) < 5) ||
            (Mathf.Abs(x - 15.4f) < 4 && Mathf.Abs(z + 8.2f) < 3.5f) ||
            (Mathf.Abs(x - 28.5f) < 3.5f && Mathf.Abs(z + 12.8f) < 3.5f);

        void People()
        {
            var player = Character("Xiao An • traveler", new Vector3(-23, .2f, 0), red, true);
            player.transform.rotation = Quaternion.Euler(0, 70, 0);
            var body = player.AddComponent<CharacterController>(); body.height = 1.7f; body.radius = .3f;
            body.center = new Vector3(0, .85f, 0); body.stepOffset = .32f; body.slopeLimit = 48;
            // Keep sub-millimetre steps at high/headless frame rates instead of discarding movement.
            body.minMoveDistance = 0;
            player.AddComponent<ThirdPersonMotor>();
            NPC("Mother", MotherPosition, jade, InteractionKind.Mother, 180);
            NPC("Master Chen", MerchantPosition, ink, InteractionKind.Merchant, 180);
            NPC("Grandfather Liu", ElderPosition, paper, InteractionKind.Elder, 190);
        }

        GameObject Character(string name, Vector3 p, Material robe, bool player)
        {
            bool wasMoving = movingHierarchy; movingHierarchy = true;
            var person = new GameObject(name); person.transform.SetParent(root); person.transform.position = p;
            // Player is excluded from camera casts; scenery and NPC collisions remain on the default layer.
            if (player) person.layer = 2;
            var animation = person.AddComponent<InkCharacter>();
            Transform parent = person.transform;
            var tunic = MeshObject("Ink-dyed cotton tunic", MeshCraft.TaperedCylinder(.37f, .28f, .64f), robe, false, parent);
            tunic.transform.localPosition = new Vector3(0, .52f, 0);
            Block("Sash", new Vector3(0, .85f, 0), new Vector3(.64f, .1f, .5f), wood, false, parent);
            Beam("Crossed robe collar", new Vector3(-.18f, 1.12f, .26f), new Vector3(.17f, .87f, .28f), .055f, lightPaper, false, parent);
            Beam("Inner collar", new Vector3(.18f, 1.12f, .26f), new Vector3(0, .99f, .29f), .045f, lightPaper, false, parent);
            animation.Head = new GameObject("Animated head").transform; animation.Head.SetParent(parent, false); animation.Head.localPosition = new Vector3(0, 1.34f, 0);
            Sphere("Face", Vector3.zero, new Vector3(.4f, .43f, .38f), skin, animation.Head);
            Sphere("Ink hair", new Vector3(0, .15f, -.04f), new Vector3(.44f, .23f, .41f), ink, animation.Head);
            Sphere("Hair bun", new Vector3(0, .28f, -.12f), new Vector3(.21f, .2f, .22f), ink, animation.Head);
            Sphere("Left eye", new Vector3(-.075f, .01f, .177f), new Vector3(.036f, .035f, .024f), ink, animation.Head);
            Sphere("Right eye", new Vector3(.075f, .01f, .177f), new Vector3(.036f, .035f, .024f), ink, animation.Head);
            Sphere("Nose", new Vector3(0, -.045f, .188f), new Vector3(.04f, .045f, .035f), skin, animation.Head);
            animation.LeftArm = Limb("Left sleeve", new Vector3(-.33f, 1.1f, 0), new Vector3(.2f, .42f, .23f), robe, parent, true);
            animation.RightArm = Limb("Right sleeve", new Vector3(.33f, 1.1f, 0), new Vector3(.2f, .42f, .23f), robe, parent, true);
            animation.LeftLeg = Limb("Left trouser", new Vector3(-.14f, .56f, 0), new Vector3(.2f, .47f, .23f), ink, parent, false);
            animation.RightLeg = Limb("Right trouser", new Vector3(.14f, .56f, 0), new Vector3(.2f, .47f, .23f), ink, parent, false);
            movingHierarchy = wasMoving;
            return person;
        }

        Transform Limb(string name, Vector3 pivot, Vector3 size, Material mat, Transform parent, bool arm)
        {
            var joint = new GameObject(name).transform; joint.SetParent(parent, false); joint.localPosition = pivot;
            Block(name + " fabric", new Vector3(0, -size.y * .5f, 0), size, mat, false, joint);
            if (arm) Sphere("Hand", new Vector3(0, -size.y - .025f, 0), new Vector3(.13f, .17f, .14f), skin, joint);
            else Block("Cloth shoe", new Vector3(0, -size.y, .05f), new Vector3(.22f, .13f, .35f), wood, false, joint);
            return joint;
        }

        void NPC(string name, Vector3 p, Material robe, InteractionKind kind, float rotation)
        {
            var npc = Character(name, p, robe, false); npc.transform.rotation = Quaternion.Euler(0, rotation, 0);
            var col = npc.AddComponent<CapsuleCollider>(); col.radius = .28f; col.height = 1.65f; col.center = new Vector3(0, .825f, 0);
            var item = npc.AddComponent<Interactable>(); item.Kind = kind; item.DisplayName = name;
        }

        void CreateCamera()
        {
            var cameraObject = new GameObject("Scroll view • third person orbit"); cameraObject.transform.SetParent(root);
            cameraObject.tag = "MainCamera";
            var camera = cameraObject.AddComponent<Camera>(); camera.fieldOfView = 49; camera.nearClipPlane = .08f; camera.farClipPlane = 160;
            camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = RenderSettings.fogColor;
            cameraObject.AddComponent<AudioListener>();
            var orbit = cameraObject.AddComponent<OrbitCamera>(); orbit.Target = UnityEngine.Object.FindFirstObjectByType<ThirdPersonMotor>().transform;
            cameraObject.transform.position = new Vector3(-31, 7, -8); cameraObject.transform.LookAt(orbit.Target.position + Vector3.up);
        }

        void Seal(Vector3 p, int index, string name)
        {
            bool wasMoving = movingHierarchy; movingHierarchy = true;
            var seal = new GameObject(name); seal.transform.SetParent(root); seal.transform.position = p;
            var stamp = Block("Cinnabar carved seal", Vector3.zero, new Vector3(.39f, .38f, .39f), red, false, seal.transform);
            Sphere("Seal jade handle", Vector3.up * .29f, new Vector3(.26f, .28f, .26f), jade, seal.transform);
            Block("Ink base", Vector3.down * .195f, new Vector3(.43f, .045f, .43f), ink, false, seal.transform);
            var item = seal.AddComponent<Interactable>(); item.Kind = InteractionKind.Seal; item.SealIndex = index; item.DisplayName = "Collect ink seal";
            var pulse = seal.AddComponent<SealPulse>(); pulse.BaseHeight = p.y;
            movingHierarchy = wasMoving;
            Sphere("Seal resting stone", new Vector3(p.x, .12f, p.z), new Vector3(1.1f, .28f, .85f), path);
        }

        void Tree(Vector3 p, float height)
        {
            Beam("Old village tree trunk", p, p + Vector3.up * height * .85f, .4f, wood, true);
            for (int i = 0; i < 6; i++)
            {
                float angle = i * Mathf.PI / 3;
                var top = p + new Vector3(Mathf.Cos(angle) * 1.3f, height * .78f + Jitter(-.3f, .5f), Mathf.Sin(angle) * 1.3f);
                Beam("Ink tree branch", p + Vector3.up * height * .56f, top, .14f, wood);
                Sphere("Brushed green canopy", top, new Vector3(2.5f, 1.3f, 2.3f), i % 2 == 0 ? leaves : jade);
            }
        }

        void Willow(Vector3 p, float height)
        {
            Beam("Willow trunk", p, p + new Vector3(.4f, height * .8f, 0), .34f, wood, true);
            for (int i = 0; i < 8; i++)
            {
                float angle = i * Mathf.PI * .25f;
                var end = p + new Vector3(Mathf.Cos(angle) * 2.3f, height - .65f + Jitter(-.3f, .3f), Mathf.Sin(angle) * 2.3f);
                Beam("Willow reaching branch", p + new Vector3(.3f, height * .65f, 0), end, .11f, wood);
                Sphere("Willow wash crown", end, new Vector3(2.7f, 1.0f, 2.1f), i % 2 == 0 ? leaves : jade);
                for (int j = 0; j < 4; j++)
                {
                    Vector3 a = end + new Vector3(Jitter(-.8f, .8f), -.2f, Jitter(-.65f, .65f));
                    var frond = Beam("Drooping willow ink stroke", a, a + new Vector3(.12f, -Jitter(1.1f, 2.3f), .08f), .09f, leaves);
                    frond.GetComponent<Renderer>().shadowCastingMode = ShadowCastingMode.Off;
                }
            }
        }

        void Bamboo(Vector3 p, int count)
        {
            for (int i = 0; i < count; i++)
            {
                Vector3 start = p + new Vector3(Jitter(-1.3f, 1.3f), 0, Jitter(-1.3f, 1.3f)); float height = Jitter(2.2f, 4.2f);
                Beam("Bamboo stalk", start, start + Vector3.up * height, .08f, leaves);
                for (int n = 1; n < 5; n++)
                {
                    Vector3 joint = start + Vector3.up * height * n / 5;
                    Sphere("Bamboo joint", joint, new Vector3(.13f, .045f, .13f), jade);
                    for (int s = -1; s <= 1; s += 2)
                        Beam("Bamboo leaf stroke", joint, joint + new Vector3(s * .6f, .3f, Jitter(-.25f, .25f)), .05f, leaves);
                }
            }
        }

        void Reeds(Vector3 p, int count)
        {
            for (int i = 0; i < count; i++)
            {
                var start = p + new Vector3(Jitter(-.3f, .3f), -.05f, Jitter(-.4f, .4f));
                Vector3 top = start + new Vector3(Jitter(-.1f, .1f), Jitter(.65f, 1.35f), Jitter(-.1f, .1f));
                Beam("River reed", start, top, .035f, leaves);
                Beam("Reed seed head", top, top + Vector3.up * .18f, .07f, path);
            }
        }

        void Grass(Vector3 p)
        {
            for (int i = 0; i < 5; i++)
            {
                var start = p + new Vector3(Jitter(-.2f, .2f), 0, Jitter(-.2f, .2f));
                Beam("Meadow brush grass", start, start + new Vector3(Jitter(-.17f, .17f), Jitter(.25f, .55f), Jitter(-.17f, .17f)), .045f, leaves);
            }
        }

        void Fence(Vector3 from, Vector3 to)
        {
            int posts = Mathf.CeilToInt(Vector3.Distance(from, to));
            for (int i = 0; i <= posts; i++) Block("Courtyard fence post", Vector3.Lerp(from, to, i / (float)posts) + Vector3.up * .45f, new Vector3(.11f, .9f, .11f), wood, true);
            Beam("Fence upper rail", from + Vector3.up * .72f, to + Vector3.up * .72f, .07f, wood);
            Beam("Fence lower rail", from + Vector3.up * .34f, to + Vector3.up * .34f, .07f, wood);
        }

        void Bench(Vector3 p, float angle)
        {
            var group = new GameObject("Riverside timber bench").transform; group.SetParent(root); group.position = p; group.rotation = Quaternion.Euler(0, angle, 0);
            Block("Bench seat", new Vector3(0, .5f, 0), new Vector3(2.3f, .14f, .52f), wood, true, group);
            Block("Bench left foot", new Vector3(-.85f, .24f, 0), new Vector3(.2f, .48f, .46f), wood, false, group);
            Block("Bench right foot", new Vector3(.85f, .24f, 0), new Vector3(.2f, .48f, .46f), wood, false, group);
        }

        void Vessel(Vector3 p, float radius, float height, Material material, Transform parent = null)
        {
            var vase = MeshObject("Handmade soy jar", MeshCraft.TaperedCylinder(radius * .75f, radius, height), material, false, parent);
            vase.transform.localPosition = p;
            var lid = MeshObject("Porcelain jar lid", MeshCraft.TaperedCylinder(radius * 1.04f, radius * .96f, .05f), ink, false, parent);
            lid.transform.localPosition = p + Vector3.up * height;
            Block("Paper jar label", p + new Vector3(0, height * .5f, -radius * .9f), new Vector3(radius * .8f, height * .43f, .04f), lightPaper, false, parent);
        }

        void Boat(Vector3 p)
        {
            var boat = new GameObject("Flat-bottom river skiff").transform; boat.SetParent(root); boat.position = p; boat.rotation = Quaternion.Euler(0, 8, 0);
            Block("Boat floor", new Vector3(0, .09f, 0), new Vector3(1.3f, .13f, 3.7f), wood, false, boat);
            Block("Left gunwale", new Vector3(-.65f, .31f, 0), new Vector3(.14f, .42f, 3.9f), ink, false, boat);
            Block("Right gunwale", new Vector3(.65f, .31f, 0), new Vector3(.14f, .42f, 3.9f), ink, false, boat);
            Block("Bow", new Vector3(0, .22f, 1.86f), new Vector3(1.3f, .35f, .12f), wood, false, boat);
            Block("Stern", new Vector3(0, .22f, -1.86f), new Vector3(1.3f, .35f, .12f), wood, false, boat);
            Block("Rowing seat", new Vector3(0, .4f, 0), new Vector3(1.32f, .08f, .43f), wood, false, boat);
            Beam("Resting oar", new Vector3(-.9f, .5f, -1.3f), new Vector3(1.2f, .5f, 1.2f), .07f, wood, false, boat);
        }

        void Laundry()
        {
            Vector3 a = new(-30, 2.4f, 9), b = new(-30, 2.4f, 4.5f);
            Beam("Laundry line", a, b, .025f, wood);
            Beam("Laundry post", new Vector3(-30, 0, 9), a, .09f, wood);
            Beam("Laundry post", new Vector3(-30, 0, 4.5f), b, .09f, wood);
            for (int i = 0; i < 4; i++)
                Block("Drying rice-paper cloth", new Vector3(-30, 1.95f, 5.1f + i * 1.0f), new Vector3(.025f, .85f, .63f), i % 2 == 0 ? paper : jade);
        }

        void Sign(Vector3 p, string title, float yaw)
        {
            var sign = new GameObject(title + " wayfinding").transform; sign.SetParent(root); sign.position = p; sign.rotation = Quaternion.Euler(0, yaw, 0);
            Block("Wayfinding post", new Vector3(0, .95f, 0), new Vector3(.12f, 1.9f, .12f), wood, true, sign);
            Block("Paper signboard", new Vector3(0, 1.5f, 0), new Vector3(2.2f, .6f, .13f), paper, false, sign);
            Text(title, new Vector3(0, 1.51f, -.073f), title.Length > 5 ? .075f : .12f, ink.color, sign);
        }

        void Lantern(Vector3 p)
        {
            Beam("Lantern elm pole", p, p + Vector3.up * 2.75f, .09f, wood);
            Beam("Lantern bracket", p + Vector3.up * 2.7f, p + new Vector3(.48f, 2.7f, 0), .06f, wood);
            LanternLocal(p + new Vector3(.45f, 2.33f, 0), root);
        }

        void LanternLocal(Vector3 p, Transform parent)
        {
            Sphere("Cinnabar paper lantern", p, new Vector3(.37f, .5f, .37f), red, parent);
            Block("Lantern top", p + Vector3.up * .24f, new Vector3(.23f, .05f, .23f), ink, false, parent);
            Block("Lantern bottom", p - Vector3.up * .25f, new Vector3(.23f, .05f, .23f), wood, false, parent);
            Beam("Lantern tassel", p + Vector3.down * .25f, p + Vector3.down * .48f, .04f, red, false, parent);
        }

        void Boundaries()
        {
            // Visible hedges describe the play space; invisible colliders are embedded in them.
            foreach (float z in new[] { -21.3f, 21.3f })
            {
                Block("Village hedge collision", new Vector3(-19, .6f, z), new Vector3(31, 1.5f, .8f), leaves, true);
                Block("Village hedge collision", new Vector3(19, .6f, z), new Vector3(31, 1.5f, .8f), leaves, true);
                for (int x = -33; x <= 33; x += 3)
                    if (Mathf.Abs(x) > 4) Sphere("Brushed boundary hedge", new Vector3(x, .8f, z), new Vector3(3.5f, 1.5f, 1.8f), leaves);
            }
            foreach (float x in new[] { -33.4f, 33.4f })
            {
                Block("Village edge wall", new Vector3(x, .65f, 0), new Vector3(.8f, 1.3f, 43), paper, true);
                Block("Wall ink coping", new Vector3(x, 1.32f, 0), new Vector3(1.1f, .17f, 43), ink);
            }
        }

        GameObject Block(string name, Vector3 p, Vector3 scale, Material material, bool collision = false, Transform parent = null)
            => Primitive(name, PrimitiveType.Cube, p, scale, material, collision, parent);
        GameObject Sphere(string name, Vector3 p, Vector3 scale, Material material, Transform parent = null)
            => Primitive(name, PrimitiveType.Sphere, p, scale, material, false, parent);
        GameObject Primitive(string name, PrimitiveType shape, Vector3 p, Vector3 scale, Material material, bool collision, Transform parent)
        {
            var go = GameObject.CreatePrimitive(shape); go.name = name; go.transform.SetParent(parent ? parent : root, false);
            go.transform.localPosition = p; go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = material;
            if (!movingHierarchy) sceneryRenderers.Add(go);
            if (!collision) { var collider = go.GetComponent<Collider>(); collider.enabled = false; UnityEngine.Object.Destroy(collider); }
            return go;
        }
        GameObject MeshObject(string name, Mesh mesh, Material material, bool collision = false, Transform parent = null)
        {
            var go = new GameObject(name); go.transform.SetParent(parent ? parent : root, false);
            go.AddComponent<MeshFilter>().sharedMesh = resources.Own(mesh); go.AddComponent<MeshRenderer>().sharedMaterial = material;
            if (!movingHierarchy) sceneryRenderers.Add(go);
            if (collision) go.AddComponent<MeshCollider>().sharedMesh = mesh;
            return go;
        }
        GameObject Beam(string name, Vector3 a, Vector3 b, float thickness, Material mat, bool collision = false, Transform parent = null)
        {
            var beam = Block(name, (a + b) * .5f, new Vector3(thickness, Vector3.Distance(a, b), thickness), mat, collision, parent);
            beam.transform.localRotation = Quaternion.FromToRotation(Vector3.up, (b - a).normalized); return beam;
        }
        void Text(string value, Vector3 p, float size, Color color, Transform parent)
        {
            var go = new GameObject(value); go.transform.SetParent(parent, false); go.transform.localPosition = p;
            go.transform.localRotation = Quaternion.identity;
            var text = go.AddComponent<TextMesh>(); text.text = value; text.fontSize = 48; text.characterSize = size;
            text.anchor = TextAnchor.MiddleCenter; text.alignment = TextAlignment.Center;
            // Legacy TextMesh vertex colors are supplied in linear space for the project's linear renderer.
            text.color = QualitySettings.activeColorSpace == ColorSpace.Linear ? color.linear : color;
            text.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf"); go.GetComponent<MeshRenderer>().sharedMaterial = text.font.material;
            go.GetComponent<MeshRenderer>().shadowCastingMode = ShadowCastingMode.Off;
        }
        Material Paint(string name, string hex, Texture2D grain, float strength)
        {
            var mat = resources.Own(new Material(Shader.Find("ScrollSeeker/Ink Wash")) { name = name, enableInstancing = true });
            mat.SetColor("_Color", ColorOf(hex)); mat.SetTexture("_Paper", grain); mat.SetFloat("_Grain", strength); return mat;
        }
        static Color ColorOf(string hex) { ColorUtility.TryParseHtmlString(hex, out var color); return color; }
        float Jitter(float min, float max) => min + (float)random.NextDouble() * (max - min);
        static Texture2D PaperTexture()
        {
            var texture = new Texture2D(128, 128, TextureFormat.RGB24, false) { name = "Original woven paper grain", wrapMode = TextureWrapMode.Repeat, filterMode = FilterMode.Bilinear };
            var pixels = new Color[128 * 128];
            for (int y = 0; y < 128; y++) for (int x = 0; x < 128; x++)
            {
                float n = .38f + Mathf.PerlinNoise(x * .13f, y * .13f) * .25f + Mathf.PerlinNoise(x * .63f + 17, y * .63f + 7) * .21f;
                pixels[y * 128 + x] = new Color(n, n, n, 1);
            }
            texture.SetPixels(pixels); texture.Apply(); return texture;
        }
    }
}
