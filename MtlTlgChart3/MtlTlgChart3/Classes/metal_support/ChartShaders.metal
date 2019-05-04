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
    int dashMode;  // LineOrientation or 0
    float2 dashPattern;
} RasterizerData;

/// Line Chart Vertex Function
vertex RasterizerData
vertexShader(uint vid [[ vertex_id ]],
             uint iid [[ instance_id ]],
             constant float *vertices [[ buffer(AAPLVertexInputIndexVertices) ]],  // v[n]=x, v[n+1]=y
             constant ChartContext *chartContextPtr  [[ buffer(AAPLVertexInputIndexChartContext) ]] )
{
    if (chartContextPtr -> vshaderMode == VShaderModeFill) {
        const float4 graphBox = chartContextPtr->graphRect; // graph size
        const float2 graphSize = float2(graphBox[2] - graphBox[0], graphBox[3] - graphBox[1]); // width, height in graph logic points
        
        const uint vid0 = vid & 0xFFFE;
        float2 position;
        position.x = vertices[vid0];
        position.y = vertices[vid0 + 1];
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
        out.dashMode = 0;
        return out;
    }
    
    if (chartContextPtr -> vshaderMode == VShaderModeDash) {
        const uint2 lineCount = uint2(chartContextPtr->extraInt[0], chartContextPtr->extraInt[1]);
        
        const float2 dashPattern = float2(chartContextPtr->extraFloat[0], chartContextPtr->extraFloat[1]);
        const float2 cellSize = float2(chartContextPtr->extraFloat[2], chartContextPtr->extraFloat[3]);
        const float lineWidth2 = chartContextPtr->lineWidth / 2.0; // half line width
        const float4 graphBox = chartContextPtr->graphRect; // graph size
        const float2 graphSize = float2(graphBox[2] - graphBox[0], graphBox[3] - graphBox[1]); // width, height in graph logic points
        
        float2 position = -graphBox.xy;
        const uint lineNumber = iid;
        const int horizontalNumber = lineNumber - lineCount[0];
        if (horizontalNumber < 0) { // vertical
            if (vid & 2) {  // 2,3 vert, bottom side
                position.y = graphBox[1];
            } else {        // 0,1 vert, top side
                position.y = graphBox[3];
            }
            
            position.x += cellSize.x * lineNumber;
            if (vid & 1) {  // move left or rightward
                position.x += lineWidth2;
            } else {
                position.x -= lineWidth2;
            }
        } else { // horizontal
            if (vid & 2) {  // 2,3 vert, bottom side
                position.x = graphBox[0];
            } else {        // 0,1 vert, top side
                position.x = graphBox[2];
            }
            
            position.y += cellSize.y * horizontalNumber;
            if (vid & 1) {  // move left or rightward
                position.y += lineWidth2;
            } else {
                position.y -= lineWidth2;
            }
        }
        
        position = position / graphSize * 2.0 - 1.0;
        
        RasterizerData out;
        out.color = chartContextPtr->color;
        out.clipSpacePosition = float4(position.x, position.y, 0.0, 1.0);
        out.dashMode = (horizontalNumber < 0) ? LineOrientationVertical : LineOrientationHorizontal;
        out.dashPattern = dashPattern;
        return out;
        
    }  // VShaderModeDash = end
    
    
    // stroke mode
    const float4 viewport = chartContextPtr->graphRect; // graph size
    const float2 positionScaler = float2(viewport[2] - viewport[0], viewport[3] - viewport[1]); // width, height in graph logic points
    const float2 screenSize = vector_float2(chartContextPtr->screenSize);

    bool isLast = vid >= chartContextPtr->vertexCount - 2;
    float2 currPt;
    const uint vid0 = vid & 0xFFFE;
    currPt.x = vertices[vid0];
    currPt.y = vertices[vid0 + 1];
    
    float2 prevPt;
    if (vid >= 2) {
        const uint vid_before = (vid - 2) & 0xFFFE;
        prevPt.x = vertices[vid_before];
        prevPt.y = vertices[vid_before + 1];
    } else {
        prevPt = currPt;
    }
    
    float2 nextPt;
    if (isLast) {
        nextPt = currPt;
    } else {
        const uint vid_after = (vid + 2) & 0xFFFE;
        nextPt.x = vertices[vid_after];
        nextPt.y = vertices[vid_after + 1];
    }

    const float2 nScale = screenSize.yx / positionScaler.yx;
    const float2 currentNormal = normalize(nScale * float2(prevPt.y - currPt.y, currPt.x - prevPt.x));
    const float2 nextNormal = normalize(nScale * float2(currPt.y - nextPt.y, nextPt.x - currPt.x));
    
    const float2 miter = normalize(currentNormal + nextNormal);
    const float direction = (vid & 1) ? 1 : -1;
    float2 resultOffset = miter * direction * chartContextPtr->lineWidth / dot(miter, currentNormal);
    
    float2 position = currPt.xy - viewport.xy;  // move to x0, y0
    position = position / positionScaler * 2.0 - 1.0;
    
    position *= screenSize;
    position += resultOffset;
    position /= screenSize;
    
    RasterizerData out;
    out.color = chartContextPtr->color;
    out.clipSpacePosition = vector_float4(position.x, position.y, 0.0, 1.0);
    out.dashMode = 0;
    return out;
}

// Fragment function
fragment float4 fragmentShader(RasterizerData in [[stage_in]]) {
    // We return the color we just set which will be written to our color attachment.
    if (in.dashMode) {
        if (in.dashMode == LineOrientationHorizontal) {
            if (int(in.clipSpacePosition.x) % int(in.dashPattern[0] + in.dashPattern[1]) > in.dashPattern[0]) {
                discard_fragment();
            }
        }
        else if (in.dashMode == LineOrientationVertical) {
            if (int(in.clipSpacePosition.y) % int(in.dashPattern[0] + in.dashPattern[1]) > in.dashPattern[0]) {
                discard_fragment();
            }
        } else {
            discard_fragment();
        }
    }
    
    return in.color;
}
