/*
 //  Updated by leonid@leeloo ©2019 Horns&Hoofs.®
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

typedef enum {
    LineOrientationNone = 0,
    LineOrientationHorizontal = 1,
    LineOrientationVertical = 2,
    LineOrientationDiscard  // discard fragment
} LineOrientation;

RasterizerData
vShaderArrow(uint vid,
             uint iid,
             constant float *vertices,
             constant float4 *colors,
             constant ChartContext *chartContextPtr)
{
    RasterizerData out;
    //TODO: implement it
    return out;
}

RasterizerData
vShaderDash(uint vid,
          uint iid,
          constant float *vertices,
          constant float4 *colors,
          constant ChartContext *chartContextPtr)
{
    RasterizerData out;
    //TODO: implement it
    return out;
}

/// Line Chart Vertex Function
vertex RasterizerData
vertexShader(uint vid [[ vertex_id ]],
             uint iid0 [[ instance_id ]],
             constant float *vertices [[ buffer(ZVxShaderBidVertices) ]],
             constant float4 *colors [[ buffer(ZVxShaderBidColor) ]],
             constant ChartContext *chartContextPtr  [[ buffer(ZVxShaderBidChartContext) ]] )
{
    if (chartContextPtr -> vshaderMode == VShaderModeDash) {
        const uint2 lineCount = uint2(chartContextPtr->extraInt[0], chartContextPtr->extraInt[1]);
        const float2 dashPattern = float2(chartContextPtr->extraFloat[0], chartContextPtr->extraFloat[1]);
        const float2 cellSize = float2(chartContextPtr->extraFloat[2], chartContextPtr->extraFloat[3]);
        const float lineWidth2 = chartContextPtr->lineWidth / 2.0; // half line width
        const float4 graphBox = chartContextPtr->graphRect; // graph size
        
        float2 position = -graphBox.xy;
        const uint lineNumber = iid0;
        const int horizontalNumber = lineNumber - lineCount[0];
        if (horizontalNumber < 0) { // vertical
            if (vid & 2) {  // 2,3 vert, bottom side
                position.y = graphBox.y;
            } else {        // 0,1 vert, top side
                position.y = graphBox.y + graphBox.w;
            }
            
            position.x += cellSize.x * lineNumber;
            if (vid & 1) {  // move left or rightward
                position.x += lineWidth2;
            } else {
                position.x -= lineWidth2;
            }
        } else { // horizontal
            if (vid & 2) {  // 2,3 vert, bottom side
                position.x = graphBox.x;
            } else {        // 0,1 vert, top side
                position.x = graphBox.z;
            }
            
            position.y += cellSize.y * horizontalNumber;
            if (vid & 1) {  // move left or rightward
                position.y += lineWidth2;
            } else {
                position.y -= lineWidth2;
            }
        }
        
        const float2 graphSize = graphBox.zw; // width, height in graph logic points
        position = position / graphSize * 2.0 - 1.0;
        
        RasterizerData out;
        out.color = chartContextPtr->color;
        out.clipSpacePosition = float4(position.x, position.y, 0.0, 1.0);
        out.dashMode = (horizontalNumber < 0) ? LineOrientationVertical : LineOrientationHorizontal;
        out.dashPattern = dashPattern;
        return out;
        
    }  // VShaderModeDash = end
    
    // VShaderModeFill {{{
    if (chartContextPtr -> vshaderMode == VShaderModeFill) {
        const float4 graphBox = chartContextPtr->graphRect; // graph size
        const uint planeCount = chartContextPtr->extraInt[0]; // one plane [[x0,y00,y01,y02] [x1,y10,y11,y12]]
        const uint index = vid / 2;
        const uint indexLast = (chartContextPtr->vertexCount) - 3;
        const uint stride = planeCount + 1;

        // map iid (turn a plane on/off)
        int iid = -1;   // the result mapped iid, -1 is a wrong result
        uint planeMask = (chartContextPtr->extraInt[1]) & 0xFF;
        if (planeMask == 0xFF) {
            iid = iid0;
        } else {
            if (planeMask && (iid0 < planeCount)) {
                uint bitIndex = 0;
                for (uint i=0; i< planeCount; ++i) {
                    if (planeMask & 1) {
                        if (bitIndex == iid0) {
                            iid = i;
                            break;
                        }
                        ++bitIndex;
                    }
                    planeMask >>= 1;
                }
            }
            if (iid < 0) {
                // error
                RasterizerData out;
                out.color = float4(1.0, 0.0, 0.0, 1.0);
                out.clipSpacePosition = float4(0);
                out.dashMode = LineOrientationDiscard;
                return out;
            }
        }

        float2 position;
        if (index < 2) {
            // the first 2 points pt[0], pt[1] (pt.fake, pt.0, ...)
            position.x = vertices[0];
            position.y = vertices[iid + 1];
        } else if (index > indexLast) {
            // the last 2 points pt[n-2], pt[n-1] (..., pt.n + pt.fake)
            const uint addr = indexLast * stride;
            position.x = vertices[addr];
            position.y = vertices[addr + iid + 1];
        } else {
            // other points in range
            const uint addr = (index - 1) * stride;
            position.x = vertices[addr];
            position.y = vertices[addr + iid + 1];
        }

        position -= graphBox.xy;  // move to x0, y0
        const float2 graphSize = graphBox.zw; // width, height in graph logic points
        position = position / graphSize * 2.0 - 1.0;
        if (vid & 1) {
            // move every next vertex to the bottom
            position.y = -1.0;
        }
        
        RasterizerData out;
        out.color = colors[iid];
        out.clipSpacePosition = vector_float4(position.x, position.y, 0.0, 1.0);
        out.dashMode = 0;
        return out;
    } // }}} VShaderModeFill
    
    // VShaderModeArrow {{{
    if (chartContextPtr -> vshaderMode == VShaderModeArrow) {
        return vShaderArrow(vid,
                        iid0,
                         vertices,
                         colors,
                         chartContextPtr);
    }
    // }}} VShaderModeArrow

    // VShaderModeStroke {{{
    if (chartContextPtr -> vshaderMode == VShaderModeStroke) {
        // stroke mode
        const float4 graphBox = chartContextPtr->graphRect; // graph size
        const float2 screenSize = float2(chartContextPtr->screenSize);
        const uint planeCount = chartContextPtr->extraInt[0]; // one plane [[x0,y00,y01,y02] [x1,y10,y11,y12]]
        const uint index = vid / 2;
        const uint indexLast = (chartContextPtr->vertexCount) - 3;
        const uint stride = planeCount + 1;
        const float sign = (vid & 1) ? 1 : -1; // aka direction

        RasterizerData out;

        // map iid (turn a plane on/off)
        int iid = -1;   // the result mapped iid, -1 is a wrong result
        uint planeMask = (chartContextPtr->extraInt[1]) & 0xFF;
        if (planeMask == 0xFF) {
            iid = iid0;
        } else {
            if (planeMask && (iid0 < planeCount)) {
                uint bitIndex = 0;
                for (uint i=0; i< planeCount; ++i) {
                    if (planeMask & 1) {
                        if (bitIndex == iid0) {
                            iid = i;
                            break;
                        }
                        ++bitIndex;
                    }
                    planeMask >>= 1;
                }
            }
            if (iid < 0) {
                // error
                out.clipSpacePosition = float4(0);
                out.dashMode = LineOrientationDiscard;
                return out;
            }
        }

        out.dashMode = 0;
        out.color = colors[iid];
                
        float2 prevPt, currPt, nextPt;
        const float dx = (vertices[indexLast * stride] - vertices[0])/indexLast;
        if (index < 2) {
            // the first 2 points pt[0], pt[1] (pt.fake, pt.0, ...)
            currPt.x = vertices[0];
            currPt.y = vertices[iid + 1];
            
            prevPt.x = currPt.x - dx;
            prevPt.y = currPt.y;
            
            nextPt.x = vertices[stride];
            nextPt.y = vertices[stride + iid + 1];
        } else if (index > indexLast) {
            // the last 2 points pt[n-2], pt[n-1] (..., pt.n + pt.fake)
            const uint addr = indexLast * stride;
            currPt.x = vertices[addr];
            currPt.y = vertices[addr + iid + 1];
            
            nextPt.x = currPt.x + dx;
            nextPt.y = currPt.y;
            
            const uint addr_prev = addr - stride;
            prevPt.x = vertices[addr_prev];
            prevPt.y = vertices[addr_prev + iid + 1];
        } else {
            // other points in range
            const uint addr = (index - 1) * stride;
            currPt.x = vertices[addr];
            currPt.y = vertices[addr + iid + 1];

            prevPt.x = vertices[addr - stride];
            prevPt.y = vertices[addr - stride + iid + 1];

            nextPt.x = vertices[addr + stride];
            nextPt.y = vertices[addr + stride + iid + 1];
        }
        
        if (true) {
            const int2 arrowIndices = int2(chartContextPtr->extraInt[2], chartContextPtr->extraInt[3]);
            if (arrowIndices[0] >= 0 && arrowIndices[1] >= 0) {
                if (int(index) == arrowIndices[0]+1 ){
                    //                || int(index) == arrowIndices[0] + arrowIndices[1]) {
                    //            out.color = float4(0,0,0,1);
                    out.dashMode = LineOrientationDiscard;
                    
                    const float arwPositionX = chartContextPtr->extraFloat[0];
                    const float x0 = graphBox.x + graphBox.z * arwPositionX;
                    
                    const float2 pt1 = prevPt;
                    const float2 pt2 = currPt;
                    const float normX = (x0 - pt1.x)/(pt2.x - pt1.x);
                    const float y0 = pt1.y + normX * (pt2.y - pt1.y);
                    
                    //                const float normX =
                    
                }
            }
        }
        
        const float2 graphSize = graphBox.zw; // width, height in graph logic points
        const float2 nScale = screenSize.yx / graphSize.yx;
        const float2 currentNormal = normalize(nScale * float2(prevPt.y - currPt.y, currPt.x - prevPt.x));
        const float2 nextNormal = normalize(nScale * float2(currPt.y - nextPt.y, nextPt.x - currPt.x));
        
        const float2 miter = normalize(currentNormal + nextNormal);
        float2 resultOffset = miter * sign * chartContextPtr->lineWidth / dot(miter, currentNormal);
        
        float2 position = currPt.xy - graphBox.xy;  // move to x0, y0
        position = position / graphSize * 2.0 - 1.0;
        
        position *= screenSize;
        position += resultOffset;
        position /= screenSize;
        out.clipSpacePosition = float4(position.x, position.y, 0.0, 1.0);

        return out;
    } // }}} VShaderModeStroke
    
    // something must go wrong if we get this far
    RasterizerData out;
    out.color = float4(1.0, 0.0, 0.0, 1.0);
    out.clipSpacePosition = float4((vid & 2 ? 1:-1), (vid & 1 ? 1:-1), 0.0, 1.0);
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
