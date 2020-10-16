#ifndef REALMS_COMMON_STRUCT_INCLUDED
#define REALMS_COMMON_STRUCT_INCLUDED

/**
 * Input to the Vertex shader.
 */
struct VertInput
{
    float4 position : POSITION;
    float3 normal   : NORMAL;
    float4 tangent  : TANGENT;
    float2 uv       : TEXCOORD0;
    float4 tex1     : TEXCOORD1;
    float4 tex2     : TEXCOORD2;
    float4 tex3     : TEXCOORD3;
};

/**
 * Output of the Vertex (and by proxy, Domain) shader.
 */
struct VertOutput
{
    float4 position : SV_Position;
    float3 normal   : NORMAL;
    float4 tangent  : TANGENT;
    float2 uv       : TEXCOORD0;
    float4 tex1     : TEXCOORD1;
    float4 tex2     : TEXCOORD2;
    float4 tex3     : TEXCOORD3;
};

/**
 * Represents a tessellation control point, one of the original verticies of the tessellated primitive.
 */
struct TessellationControlPoint
{
    float4 position : INTERNALTESSPOS;
    float3 normal   : NORMAL;
    float4 tangent  : TANGENT;
    float2 uv       : TEXCOORD0;
    float4 tex1     : TEXCOORD1;
    float4 tex2     : TEXCOORD2;
    float4 tex3     : TEXCOORD3;
};

/**
 * The factors controlling how the tessellation is performed.
 */
struct TessellationFactors
{
    float edge[3] : SV_TessFactor;
    float inside  : SV_InsideTessFactor;
};

#endif