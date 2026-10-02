using UnityEngine;
namespace ScrollSeeker
{
    public sealed class OrbitCamera : MonoBehaviour
    {
        public Transform Target;
        public bool Locked;
        float yaw = 65, pitch = 30, distance = 10;
        void LateUpdate()
        {
            if (!Target) return;
            if (!Locked && Input.GetMouseButton(1))
            { yaw += Input.GetAxis("Mouse X") * 3; pitch = Mathf.Clamp(pitch - Input.GetAxis("Mouse Y") * 2, 15, 65); }
            if (!Locked) distance = Mathf.Clamp(distance - Input.mouseScrollDelta.y, 5, 15);
            var pivot = Target.position + Vector3.up * 1.5f;
            Vector3 offset = Quaternion.Euler(pitch, yaw, 0) * Vector3.back * distance;
            float length = distance;
            if (Physics.SphereCast(pivot, .25f, offset.normalized, out var hit, distance, 1 << 0, QueryTriggerInteraction.Ignore))
                length = Mathf.Max(.8f, hit.distance - .15f);
            transform.position = pivot + offset.normalized * length;
            transform.LookAt(pivot);
        }
    }
}
