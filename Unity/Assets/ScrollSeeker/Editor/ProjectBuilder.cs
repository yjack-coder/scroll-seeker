using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
namespace ScrollSeeker.Editor
{
    public static class ProjectBuilder
    {
        public const string ScenePath = "Assets/ScrollSeeker/Scenes/Riverside.unity";
        [MenuItem("Scroll Seeker/Prepare playable scene")]
        public static void Prepare()
        {
            PlayerSettings.companyName = "Scroll Seeker";
            PlayerSettings.productName = "Scroll Seeker — A Life Along the River";
            PlayerSettings.bundleVersion = "0.1.0";
            PlayerSettings.SetApplicationIdentifier(UnityEditor.Build.NamedBuildTarget.Standalone, "com.scrollseeker.riverside");
            PlayerSettings.defaultScreenWidth = 1440; PlayerSettings.defaultScreenHeight = 900;
            PlayerSettings.fullScreenMode = FullScreenMode.Windowed;
            PlayerSettings.resizableWindow = true;
            PlayerSettings.runInBackground = true;
            PlayerSettings.colorSpace = ColorSpace.Linear;
            PlayerSettings.SetScriptingBackend(UnityEditor.Build.NamedBuildTarget.Standalone, ScriptingImplementation.Mono2x);
            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.StandaloneOSX, false);
            PlayerSettings.SetGraphicsAPIs(BuildTarget.StandaloneOSX, new[] { GraphicsDeviceType.Metal });
            // The compact prototype uses Unity's built-in input axes and built-in renderer.
            var settings = new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/ProjectSettings.asset")[0]);
            var input = settings.FindProperty("activeInputHandler");
            if (input != null) { input.intValue = 0; settings.ApplyModifiedPropertiesWithoutUndo(); }
            QualitySettings.antiAliasing = 4;
            QualitySettings.shadowDistance = 65;
            QualitySettings.shadows = ShadowQuality.All;
            QualitySettings.shadowResolution = ShadowResolution.High;
            GraphicsSettings.defaultRenderPipeline = null;
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            new GameObject("Scroll Seeker · Riverside journey").AddComponent<GameSession>();
            EditorSceneManager.SaveScene(scene, ScenePath);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
            AssetDatabase.SaveAssets();
            Debug.Log("SCROLL_SEEKER_SCENE_READY " + ScenePath);
        }
        [MenuItem("Scroll Seeker/Build macOS demo")]
        public static void BuildMac()
        {
            Prepare();
            var output = Environment.GetEnvironmentVariable("SCROLL_SEEKER_BUILD") ?? "Builds/Scroll Seeker.app";
            Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(output)));
            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            {
                scenes = new[] { ScenePath }, locationPathName = output,
                target = BuildTarget.StandaloneOSX,
                options = BuildOptions.Development
            });
            Debug.Log("SCROLL_SEEKER_BUILD " + report.summary.result + " " + report.summary.totalSize);
            if (report.summary.result != BuildResult.Succeeded) throw new Exception("macOS build failed");
        }
    }
}
