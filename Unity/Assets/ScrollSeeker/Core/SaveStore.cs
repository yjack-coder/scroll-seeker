using System;
using System.IO;
using UnityEngine;
namespace ScrollSeeker
{
    /// <summary>Validated JSON, atomic replacement, one last-good backup; independent of iOS saves.</summary>
    public sealed class SaveStore
    {
        readonly string path;
        public string LastWarning { get; private set; }
        public SaveStore(string path) { this.path = path; }
        public JourneyData Load()
        {
            LastWarning = null;
            foreach (var candidate in new[] { path, path + ".bak" })
            {
                if (!File.Exists(candidate)) continue;
                try
                {
                    var data = ReadValid(candidate);
                    if (candidate != path) LastWarning = "Recovered the previous save.";
                    return data;
                }
                catch (Exception e) when (e is IOException || e is UnauthorizedAccessException || e is ArgumentException)
                { LastWarning = "Save could not be read; using recovery or a new journey."; }
            }
            return new JourneyData();
        }
        public bool Save(JourneyData data)
        {
            try
            {
                Journey.Validate(data);
                var directory = Path.GetDirectoryName(path);
                if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
                File.WriteAllText(path + ".tmp", JsonUtility.ToJson(data, true));
                // A damaged primary must never replace the last-good recovery copy.
                if (File.Exists(path)) File.Replace(path + ".tmp", path, PrimaryIsValid() ? path + ".bak" : null);
                else File.Move(path + ".tmp", path);
                LastWarning = null; return true;
            }
            catch (Exception e) when (e is IOException || e is UnauthorizedAccessException || e is ArgumentException)
            { LastWarning = "Could not save: " + e.Message; return false; }
            finally
            {
                try { if (File.Exists(path + ".tmp")) File.Delete(path + ".tmp"); }
                catch (Exception e) when (e is IOException || e is UnauthorizedAccessException) { }
            }
        }
        bool PrimaryIsValid()
        {
            try { ReadValid(path); return true; }
            catch (Exception e) when (e is IOException || e is UnauthorizedAccessException || e is ArgumentException)
            { return false; }
        }
        static JourneyData ReadValid(string candidate)
        {
            var json = File.ReadAllText(candidate);
            if (!json.Contains("\"version\"")) throw new ArgumentException("Missing version");
            var data = JsonUtility.FromJson<JourneyData>(json);
            Journey.Validate(data);
            return data;
        }
    }
}
