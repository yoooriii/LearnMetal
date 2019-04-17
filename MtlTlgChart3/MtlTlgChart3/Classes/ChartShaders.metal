/*
See LICENSE folder for this sample’s licensing information.

This is adopted metal shaders file from apple
*/

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

#import "ShaderTypes.h"

typedef struct {
    float4 clipSpacePosition [[position]];
    float4 color;
} RasterizerData;

// Vertex Function
vertex RasterizerData
vertexShader(uint vertexID [[ vertex_id ]],
             device ChartRenderVertex *vertices [[ buffer(AAPLVertexInputIndexVertices) ]],
             constant ChartContext *chartContextPtr  [[ buffer(AAPLVertexInputIndexChartContext) ]] )
{
    const float lineWidth = chartContextPtr->lineWidth;
    const vector_float4 viewport = vector_float4(chartContextPtr->viewportSize);
    const float2 positionScaler = float2(viewport.z - viewport.x, viewport.w - viewport.y);
    const float2 screenScaler = vector_float2(chartContextPtr->screenSize);
    
    const float2 currentNormal = normalize(vertices[vertexID].normal / positionScaler.yx * screenScaler.yx);
    const float2 nextNormal = normalize(vertices[vertexID].nextNormal / positionScaler.yx * screenScaler.yx);
    
    const float2 miter = normalize(currentNormal + nextNormal);
    const float direction = vertices[vertexID].direction;
    const float2 resultOffset = miter * direction * (lineWidth / dot(miter, currentNormal));
    
    float2 position = vertices[vertexID].position.xy - viewport.xy; // pixelSpacePosition
    position = position / positionScaler * 2.0 - 1.0;
    
    position *= screenScaler;
    position += resultOffset;
    position /= screenScaler;
    
    RasterizerData out;
    out.color = chartContextPtr->color;
    out.clipSpacePosition = vector_float4(position.x, position.y, 0.0, 1.0);
    return out;
}

// Fragment function
fragment float4 fragmentShader(RasterizerData in [[stage_in]]) {
    // We return the color we just set which will be written to our color attachment.
    return in.color;
}

