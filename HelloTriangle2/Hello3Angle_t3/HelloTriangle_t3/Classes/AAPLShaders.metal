/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal shaders used for this sample
*/

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands
#import "AAPLShaderTypes.h"

// Vertex shader outputs and fragment shader inputs
typedef struct
{
    // The [[position]] attribute of this member indicates that this value is the clip space
    // position of the vertex when this structure is returned from the vertex function
    float4 clipSpacePosition [[position]];

    // Since this member does not have a special attribute, the rasterizer interpolates
    // its value with the values of the other triangle vertices and then passes
    // the interpolated value to the fragment shader for each fragment in the triangle
    float4 color;

} RasterizerData;

// Vertex function
vertex RasterizerData
vertexShader(uint vertexID [[vertex_id]],
             constant AAPLVertex *vertices [[buffer(AAPLVertexInputIndexVertices)]],
             constant AAPLRenderContext *renderContext [[buffer(AAPLVertexInputIndexRenderContext)]])
{
    RasterizerData out;

    // Initialize our output clip space position
    out.clipSpacePosition = vector_float4(0.0, 0.0, 0.0, 1.0);

    // Index into our array of positions to get the current vertex
    //   Our positions are specified in pixel dimensions (i.e. a value of 100 is 100 pixels from
    //   the origin)
    float2 pixelSpacePosition = vertices[vertexID].position.xy;

    // Dereference viewportSizePointer and cast to float so we can do floating-point division
    vector_float2 viewportSize = vector_float2(renderContext->viewportSize);

    // The output position of every vertex shader is in clip-space (also known as normalized device
    //   coordinate space, or NDC).   A value of (-1.0, -1.0) in clip-space represents the
    //   lower-left corner of the viewport whereas (1.0, 1.0) represents the upper-right corner of
    //   the viewport.

    // Calculate and write x and y values to our clip-space position.  In order to convert from
    //   positions in pixel space to positions in clip-space, we divide the pixel coordinates by
    //   half the size of the viewport.
    float2 pos = pixelSpacePosition / (viewportSize / 2.0);
    
    
    
    out.clipSpacePosition.xy = pos;

    // Pass our input color straight to our output color.  This value will be interpolated
    //   with the other color values of the vertices that make up the triangle to produce
    //   the color value for each fragment in our fragment shader
    out.color = vertices[vertexID].color;
//    out.color = float4(1.0); //vertices[vertexID].color;
    out.color = float4(renderContext->strokeColor);

    return out;
}

// Fragment function
fragment float4 fragmentShader(RasterizerData in [[stage_in]]) {
    // We return the color we just set which will be written to our color attachment.
    return in.color;
}

// Another Fragment function: Alpha blend (smooth)?? no idea how it works
fragment half4 fragment_Points(RasterizerData fragData [[stage_in]],
                               float2 pointCoord [[point_coord]])
{
//    if (length(pointCoord - float2(0.5)) > 0.3) {
//        discard_fragment();
//    }
//    return half4(fragData.color);

    float dist = length(pointCoord - float2(0.5));
    if (dist < 0.70) {
        discard_fragment();
    }
    return half4(fragData.color);


//    float4 out_color = fragData.color;
//    out_color.a = 1.0 - smoothstep(0.4, 0.5, dist);
//    return half4(out_color);
}
