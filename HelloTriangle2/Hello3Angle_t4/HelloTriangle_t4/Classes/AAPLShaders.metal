/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal shaders used for this sample
*/

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// convenience matrix create functions
float3x3 mx_translate(float tx, float ty) {
    return float3x3(float3(1, 0, 0),
                    float3(0, 1, 0),
                    float3(tx, ty, 1));
}

float3x3 mx_rotate(float angle) {
    float3 m0 = float3( cos(angle), sin(angle), 0);
    float3 m1 = float3(-sin(angle), cos(angle), 0);
    float3 m2 = float3( 0,          0,          1);
    return float3x3(m0, m1, m2);
}

float3x3 mx_scale(float sx, float sy) {
    return float3x3(float3(sx, 0, 0),
                    float3(0, sy, 0),
                    float3(0, 0, 1));
}

// Include header shared between this Metal shader code and C code executing Metal API commands
#import "AAPLShaderTypes.h"

// Vertex shader outputs and per-fragment inputs. Includes clip-space position and vertex outputs
//  interpolated by rasterizer and fed to each fragment generated by clip-space primitives.
typedef struct
{
    // The [[position]] attribute qualifier of this member indicates this value is the clip space
    //   position of the vertex wen this structure is returned from the vertex shader
    float4 clipSpacePosition [[position]];
    
    // Since this member does not have a special attribute qualifier, the rasterizer will
    //   interpolate its value with values of other vertices making up the triangle and
    //   pass that interpolated value to the fragment shader for each fragment in that triangle;
    float2 textureCoordinate;
    
} RasterizerData;

// Vertex Function
vertex RasterizerData
vertexShader(uint vertexID [[ vertex_id ]],
             constant AAPLVertex *vertexArray [[ buffer(AAPLVertexInputIndexVertices) ]],
             constant AAPLRenderContext *renderContext [[buffer(AAPLVertexInputIndexRenderContext)]])
{
    
    RasterizerData out;
    
    // Index into our array of positions to get the current vertex
    //   Our positions are specified in pixel dimensions (i.e. a value of 100 is 100 pixels from
    //   the origin)
    float2 pixelSpacePosition = vertexArray[vertexID].position.xy;
    
    // Get the size of the drawable so that we can convert to normalized device coordinates,
    float2 viewportSize = float2(renderContext->viewportSize);
    
    // The output position of every vertex shader is in clip space (also known as normalized device
    //   coordinate space, or NDC). A value of (-1.0, -1.0) in clip-space represents the
    //   lower-left corner of the viewport whereas (1.0, 1.0) represents the upper-right corner of
    //   the viewport.
    
    // In order to convert from positions in pixel space to positions in clip space we divide the
    //   pixel coordinates by half the size of the viewport.
    float2 position = pixelSpacePosition / (viewportSize / 2.0);
    float3 pos3d = float3(position, 0);
    float3x3 rotateMx = mx_rotate(renderContext->rotation);
    float3 rotatedPt = pos3d * rotateMx;
    out.clipSpacePosition = float4(rotatedPt, 1.0); // (x,y,0,1)
    
    // Pass our input textureCoordinate straight to our output RasterizerData. This value will be
    //   interpolated with the other textureCoordinate values in the vertices that make up the
    //   triangle.
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    
    return out;
}


// Fragment function
fragment float4
samplingShader(RasterizerData in [[stage_in]],
               texture2d<half> colorTexture [[ texture(AAPLTextureIndexBaseColor) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    
    // Sample the texture to obtain a color
    const half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);
    
    // We return the color of the texture
    return float4(colorSample);
}
