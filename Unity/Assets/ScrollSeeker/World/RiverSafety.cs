using UnityEngine;

namespace ScrollSeeker
{
    /// <summary>A gentle bank recovery prevents falls into water from stranding the quest.</summary>
    public sealed class RiverSafety : MonoBehaviour
    {
        public GameSession Session;
        float cooldown;
        void Update()
        {
            if (!Session || !Session.Player) return;
            cooldown -= Time.deltaTime;
            Vector3 p = Session.Player.transform.position;
            if (cooldown > 0 || Mathf.Abs(p.x) > 3.65f || p.y > -.32f) return;
            Session.Player.Teleport(new Vector3(p.x < 0 ? -4.8f : 4.8f, .2f, Mathf.Clamp(p.z, -19.5f, 19.5f)));
            cooldown = 2;
            Session.Notify("The current is strong. Cross safely at Willow Bridge.");
        }
    }
}
