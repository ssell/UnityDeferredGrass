using UnityEngine;

public class SharedGrassMaterial : MonoBehaviour
{
    private void FixedUpdate()
    {
        MeshRenderer renderer = gameObject.GetComponent<MeshRenderer>();

        if (renderer != null)
        {
            renderer.material = GrassManager.SharedMaterial;
        }
    }
}
