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
vertexShader(uint vid [[ vertex_id ]],
             device ChartRenderVertex *vertices [[ buffer(AAPLVertexInputIndexVertices) ]],
             constant ChartContext *chartContextPtr  [[ buffer(AAPLVertexInputIndexChartContext) ]] )
{
    const float4 viewport = float4(chartContextPtr->viewportSize);
    const float2 positionScaler = float2(viewport.z - viewport.x, viewport.w - viewport.y);
    const float2 screenScaler = vector_float2(chartContextPtr->screenSize);
    const ChartRenderVertex vx = vertices[vid];

    const float2 nScale = screenScaler.yx / positionScaler.yx;
    const float2 currentNormal = normalize(vx.normal * nScale);
    const float2 nextNormal = normalize(vx.nextNormal * nScale);
    
    const float2 miter = normalize(currentNormal + nextNormal);
    const float direction = (vid & 1) ? -1 : 1; //vx.direction;
    const float2 resultOffset = miter * direction * chartContextPtr->lineWidth / dot(miter, currentNormal);
    
    float2 position = vx.position.xy - viewport.xy;
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

