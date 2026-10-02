using UnityEngine;
namespace ScrollSeeker
{
    public enum InteractionKind { Mother, Merchant, Elder, Seal }
    public sealed class Interactable : MonoBehaviour
    {
        public InteractionKind Kind;
        public string DisplayName;
        public int SealIndex;
        public Vector3 Point => transform.position + Vector3.up * 1.4f;
        public bool Available(Journey journey) => Kind != InteractionKind.Seal || (journey.Data.keepsakes & (1 << SealIndex)) == 0;
    }
}
