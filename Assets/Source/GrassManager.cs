using UnityEngine;
using UnityEngine.UI;

public class GrassManager : MonoBehaviour
{
    public static Material SharedMaterial;
    public Material Material;

    public Vector3 WindDirection = new Vector3(-1.0f, 0.0f, 1.0f).normalized;

    public Slider DensitySlider;
    public Slider WindSpeedSlider;
    public Slider WindStrengthSlider;

    void FixedUpdate()
    {
        // Globals
        Shader.SetGlobalVector("_WindDirection", WindDirection);
        Shader.SetGlobalFloat("_WindSpeed", WindSpeedSlider.value);
        Shader.SetGlobalFloat("_WindStrength", WindStrengthSlider.value);
        Shader.SetGlobalVector("_CameraTargetPos", Vector3.zero);
        Shader.SetGlobalVector("_CameraForwardVec", Camera.main.transform.forward);

        // Material Specific
        Vector4 dimensions = Material.GetVector("_Dimensions");
        
        if (Mathf.Abs(dimensions.z - DensitySlider.value) > float.Epsilon)
        {
            dimensions.z = DensitySlider.value;
            Material.SetVector("_Dimensions", dimensions);
        }
        

        SharedMaterial = Material;
    }
}
