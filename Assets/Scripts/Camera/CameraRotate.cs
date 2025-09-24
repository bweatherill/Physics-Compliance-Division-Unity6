using UnityEngine;

public class CameraRotate : MonoBehaviour
{
    [Header("References")]
    [SerializeField] private Transform vcam;  // Cinemachine VCam transform

    [Header("Rotation Settings")]
    [SerializeField] private float rotationStep = 90f;
    [SerializeField] private float rotationSpeed = 10f;  // higher = faster
    [SerializeField] private bool smoothRotate = true;

    [Header("Input")]
    [SerializeField] private KeyCode rotateLeftKey = KeyCode.Tab;
    [SerializeField] private KeyCode rotateRightKey = KeyCode.R;

    private Quaternion targetRotation;
    private bool isRotating;


    void Awake() => vcam = GameObject.Find("PlayerFollowCamera").GetComponent<Transform>();
 
    void Start() => targetRotation = vcam.rotation;


    void Update()
    {
        if (Input.GetKeyDown(rotateLeftKey))  Step(-1);
        if (Input.GetKeyDown(rotateRightKey)) Step(+1);

        if (smoothRotate && isRotating)
            SmoothRotate();
    }

    private void Step(int dir)
    {
        Vector3 e = vcam.eulerAngles;
        e.y += rotationStep * dir;

        // Snap to 45 + n*90
        e.y = 45f + Mathf.Round((e.y - 45f) / 90f) * 90f;

        targetRotation = Quaternion.Euler(e);

        if (smoothRotate)
            isRotating = true;
        else
            vcam.rotation = targetRotation;
    }

    private void SmoothRotate()
    {
        vcam.rotation = Quaternion.Lerp(
            vcam.rotation,
            targetRotation,
            Time.deltaTime * rotationSpeed
        );

        if (Quaternion.Angle(vcam.rotation, targetRotation) < 0.1f)
        {
            vcam.rotation = targetRotation; // snap to finish
            isRotating = false;
        }
    }
}
