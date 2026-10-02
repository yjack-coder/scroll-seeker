using UnityEngine;
namespace ScrollSeeker
{
    [RequireComponent(typeof(CharacterController))]
    public sealed class ThirdPersonMotor : MonoBehaviour
    {
        public bool Paused;
        public float Speed { get; private set; }
        public Vector3? DrivenDirection;
        CharacterController body;
        float falling;
        void Awake() { body = GetComponent<CharacterController>(); }
        void Update()
        {
            var input = DrivenDirection ?? new Vector3(Input.GetAxisRaw("Horizontal"), 0, Input.GetAxisRaw("Vertical"));
            Vector3 forward = Camera.main.transform.forward; forward.y = 0; forward.Normalize();
            Vector3 right = Camera.main.transform.right; right.y = 0; right.Normalize();
            Vector3 direction = DrivenDirection.HasValue ? input : forward * input.z + right * input.x;
            Step(Paused ? Vector3.zero : Vector3.ClampMagnitude(direction, 1), Time.deltaTime);
        }
        public void Step(Vector3 direction, float delta)
        {
            Speed = direction.magnitude * (Input.GetKey(KeyCode.LeftShift) ? 6f : 4f);
            if (body.isGrounded && falling < 0) falling = -2;
            falling += Physics.gravity.y * delta;
            body.Move((direction.normalized * Speed + Vector3.up * falling) * delta);
            if (direction.sqrMagnitude > .01f)
                transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(direction), 12 * delta);
            if (transform.position.y < -3) Teleport(new Vector3(-23, .2f, 0));
        }
        public void Teleport(Vector3 point)
        { body.enabled = false; transform.position = point; body.enabled = true; falling = 0; }
    }
}
