using UnityEngine;

public class GrassManager : MonoBehaviour
{
    public Vector3 WindDirection = new Vector3(-1.0f, 0.0f, 1.0f).normalized;
    public float WindSpeed = 8.0f;
    public float WindStrength = 0.8f;

    void FixedUpdate()
    {
        // Customizable
        Shader.SetGlobalVector("_WindDirection", WindDirection);
        Shader.SetGlobalFloat("_WindSpeed", WindSpeed);
        Shader.SetGlobalFloat("_WindStrength", WindStrength);

        // Constrained
        Shader.SetGlobalVector("_CameraTargetPos", Vector3.zero);
        Shader.SetGlobalVector("_CameraForwardVec", Camera.main.transform.forward);
    }
}
