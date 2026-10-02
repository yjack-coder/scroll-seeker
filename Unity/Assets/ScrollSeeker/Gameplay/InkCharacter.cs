using UnityEngine;
namespace ScrollSeeker
{
    public sealed class InkCharacter : MonoBehaviour
    {
        public Transform LeftArm, RightArm, LeftLeg, RightLeg, Head;
        ThirdPersonMotor motor;
        void Start() { motor = GetComponent<ThirdPersonMotor>(); }
        void LateUpdate()
        {
            float speed = motor ? motor.Speed : 0;
            float stride = Mathf.Sin(Time.time * 10) * Mathf.Min(speed * 8, 35);
            if (LeftArm) LeftArm.localRotation = Quaternion.Euler(stride, 0, -8);
            if (RightArm) RightArm.localRotation = Quaternion.Euler(-stride, 0, 8);
            if (LeftLeg) LeftLeg.localRotation = Quaternion.Euler(-stride, 0, 0);
            if (RightLeg) RightLeg.localRotation = Quaternion.Euler(stride, 0, 0);
            if (Head) Head.localRotation = Quaternion.Euler(0, Mathf.Sin(Time.time * 1.2f) * (speed > 0 ? 3 : 9), 0);
        }
    }
}
