/**
 * Contains the vertex, fragment, and geometry shader for terrain grass.
 * Includes Tesselation.cginc to provide the domain and hull shaders.
 *
 * The grass is composed of randomly orientated textured quads. It has control
 * parameters for: density, height, wind, and various appearance properties.
 *
 * There is an optional flag, GRASS_PERSPECTIVE_BEND, which may be #defined 
 * to enable bending of the grass at certain view angles. This helps to hide
 * gaps in between the grass quads which are visible at high angles.
 */

#ifndef VF_GRASS_INCLUDED
#define VF_GRASS_INCLUDED

#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "CommonStruct.cginc"

// -----------------------------------------------------------------------------
// Misc
// ------------------------------------------------------------------------------

struct GeometryOutput
{
    float4 position : SV_POSITION;
    float3 normal   : NORMAL;
    float2 uv       : TEXCOORD0;
    float4 tex1     : TEXCOORD1;    // Sample from _GrowthMap (r)
    float4 tex2     : TEXCOORD2;    // Sample from _WindMap (rgb), Wind bend angle (a) for highlights
    float4 tex3     : TEXCOORD3;    // Sample from _DisruptionMap (rgba)
};

UNITY_DECLARE_TEX2D(_AlbedoMap);    // Sampled texture for grass appearance.

sampler2D _GrowthMap;               // Growth/height map
float4 _GrowthMap_ST;

sampler2D _WindMap;                 // Wind distortion map
float4 _WindMap_ST;

sampler2D _DisruptionMap;           // (flattening modifier, cut modifier, burn modifier, growth modifier) all on range [0=no modifier, 1=full modifier]
float4 _DisruptionMap_ST;

float4 _BaseColor;                  // Grass base color. Used to make gradient with tip color.
float4 _TipColor;                   // Grass tip color. Used to make gradient with base color.
float4 _Dimensions;                 // (width, height, density, unused)
float4 _WindDirection;              // Direction that the _WindMap is scrolled
float4 _WindProperties;             // (speed, strength, highlight factor, unused)
float4 _BendProperties;             // (min bend, max bend, unused, unused)

#define MIN_HEIGHT_CUTOFF 0.05f

/**
 * Provides a random single output value for a 3-dimensional input value.
 * Source: https://www.shadertoy.com/view/4djSRW
 */
float Hash13(float3 p3)
{
    p3  = frac(p3 * 0.1031f);
    p3 += dot(p3, p3.yzx + 33.33f);
    return frac((p3.x + p3.y) * p3.z);
}

/**
 * Creates a rotation matrix for the given angle (radians) along the specified axis.
 * Source: https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
 */
float3x3 AngleAxis3x3(float angle, float3 axis)
{
    float c, s;
    sincos(angle, s, c);

    float t = 1 - c;
    float x = axis.x;
    float y = axis.y;
    float z = axis.z;

    return float3x3(
        t * x * x + c, t * x * y - s * z, t * x * z + s * y,
        t * x * y + s * z, t * y * y + c, t * y * z - s * x,
        t * x * z - s * y, t * y * z + s * x, t * z * z + c
    );
}

/**
 * Given a world space coordinate, returns a random rotation matrix.
 * The resulting rotation is along the tangent space up (+z).
 */
float3x3 RandomAngleTransform(float3 worldPos)
{
    float angle = Hash13(worldPos) * 2.0f - 1.0f;
    return AngleAxis3x3(angle, float3(0.0f, 0.0f, 1.0f));
}

// -----------------------------------------------------------------------------
// Vertex Shader
// -----------------------------------------------------------------------------

/**
 * Samples the growth/height map for the given world position.
 * Returned value is the height, in world units, of the grass.
 */
float SampleGrowthHeight(float3 worldPos)
{
    float2 samplePos = TRANSFORM_TEX(worldPos.xz, _GrowthMap);
    float growthMod = tex2Dlod(_GrowthMap, float4(samplePos, 0.0f, 0.0f)).r;
    
    return _Dimensions.y * growthMod;
}

/**
 * Samples the wind/distortion map for the given world position.
 * Returned value is the normalized wind direction vector.
 */
float3 SampleWindDirection(float3 worldPos)
{
    float time = _Time * _WindProperties.x;
    float2 samplePos = worldPos.xz + (normalize(_WindDirection.xy) * time);
    samplePos = TRANSFORM_TEX(samplePos, _WindMap);

    return normalize(tex2Dlod(_WindMap, float4(samplePos, 0.0f, 0.0f)).xzy * 2.0f - 1.0f);
}

/**
 * Samples the disruption map for the given world position.
 * Returned value is (flattening modifier, cut modifier, burn modifier, growth modifier).
 */
float4 SampleDisruptionMap(float3 worldPos)
{
    float2 samplePos = TRANSFORM_TEX(worldPos.xz, _DisruptionMap);
    return tex2Dlod(_DisruptionMap, float4(samplePos, 0.0f, 0.0f));
}

VertOutput VertMain(VertInput input)
{
    VertOutput output;
    
    float3 worldPos = mul(unity_ObjectToWorld, input.position).xyz;

    output.position = input.position;
    output.normal   = input.normal;
    output.tangent  = input.tangent;
    output.uv       = input.uv;
    output.tex1     = float4(SampleGrowthHeight(worldPos), 0.0f, 0.0f, 0.0f);
    output.tex2     = float4(SampleWindDirection(worldPos), 0.0f);
    output.tex3     = SampleDisruptionMap(worldPos);

    return output;
}

// Define VERT_MAIN so that the Domain shader (Tessellation.cginc) calls our override.
#define VERT_MAIN(i) VertMain(i)

// -----------------------------------------------------------------------------
// Domain and Hull Shader
// -----------------------------------------------------------------------------

float CalculateTessEdgeFactor()
{
    return _Dimensions.z;
}

float CalculateTessInsideFactor()
{
    return _Dimensions.z;
}

#define CALCULATE_TESS_EDGE_FACTOR CalculateTessEdgeFactor()
#define CALCULATE_TESS_INSIDE_FACTOR CalculateTessInsideFactor()

#include "Tessellation.cginc"

// -----------------------------------------------------------------------------
// Geometry Shader
// -----------------------------------------------------------------------------

/**
 * Builds a new vertex for the grass geometry.
 * The resulting position is in local space.
 */
GeometryOutput CalculateGeometry(
    in float3 position, 
    in float3x3 tangentToLocal, 
    in float3 offset,
    in float2 uv,
    in float4 tex1,
    in float4 tex2,
    in float4 tex3)
{
    GeometryOutput output;

    position += mul(tangentToLocal, offset);
    output.position = mul(unity_ObjectToWorld, float4(position, 1.0f));

    output.normal   = float3(0.0f, 1.0f, 0.0f);
    output.uv       = uv;
    output.tex1     = tex1;
    output.tex2     = tex2;
    output.tex3     = tex3;

    return output;
}

/**
 * Calculates whether to use the right or left vector as the normal.
 * Keep in mind that there is no culling, so the camera could be facing either side at an given time.
 * So we determine which side is facing the camera, and use the appropriate vector.
 */
void CalculateGeometryNormals(
    in float3 cameraWorldView,
    in float3 right,
    in float3 left,
    in float3 up,
    inout GeometryOutput ll,
    inout GeometryOutput lr,
    inout GeometryOutput ul,
    inout GeometryOutput ur,
    inout GeometryOutput uul,
    inout GeometryOutput uur)
{
    float dotRight = dot(cameraWorldView, right);
    float3 normal = (dotRight > 0.0f ? right : left);    // If the right is facing opposite of the camera (towards) use it.

    normal = normalize(normal + up * 20.0f);             // Now, the grass should not be looking directly along right/left as lighting will not look correct.
                                                         // Angle it upwards so that lighting correctly catches on the blades. Why `* 20`? Why not.
    ll.normal = normal;
    lr.normal = normal;
    ul.normal = normal;
    ur.normal = normal;
    uul.normal = normal;
    uur.normal = normal;
}

/**
 * Rotates the top corners of the grass quad when the camera is at a high angle.
 * The rotation is along the x-axis so that the quad faces up towards the camera.
 */
void PerformPerspectiveBend(
    in GeometryOutput ll, 
    in GeometryOutput lr, 
    inout GeometryOutput ul, 
    inout GeometryOutput ur,
    in float3 cameraWorldView,
    in float3 right, 
    in float3 left)
{
    float dotRight = dot(normalize(cameraWorldView * float3(1.0f, 0.0f, 1.0f)), right);     // Cancel out the y in the view as we only shear on the xz plane.
    float3 offsetAlong = (dotRight <= 0.0f ? right : left);                                 // If the right is same general direction as the camera view, then shear along it.
    float offset = lerp(_BendProperties.x, _BendProperties.y, clamp(abs(dotRight) * 2.0f, 0.0f, 1.0f));

    ul.position.xyz += offsetAlong * offset;
    ur.position.xyz += offsetAlong * offset;
}

/**
 * Projects the vector a onto the vector b.
 * The length of the resulting vector is on the range [0.0, length(a)]
 */
float3 ProjectOnto(
    in float3 a, 
    in float3 b)
{
    return (dot(b, a) / length(b)) * b;
}

/**
 * Given a vertex, rotates it using the provided matrix around the object origin.
 */
void RotateVertexAroundObjectOrigin(
    inout GeometryOutput vertex, 
    in float3x3 rotation,
    in float3 objectWorldOrigin)
{
    vertex.position.xyz -= objectWorldOrigin;
    vertex.position.xyz = mul(rotation, vertex.position.xyz);
    vertex.position.xyz += objectWorldOrigin;
}

/**
 * Creates a rotation matrix for the grass using the previously sampled window vector.
 */
float3x3 GetWindRotation(
    in float3 windDirection, 
    in float3 right, 
    inout float windAngle)
{
    /**
     * Our grass is a 2D quad, so we can not bend on the forward axis as that would look wrong.
     * Instead we project the wind onto our right axis and adjust the wind strength accordingly.
     * If the wind is equal to our right vector, then it will use the full strength, however
     * if it is opposite then it will have zero strength.
     *
     * Wind direction was formerly an unit vector with length one. After projection the length 
     * of it will be anywhere on the range [0.0, 1.0].
     */

    windDirection = ProjectOnto(windDirection, right);

    float windStrength = _WindProperties.y * length(windDirection);    
    windAngle = UNITY_PI * windStrength;

    float3x3 windRotation = AngleAxis3x3(windAngle, normalize(windDirection));

    return windRotation;
}

/**
 * Applies the wind rotation to the top vertices, causing the grass to bend.
 */
void ApplyWindRotation(
    inout GeometryOutput vertex, 
    in float3 objectWorldOrigin, 
    in float3x3 windRotation, 
    float windAngle)
{
    RotateVertexAroundObjectOrigin(vertex, windRotation, objectWorldOrigin);
    vertex.tex2.w = windAngle;
}

/**
 * Applies "flattening" to the grass.
 *
 * The bottom vertices are unchanged, the middle are rotated according to the flatten modifier,
 * and the top are projected in a straight line from the bottom and middle vertices.
 */
void ApplyFlattenRotation(
    float flattenMod, 
    in GeometryOutput ll,
    in GeometryOutput lr,
    inout GeometryOutput ul, 
    inout GeometryOutput ur, 
    inout GeometryOutput uul, 
    inout GeometryOutput uur, 
    in float3 objectWorldOrigin, 
    in float3 forward,
    in float3 up)
{
    float3x3 flattenRotation = AngleAxis3x3(UNITY_PI * flattenMod * 0.5f, forward);
    float projDist = length(uul.position.xyz - ul.position.xyz);

    RotateVertexAroundObjectOrigin(ul, flattenRotation, objectWorldOrigin);
    RotateVertexAroundObjectOrigin(ur, flattenRotation, objectWorldOrigin);

    float3 projDir = normalize(ul.position.xyz - ll.position.xyz);

    uul.position.xyz = ul.position.xyz + (projDir * projDist) + (up * 0.01f);
    uur.position.xyz = ur.position.xyz + (projDir * projDist) + (up * 0.01f);
}

[maxvertexcount(12)]
void GeometryMain(
    triangle VertOutput triangleInput[3] : SV_POSITION,
    inout TriangleStream<GeometryOutput> triangleStream)
{
    float3 position = triangleInput[0].position;
    float3 normal   = triangleInput[0].normal;
    float4 tangent  = triangleInput[0].tangent;
    float4 tex1     = triangleInput[0].tex1;
    float4 tex2     = triangleInput[0].tex2;
    float4 tex3     = triangleInput[0].tex3;
    float3 binormal = cross(normal, tangent) * tangent.w;

    float flattenMod  = tex3.r;
    float growthMod   = tex3.a;
    float width       = lerp(0.0f, _Dimensions.x, growthMod);
    float height      = lerp(0.0f, tex1.r, growthMod);
    float halfWidth   = _Dimensions.x * 0.5f;
    float heightMod   = 0.2f;

    // Early exit if the grass is below a certain height. This saves resources and allows for empty patches.
    if (height < MIN_HEIGHT_CUTOFF)
    {
        return;
    }

    // Create transform from tangent to local space, and then the random rotation
    float3x3 tangentToLocal = float3x3(
        tangent.x, binormal.x, normal.x,
        tangent.y, binormal.y, normal.y,
        tangent.z, binormal.z, normal.z
    );

    tangentToLocal = mul(tangentToLocal, RandomAngleTransform(position));

    // Build the bottom quad of our grass in world space
    GeometryOutput lr = CalculateGeometry(position, tangentToLocal, float3(halfWidth, 0.0f, 0.0f), float2(1.0f, 0.0f), tex1, tex2, tex3);
    GeometryOutput ll = CalculateGeometry(position, tangentToLocal, float3(-halfWidth, 0.0f, 0.0f), float2(0.0f, 0.0f), tex1, tex2, tex3);
    GeometryOutput ul = CalculateGeometry(position, tangentToLocal, float3(-halfWidth, 0.0f, height * heightMod), float2(0.0f, heightMod), tex1, tex2, tex3);
    GeometryOutput ur = CalculateGeometry(position, tangentToLocal, float3(halfWidth, 0.0f, height * heightMod), float2(1.0f, heightMod), tex1, tex2, tex3);

    // Calculate the the axis directions for wind and perspective bending
    float3 up = normalize(ul.position.xyz - ll.position.xyz);
    float3 forward = normalize(lr.position.xyz - ll.position.xyz);
    float3 right = normalize(cross(forward, up));
    float3 left = normalize(cross(up, forward));
    float3 worldOrigin = (ll.position.xyz + (lr.position.xyz - ll.position.xyz) * 0.5f);        // Note, not the position. This is raised up.
    float3 cameraWorldView = normalize(UnityWorldSpaceViewDir(worldOrigin));

    // Build the top quad of our grass in world space. Only this one is affected by wind as we want to keep the bottom rooted in place.
    GeometryOutput uul = CalculateGeometry(position, tangentToLocal, float3(-halfWidth, 0.0f, height), float2(0.0f, 1.0f), tex1, tex2, tex3);
    GeometryOutput uur = CalculateGeometry(position, tangentToLocal, float3(halfWidth, 0.0f, height), float2(1.0f, 1.0f), tex1, tex2, tex3);
    
    if (flattenMod > 0.0f)
    {
        // If there is any flattening then perform it. Note we do not apply wind or perspective bend to grass being flattened.
        ApplyFlattenRotation(flattenMod, ll, lr, ul, ur, uul, uur, worldOrigin, forward, up);
    }
    else
    {
        // Apply wind to our world-space top points
        float windAngle = 0.0f;
        float3x3 windRotation = GetWindRotation(tex2.xyz, forward, windAngle);
    
        ApplyWindRotation(uul, worldOrigin, windRotation, windAngle);
        ApplyWindRotation(uur, worldOrigin, windRotation, windAngle);

        // If enabled, perform perspective bending so that the grass is adjusted according to camera view angle to better hide gaps.
        #ifdef GRASS_PERSPECTIVE_BEND
            PerformPerspectiveBend(ul, ur, uul, uur, cameraWorldView, right, left);
        #endif
    }

    // Calculate all normals
    CalculateGeometryNormals(cameraWorldView, right, left, up, ll, lr, ul, ur, uul, uur);

    // Move from world space to projection space
    lr.position  = mul(UNITY_MATRIX_VP, lr.position);
    ll.position  = mul(UNITY_MATRIX_VP, ll.position);
    ul.position  = mul(UNITY_MATRIX_VP, ul.position);
    ur.position  = mul(UNITY_MATRIX_VP, ur.position);
    uul.position = mul(UNITY_MATRIX_VP, uul.position);
    uur.position = mul(UNITY_MATRIX_VP, uur.position);

    // Bottom quad
    triangleStream.Append(lr);
    triangleStream.Append(ll);
    triangleStream.Append(ul);
    
    triangleStream.Append(lr);
    triangleStream.Append(ur);
    triangleStream.Append(ul);

    // Top quad
    triangleStream.Append(ur);
    triangleStream.Append(ul);
    triangleStream.Append(uul);
    
    triangleStream.Append(ur);
    triangleStream.Append(uur);
    triangleStream.Append(uul);
}

// -----------------------------------------------------------------------------
// Fragment Shader
// -----------------------------------------------------------------------------

void FragMain(
    GeometryOutput input,
    out half4 gbDiffuse  : SV_Target0,  // Diffuse Color RGB, Occlusion A
    out half4 gbSpecular : SV_Target1,  // Specular Color RGB, Roughness A
    out half4 gbNormal   : SV_Target2,  // World Normal RGB, Unused A
    out half4 gbLighting : SV_Target3)  // Emission + Lighting + Lightmaps + Reflection Probes
{
    float4 tint = lerp(_BaseColor, _TipColor, input.uv.y);
    float4 image = UNITY_SAMPLE_TEX2D(_AlbedoMap, input.uv);
    float4 color = tint * image;
    float cutMod = 1.0f - input.tex3.g;
    float cutAlpha = (cutMod < 1.0f && input.uv.y > cutMod) ? 0.0f : 1.0f;

    UnityStandardData data;

    #ifdef GRASS_WIND_HIGHLIGHT
    float windHighlight = (_WindProperties.z * clamp(input.tex2.w - 0.1f, 0.0f, 1.0f));
    #else
    float windHighlight = 1.0f;
    #endif

    //data.diffuseColor  = (input.tex2.xyz + 1.0f) * 0.5f;
    data.diffuseColor  = color.rgb + windHighlight;
    data.occlusion     = min(color.a, cutAlpha);
    data.specularColor = half3(0.0f, 0.0f, 0.0f);
    data.smoothness    = 0.0f;
    data.normalWorld   = input.normal;

    UnityStandardDataToGbuffer(data, gbDiffuse, gbSpecular, gbNormal);

    half3 emissive = half3(0.0f, 0.0f, 0.0f);
    
    #ifndef UNITY_HDR_ON
        emissive.rgb = exp2(-emissive.rgb);
    #endif

    gbLighting = half4(emissive, 1);
}

#endif