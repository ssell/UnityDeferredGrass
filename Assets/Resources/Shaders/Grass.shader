Shader "VertexFragment/Grass"
{
    Properties
    {
        _Texture ("Texture", 2D) = "white" {}                               // Sampled texture for grass appearance.
        _BaseColor ("BaseColor", Color) = (1, 1, 1, 1)                      // Grass base color. Used to make gradient with tip color.
        _TipColor ("TipColor", Color) = (1, 1, 1, 1)                        // Grass tip color. Used to make gradient with base color.
        _GrowthMap ("Growth Map", 2D) = "white" {}                          // Growth/height map
        _Dimensions ("Dimensions", Vector) = (1, 1, 1, 0)                   // (width, height, density, unused)
        _WindMap ("Wind Map", 2D) = "black" {}                              // Wind distortion map
        _WindDirection ("Wind Direction", Vector) = (1, 0, 0, 0)            // Direction that the _WindMap is scrolled
        _WindProperties ("Wind Properties", Vector) = (1, 0.1, 0, 0.5)      // (speed, strength, highlight factor, unused)
        _BendProperties ("Bend Properties", Vector) = (0.1, 0.5, 0, 0)      // (min bend, max bend, unused, unused)
        _DisruptionMap ("Disruption Map", 2D) = "white" {}                  // (flattening modifier, cut modifier, burn modifier, growth modifier) all on range [0=no modifier, 1=full modifier]
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        Pass
        {
            Name "DEFERRED"
            Tags { "LightMode" = "Deferred" }

            AlphaToMask On
            Cull Off

        CGPROGRAM
            #pragma vertex VertTessMain
            #pragma fragment FragMain
            #pragma hull HullMain
            #pragma domain DomainMain
            #pragma geometry GeometryMain

            #pragma target 4.6
            #pragma exclude_renderers nomrt
            #pragma require 2darray

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

