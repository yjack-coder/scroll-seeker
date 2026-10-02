using UnityEngine;

namespace ScrollSeeker
{
    /// <summary>Restrained motion helps small collectibles read against the paper landscape.</summary>
    public sealed class SealPulse : MonoBehaviour
    {
        public float BaseHeight;
        void Update()
        {
            var p = transform.position; p.y = BaseHeight + Mathf.Sin(Time.time * 2.2f) * .075f; transform.position = p;
            transform.Rotate(0, Time.deltaTime * 25, 0, Space.World);
        }
    }
}
