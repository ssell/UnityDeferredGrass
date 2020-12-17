Shader "VertexFragment/Grass"
{
    Properties
    {
        _AlbedoMap ("Albedo Map", 2D) = "white" {}                          // Sampled texture for grass appearance.
        _BaseColor ("BaseColor", Color) = (1, 1, 1, 1)                      // Grass base color. Used to make gradient with tip color.
        _TipColor ("TipColor", Color) = (1, 1, 1, 1)                        // Grass tip color. Used to make gradient with base color.
        _GrowthMap ("Growth Map", 2D) = "white" {}                          // Growth/height map
        _Dimensions ("Dimensions", Vector) = (1, 1, 1, 0)                   // (width, height, density, density drop-off range)
        _WindMap ("Wind Map", 2D) = "black" {}                              // Wind distortion map
        _WindHighlights ("Wind Highlights", Vector) = (0.0, 0.0, 0.0, 0.0)  // (unused, strength, highlight factor, unused)
        _BendProperties ("Bend Properties", Vector) = (0.1, 0.5, 0, 0)      // (min bend, max bend, unused, unused)
        _DisruptionMap ("Disruption Map", 2D) = "white" {}                  // (flattening modifier, cut modifier, burn modifier, growth modifier) all on range [0=no modifier, 1=full modifier]
        _DensityDropOffMap ("Density Drop-Off Map", 2D) = "white" {}        // Used to control the density modifier when further away from the camera.
        _DetailsMap ("Details Map", 2D) = "white" {}                        // Indicates where details may be placed (white). Used by the Realms Terrain

        // Wind properties (direction, speed, and strength) are passed in as Realms globals
    }

    SubShader
    {
        LOD 200

        Pass
        {
            Name "DEFERRED"
            Tags { "RenderType"="Opaque" "LightMode" = "Deferred" }

            AlphaToMask On
            Cull Off

        CGPROGRAM
            #pragma vertex VertTessMain
            #pragma fragment FragMain
            #pragma hull HullMain
            #pragma domain DomainMain
            #pragma geometry GeometryMain

            #pragma target 4.6
            #pragma multi_compile _ UNITY_HDR_ON

            #define DEFERRED_PASS
            #define GRASS_PERSPECTIVE_BEND        // The grass quads should bend upwards to face the camera at high viewing angles
            #define GRASS_WIND_HIGHLIGHT

            #include "UnityCG.cginc"
            #include "UnityGBuffer.cginc"
            #include "include/Grass.cginc"
        ENDCG
        }
    }
}