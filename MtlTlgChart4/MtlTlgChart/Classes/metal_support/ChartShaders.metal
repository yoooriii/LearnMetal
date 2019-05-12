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
    LineOrientationHorizontal,
    LineOrientationVertical,
    LineOrientationDiscard  // discard fragment
} LineOrientation;

typedef struct {
    float2 prevPt;
    float2 currPt;
    float2 nextPt;
} Vertex3;

inline int convertIID(uint iid0, constant ChartContext *context) {
    const uint planeCount = context->extraInt[0]; // one plane [[x0,y00,y01,y02] [x1,y10,y11,y12]]
    uint planeMask = (context->extraInt[1]) & 0xFF;
    int iid = -1;
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
    }
    return iid;
}

inline Vertex3 getVertex3(constant float *vertices, const int iid,
                   const uint index, constant ChartContext *context)
{
    Vertex3 v3;
    const uint planeCount = context->extraInt[0]; // one plane [[x0,y00,y01,y02] [x1,y10,y11,y12]]
    const uint stride = planeCount + 1;
    const uint indexLast = (context->vertexCount) - 3;
    const float dx = (vertices[indexLast * stride] - vertices[0])/indexLast;
    if (index < 2) {
        // the first 2 points pt[0], pt[1] (pt.fake, pt.0, ...)
        v3.currPt.x = vertices[0];
        v3.currPt.y = vertices[iid + 1];
        
        v3.prevPt.x = v3.currPt.x - dx;
        v3.prevPt.y = v3.currPt.y;
        
        v3.nextPt.x = vertices[stride];
        v3.nextPt.y = vertices[stride + iid + 1];
    } else if (index > indexLast) {
        // the last 2 points pt[n-2], pt[n-1] (..., pt.n + pt.fake)
        const uint addr = indexLast * stride;
        v3.currPt.x = vertices[addr];
        v3.currPt.y = vertices[addr + iid + 1];
        
        v3.nextPt.x = v3.currPt.x + dx;
        v3.nextPt.y = v3.currPt.y;
        
        const uint addr_prev = addr - stride;
        v3.prevPt.x = vertices[addr_prev];
        v3.prevPt.y = vertices[addr_prev + iid + 1];
    } else {
        // other points in range
        const uint addr = (index - 1) * stride;
        v3.currPt.x = vertices[addr];
        v3.currPt.y = vertices[addr + iid + 1];
        
        v3.prevPt.x = vertices[addr - stride];
        v3.prevPt.y = vertices[addr - stride + iid + 1];
        
        v3.nextPt.x = vertices[addr + stride];
        v3.nextPt.y = vertices[addr + stride + iid + 1];
    }
    return v3;
}

RasterizerData
vShaderArrow(uint vid,
             uint iid0,
             constant float *vertices,
             constant float4 *colors,
             constant ChartContext *context)
{
    RasterizerData out;
    const float4 visibleRect = context->visibleRect; // logic absolute coordinates
    const uint index = vid / 2;

    // map iid (turn a plane on/off)
    const int iid = convertIID(iid0, context);
    if (iid < 0) {
        // error
        out.clipSpacePosition = float4(0);
        out.dashMode = LineOrientationDiscard;
        return out;
    }
    
    const int2 aid2 = int2(context->extraInt[2], context->extraInt[3]); // vx (index, leng)
    if (aid2[0] < 0 || aid2[0] >= int(context->vertexCount)) {
        out.dashMode = LineOrientationDiscard;
        return out;
    }
    
    const uint stride = context->extraInt[0] + 1; // stride = plane.count + 1
    const uint ivx1 = (aid2[0]) * stride;
    const uint ivx2 = (aid2[0] + 1) * stride;
    const float2 pt1 = float2(vertices[ivx1], vertices[ivx1 + iid + 1]);
    const float2 pt2 = (aid2[1] <= 0) ? pt1 : float2(vertices[ivx2], vertices[ivx2 + iid + 1]);
    
    const float4 boundBox = context->boundingBox;
    const float x0 = boundBox.x + boundBox.z * context->extraFloat[0];
    const float dx12 = pt2.x - pt1.x;
    const float kx = (dx12 < 0.01) ? 0 : (x0 - pt1.x)/dx12; // kx = [0...1] --> between [x1...x2]
    const float y0 = pt1.y + kx * (pt2.y - pt1.y);
    const float2 center = float2(x0, y0);
    
    float2 resultOffset;
    const float initialRadius = context->extraFloat[1];
    if (vid < ArrowCircleVertexCount) {
        // circle vertices, 1st pass
        out.color = colors[iid];
        const float radius = (vid & 1) ? initialRadius : initialRadius * 0.5;
        const float a = M_PI_F * 2.0 * float(index) / float(ArrowCircleStepCount);
        resultOffset = float2(sin(a), cos(a)) * radius;
    } else {
        // circle vertices, 2nd pass
        const uint vid2 = vid - ArrowCircleVertexCount;
        const uint index2 = vid2/2;

        out.color = context->color;
        const float radius = (vid & 1) ? initialRadius * 0.5 : 0;
        const float a = M_PI_F * 2.0 * float(index2) / float(ArrowCircleStepCount);
        resultOffset = float2(sin(a), cos(a)) * radius;
    }
    
    const float2 graphSize = visibleRect.zw; // width, height in graph logic points
    const float2 screenSize = float2(context->screenSize); // int --> float
    
    float2 position = center.xy - visibleRect.xy;  // move to x0, y0
    position = position / graphSize * 2.0 - 1.0;
    
    position *= screenSize;
    position += resultOffset;
    position /= screenSize;

    out.clipSpacePosition = float4(position.x, position.y, 0.0, 1.0);
    out.dashMode = 0;
    return out;
}

RasterizerData
vShaderStroke(uint vid,
             uint iid0,
             constant float *vertices,
             constant float4 *colors,
             constant ChartContext *chartContextPtr)
{
    RasterizerData out;
    const float4 graphBox = chartContextPtr->visibleRect; // graph size
    const float2 screenSize = float2(chartContextPtr->screenSize);
    const uint index = vid / 2;
    const float sign = (vid & 1) ? 1 : -1; // aka direction
    
    // map iid (turn a plane on/off)
    const int iid = convertIID(iid0, chartContextPtr);
    if (iid < 0) {
        // error
        out.clipSpacePosition = float4(0);
        out.dashMode = LineOrientationDiscard;
        return out;
    }
    
    out.dashMode = 0;
    out.color = colors[iid];
    
    const Vertex3 v3 = getVertex3(vertices, iid, index, chartContextPtr);
    
    if (false) { // discard a selected segment
        const int2 arrowIndices = int2(chartContextPtr->extraInt[2], chartContextPtr->extraInt[3]);
        if (arrowIndices[0] >= 0 && arrowIndices[1] >= 0) {
            if (int(index) == arrowIndices[0] + 1) {
                out.dashMode = LineOrientationDiscard;
            }
        }
    }
    
    const float2 graphSize = graphBox.zw; // width, height in graph logic points
    const float2 nScale = screenSize.yx / graphSize.yx;
    const float2 currentNormal = normalize(nScale * float2(v3.prevPt.y - v3.currPt.y, v3.currPt.x - v3.prevPt.x));
    const float2 nextNormal = normalize(nScale * float2(v3.currPt.y - v3.nextPt.y, v3.nextPt.x - v3.currPt.x));
    
    const float2 miter = normalize(currentNormal + nextNormal);
    float2 resultOffset = miter * sign * chartContextPtr->lineWidth / dot(miter, currentNormal);
    
    float2 position = v3.currPt.xy - graphBox.xy;  // move to x0, y0
    position = position / graphSize * 2.0 - 1.0;
    
    position *= screenSize;
    position += resultOffset;
    position /= screenSize;
    out.clipSpacePosition = float4(position.x, position.y, 0.0, 1.0);
    
    return out;
}

RasterizerData
vShaderFill(uint vid,
             uint iid0,
             constant float *vertices,
             constant float4 *colors,
             constant ChartContext *chartContextPtr)
{
    const float4 graphBox = chartContextPtr->visibleRect; // graph size
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
}

RasterizerData
vShaderDash(uint vid,
          uint iid0,
          constant float *vertices,
          constant float4 *colors,
          constant ChartContext *chartContextPtr)
{
    const uint2 lineCount = uint2(chartContextPtr->extraInt[0], chartContextPtr->extraInt[1]);
    const float2 dashPattern = float2(chartContextPtr->extraFloat[0], chartContextPtr->extraFloat[1]);
    const float2 cellSize = float2(chartContextPtr->extraFloat[2], chartContextPtr->extraFloat[3]);
    const float lineWidth2 = chartContextPtr->lineWidth / 2.0; // half line width
    const float4 graphBox = chartContextPtr->visibleRect; // graph size
    
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
}

/// Line Chart Vertex Function
vertex RasterizerData
vertexShader(uint vid [[ vertex_id ]],
             uint iid0 [[ instance_id ]],
             constant float *vertices [[ buffer(ZVxShaderBidVertices) ]],
             constant float4 *colors [[ buffer(ZVxShaderBidColor) ]],
             constant ChartContext *chartContextPtr  [[ buffer(ZVxShaderBidChartContext) ]] )
{
    switch (chartContextPtr -> vshaderMode) {
        case VShaderModeDash:
            return vShaderDash(vid, iid0, vertices, colors, chartContextPtr);
        case VShaderModeFill:
            return vShaderFill(vid, iid0, vertices, colors, chartContextPtr);
        case VShaderModeArrow:
            return vShaderArrow(vid, iid0, vertices, colors, chartContextPtr);
        case VShaderModeStroke:
            return vShaderStroke(vid, iid0, vertices, colors, chartContextPtr);
        default: break;
    }
    
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
