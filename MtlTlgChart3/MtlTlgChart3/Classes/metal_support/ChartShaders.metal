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

vertex RasterizerData
vertexShaderFilled(uint vid [[ vertex_id ]],
                   device float2 *vertices [[ buffer(AAPLVertexInputIndexVertices) ]],
                   constant ChartContext *chartContextPtr  [[ buffer(AAPLVertexInputIndexChartContext) ]] );


/// Line Chart Vertex Function
vertex RasterizerData
vertexShader(uint vid [[ vertex_id ]],
             device float2 *vertices [[ buffer(AAPLVertexInputIndexVertices) ]],
             constant ChartContext *chartContextPtr  [[ buffer(AAPLVertexInputIndexChartContext) ]] )
{
    if (chartContextPtr -> vshaderMode == VShaderModeFill) {
        const float4 graphBox = chartContextPtr->graphRect; // graph size
        const float2 graphSize = float2(graphBox[2] - graphBox[0], graphBox[3] - graphBox[1]); // width, height in graph logic points
        
        float2 position = vertices[vid];
        position -= graphBox.xy;  // move to x0, y0
        position = position / graphSize * 2.0 - 1.0;
        if (vid & 1) {
            // move every next vertex to the bottom
            position.y = -1.0;
        }
        
        RasterizerData out;
        out.color = chartContextPtr->color;
        out.color.a = 1.0;
        out.clipSpacePosition = vector_float4(position.x, position.y, 0.0, 1.0);
        return out;
    }
    
    const float4 viewport = chartContextPtr->graphRect; // graph size
    const float2 positionScaler = float2(viewport[2] - viewport[0], viewport[3] - viewport[1]); // width, height in graph logic points
    const float2 screenScaler = vector_float2(chartContextPtr->screenSize);

    bool isLast = vid >= chartContextPtr->vertexCount - 2;
    float2 currPt = vertices[vid];
    float2 prevPt = (vid < 2) ? currPt : vertices[vid-2];
    float2 nextPt = isLast ?    currPt : vertices[vid+2];

    const float2 nScale = screenScaler.yx / positionScaler.yx;
    const float2 currentNormal = normalize(nScale * float2(prevPt.y - currPt.y, currPt.x - prevPt.x));
    const float2 nextNormal = normalize(nScale * float2(currPt.y - nextPt.y, nextPt.x - currPt.x));
    
    const float2 miter = normalize(currentNormal + nextNormal);
    const float direction = (vid & 1) ? 1 : -1;
    float2 resultOffset = miter * direction * chartContextPtr->lineWidth / dot(miter, currentNormal);
    
    float2 position = currPt.xy - viewport.xy;  // move to x0, y0
    position = position / positionScaler * 2.0 - 1.0;
    
    position *= screenScaler;
    position += resultOffset;
    position /= screenScaler;
    
    RasterizerData out;
    out.color = chartContextPtr->color;
    out.clipSpacePosition = vector_float4(position.x, position.y, 0.0, 1.0);
    return out;
}


/// Filled Chart Vertex Function
vertex RasterizerData
vertexShaderFilled(uint vid [[ vertex_id ]],
             device float2 *vertices [[ buffer(AAPLVertexInputIndexVertices) ]],
             constant ChartContext *chartContextPtr  [[ buffer(AAPLVertexInputIndexChartContext) ]] )
{
    // graphRect = float4(minX, minY, maxX, maxY); graph size
    const float4 graphBox = chartContextPtr->graphRect;
    const float2 graphSize = float2(graphBox[2] - graphBox[0], graphBox[3] - graphBox[1]);
    
    float2 currPt = vertices[vid];
    if (vid & 1) {
        currPt.y = graphBox[1]; // minY
    }
    float2 position = currPt.xy - graphBox.xy;  // move to x0, y0
    position = position / graphSize * 2.0 - 1.0;
    
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

