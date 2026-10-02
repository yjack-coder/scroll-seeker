using System.Collections.Generic;
using UnityEngine;

namespace ScrollSeeker
{
    /// <summary>Scene reloads also release runtime meshes, materials, and generated texture memory.</summary>
    public sealed class WorldResources : MonoBehaviour
    {
        readonly List<Object> owned = new();
        public T Own<T>(T resource) where T : Object { owned.Add(resource); return resource; }
        void OnDestroy()
        {
            foreach (Object resource in owned)
                if (resource) Destroy(resource);
            owned.Clear();
        }
    }
}
