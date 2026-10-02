using NUnit.Framework;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace ScrollSeeker.Tests
{
    public sealed class RiversideSceneSerializationTests
    {
        const string Riverside = "Assets/ScrollSeeker/Scenes/Riverside.unity";

        [Test]
        public void SavedRiversideSceneDoesNotDeserializeAnOpenDialogue()
        {
            // Inspect the actual saved scene in EditMode: Awake does not run, so it
            // cannot hide a serialized transient value by resetting it at startup.
            var active = SceneManager.GetActiveScene();
            var scene = SceneManager.GetSceneByPath(Riverside);
            bool openedForTest = !scene.IsValid() || !scene.isLoaded;
            if (openedForTest) scene = EditorSceneManager.OpenScene(Riverside, OpenSceneMode.Additive);
            try
            {
                GameSession savedSession = null;
                int count = 0;
                foreach (var root in scene.GetRootGameObjects())
                    foreach (var candidate in root.GetComponentsInChildren<GameSession>(true))
                    { savedSession = candidate; count++; }
                Assert.That(count, Is.EqualTo(1), "Riverside must contain exactly one gameplay session.");
                Assert.That(savedSession.DialogueOpen, Is.False, "A saved scene must launch without a dialogue modal.");
                var serialized = new SerializedObject(savedSession);
                Assert.That(serialized.FindProperty(nameof(GameSession.SavePathOverride)), Is.Not.Null);
                foreach (var transient in new[]
                {
                    nameof(GameSession.Dialogue), nameof(GameSession.DialogueTitle), nameof(GameSession.Toast),
                    nameof(GameSession.PourProgress), nameof(GameSession.Balance), nameof(GameSession.SoundEnabled)
                })
                    Assert.That(serialized.FindProperty(transient), Is.Null, transient + " must remain runtime-only.");
            }
            finally
            {
                if (active.IsValid() && active.isLoaded) SceneManager.SetActiveScene(active);
                if (openedForTest && scene.IsValid() && scene.isLoaded) EditorSceneManager.CloseScene(scene, true);
            }
        }
    }
}
