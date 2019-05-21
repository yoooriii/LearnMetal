/*
 //  Updated by leonid@leeloo ©2019 Horns&Hoofs.®
*/

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

#import "ShaderTypes.h"

typedef enum {
    LineOrientationNone = 0,
    LineOrientationHorizontal,
    LineOrientationVertical,
    LineOrientationDiscard  // discard fragment
} LineOrientation;

typedef struct {
    float4 clipSpacePosition [[position]];
    float4 color;
    int mode;  // LineOrientation or 0
    float2 dashPattern;
} RasterizerData;

//RasterizerData
//vShaderArrow(uint vid,
//             uint iid0,
//             constant float *vertices,
//             constant float4 *colors,
//             constant ChartContext *context)
//{
//    RasterizerData out;
//    const float4 visibleRect = context->visibleRect; // logic absolute coordinates
//    const uint index = vid / 2;
//
//    // map iid (turn a plane on/off)
//    const int iid = convertIID(iid0, context);
//    if (iid < 0) {
//        // error
//        out.clipSpacePosition = float4(0);
//        out.mode = LineOrientationDiscard;
//        return out;
//    }
//
//    const int2 aid2 = int2(context->extraInt[2], context->extraInt[3]); // vx (index, leng)
//    if (aid2[0] < 0 || aid2[0] >= int(context->vertexCount)) {
//        out.mode = LineOrientationDiscard;
//        return out;
//    }
//
//    const uint stride = context->extraInt[0] + 1; // stride = plane.count + 1
//    const uint ivx1 = (aid2[0]) * stride;
//    const uint ivx2 = (aid2[0] + 1) * stride;
//    const float2 pt1 = float2(vertices[ivx1], vertices[ivx1 + iid + 1]);
//    const float2 pt2 = (aid2[1] <= 0) ? pt1 : float2(vertices[ivx2], vertices[ivx2 + iid + 1]);
//
//    const float4 boundBox = context->boundingBox;
//    const float x0 = boundBox.x + boundBox.z * context->extraFloat[0];
//    const float dx12 = pt2.x - pt1.x;
//    const float kx = (dx12 < 0.01) ? 0 : (x0 - pt1.x)/dx12; // kx = [0...1] --> between [x1...x2]
//    const float y0 = pt1.y + kx * (pt2.y - pt1.y);
//    const float2 center = float2(x0, y0);
//
//    float2 resultOffset;
//    const float initialRadius = context->extraFloat[1];
//    if (vid < ArrowCircleVertexCount) {
//        // circle vertices, 1st pass
//        out.color = colors[iid];
//        const float radius = (vid & 1) ? initialRadius : initialRadius * 0.5;
//        const float a = M_PI_F * 2.0 * float(index) / float(ArrowCircleStepCount);
//        resultOffset = float2(sin(a), cos(a)) * radius;
//    } else {
//        // circle vertices, 2nd pass
//        const uint vid2 = vid - ArrowCircleVertexCount;
//        const uint index2 = vid2/2;
//
//        out.color = context->color;
//        const float radius = (vid & 1) ? initialRadius * 0.5 : 0;
//        const float a = M_PI_F * 2.0 * float(index2) / float(ArrowCircleStepCount);
//        resultOffset = float2(sin(a), cos(a)) * radius;
//    }
//
//    const float2 graphSize = visibleRect.zw; // width, height in graph logic points
//    const float2 screenSize = float2(context->screenSize); // int --> float
//
//    float2 position = center.xy - visibleRect.xy;  // move to x0, y0
//    position = position / graphSize * 2.0 - 1.0;
//
//    position *= screenSize;
//    position += resultOffset;
//    position /= screenSize;
//
//    out.clipSpacePosition = float4(position.x, position.y, 0.0, 1.0);
//    out.mode = 0;
//    return out;
//}

#define GET_POINT_AT(addr) float2(vertices[addr], vertices[addr + iiy])

RasterizerData
vShaderStroke(const uint vid,
             constant float *vertices,
             constant InstanceDescriptor *instanceDescriptor,
             constant ChartContext *context)
{
    RasterizerData out;
    out.mode = LineOrientationNone;
    out.color = instanceDescriptor->color;

    const uint vertexCount = context->vertexCount;
    const float4 graphBox = context->visibleRect; // graph size
    const float2 screenSize = float2(context->screenSize);
    const float2 graphSize = graphBox.zw; // width, height in graph logic points
    
    // map iid (turn a plane on/off)
    const uint iiy = instanceDescriptor->offsetIY;
    const uint stride = instanceDescriptor->stride;
    const uint index = (vid + 1)/2;
    const uint addr = index * stride;

    if (vid == 0 || vid == (vertexCount-1)) { // the 1st and the lest points closing the path
        const float2 currPt = GET_POINT_AT(addr);
        const float2 position = (currPt - graphBox.xy) / graphSize * 2.0 - 1.0; // move to x0, y0 and scale to clip space 2x2
        const float clampX = 1.05;
        out.clipSpacePosition = float4(clamp(position.x, -clampX, clampX), position.y, 0.0, 1.0);
        return out;
    }

    const float2 prevPt = GET_POINT_AT(addr - stride);
    const float2 currPt = GET_POINT_AT(addr);
    const float2 nextPt = GET_POINT_AT(addr + stride);
    
    const float2 nScale = screenSize.yx / graphSize.yx;
    const float2 currentNormal = normalize(nScale * float2(prevPt.y - currPt.y, currPt.x - prevPt.x));
    const float2 nextNormal = normalize(nScale * float2(currPt.y - nextPt.y, nextPt.x - currPt.x));
    
    const float sign = (vid & 1) ? 1 : -1;  // aka direction
    const float2 miter = normalize(currentNormal + nextNormal);
    const float2 resultOffset = miter * sign * context->lineWidth / dot(miter, currentNormal);
    
    float2 position = (currPt - graphBox.xy) / graphSize * 2.0 - 1.0; // move to x0, y0 and scale to clip space 2x2
    position *= screenSize;
    position += resultOffset;
    position /= screenSize;
    out.clipSpacePosition = float4(position.x, position.y, 0.0, 1.0);

    return out;
}

RasterizerData
vShaderFill(uint vid,
            constant float *vertices,
            constant InstanceDescriptor *instanceDescriptor,
            constant ChartContext *context)
{
    RasterizerData out;
    out.mode = LineOrientationNone;
    out.color = instanceDescriptor->color;
    
    const float4 graphBox = context->visibleRect; // graph size
    const float2 graphSize = graphBox.zw; // width, height in graph logic points
    const uint iiy = instanceDescriptor->offsetIY;
    const uint stride = instanceDescriptor->stride;
    const uint index = (vid + 1)/2;
    const uint addr = index * stride;
    const uint vertexCount = context->vertexCount;

    const float2 currPt = GET_POINT_AT(addr);
    float2 position = (currPt - graphBox.xy) / graphSize * 2.0 - 1.0; // move to x0, y0 and scale to clip space 2x2

    if (!(vid & 1)) {
        position.y = -1;
        if (vid >= vertexCount-2) {
            position.x += 0.05;
        }
    }

    out.clipSpacePosition = float4(position.x, position.y, 0.0, 1.0);
    return out;
}

//RasterizerData
//vShaderDash(uint vid,
//          uint iid0,
//          constant float *vertices,
//          constant float4 *colors,
//          constant ChartContext *chartContextPtr)
//{
//    const uint2 lineCount = uint2(chartContextPtr->extraInt[0], chartContextPtr->extraInt[1]);
//    const float2 dashPattern = float2(chartContextPtr->extraFloat[0], chartContextPtr->extraFloat[1]);
//    const float2 cellSize = float2(chartContextPtr->extraFloat[2], chartContextPtr->extraFloat[3]);
//    const float lineWidth2 = chartContextPtr->lineWidth / 2.0; // half line width
//    const float4 graphBox = chartContextPtr->visibleRect; // graph size
//
//    float2 position = -graphBox.xy;
//    const uint lineNumber = iid0;
//    const int horizontalNumber = lineNumber - lineCount[0];
//    if (horizontalNumber < 0) { // vertical
//        if (vid & 2) {  // 2,3 vert, bottom side
//            position.y = graphBox.y;
//        } else {        // 0,1 vert, top side
//            position.y = graphBox.y + graphBox.w;
//        }
//
//        position.x += cellSize.x * lineNumber;
//        if (vid & 1) {  // move left or rightward
//            position.x += lineWidth2;
//        } else {
//            position.x -= lineWidth2;
//        }
//    } else { // horizontal
//        if (vid & 2) {  // 2,3 vert, bottom side
//            position.x = graphBox.x;
//        } else {        // 0,1 vert, top side
//            position.x = graphBox.z;
//        }
//
//        position.y += cellSize.y * horizontalNumber;
//        if (vid & 1) {  // move left or rightward
//            position.y += lineWidth2;
//        } else {
//            position.y -= lineWidth2;
//        }
//    }
//
//    const float2 graphSize = graphBox.zw; // width, height in graph logic points
//    position = position / graphSize * 2.0 - 1.0;
//
//    RasterizerData out;
//    out.color = chartContextPtr->color;
//    out.clipSpacePosition = float4(position.x, position.y, 0.0, 1.0);
//    out.mode = (horizontalNumber < 0) ? LineOrientationVertical : LineOrientationHorizontal;
//    out.dashPattern = dashPattern;
//    return out;
//}

/// Line Chart Vertex Function
vertex RasterizerData
vertexShader(uint vid [[ vertex_id ]],
             uint iid [[ instance_id ]],
             constant float *vertices [[ buffer(ZVxShaderBidVertices) ]],
             constant InstanceDescriptor *descriptors [[ buffer(ZVxShaderBidInstanceDescriptor) ]],
             constant ChartContext *context  [[ buffer(ZVxShaderBidChartContext) ]] )
{
    constant InstanceDescriptor *descriptor = &descriptors[iid];
    switch (context -> vshaderMode) {
//        case VShaderModeDash:
//            return vShaderDash(vid, iid, vertices, instanceDescriptors, chartContextPtr);
        case VShaderModeFill:
            return vShaderFill(vid, vertices, descriptor, context);
//        case VShaderModeArrow:
//            return vShaderArrow(vid, iid, vertices, instanceDescriptors, chartContextPtr);
        case VShaderModeStroke:
            return vShaderStroke(vid, vertices, descriptor, context);
            
        default: break;
    }
    
    // something must go wrong if we get this far
    RasterizerData out;
    out.color = float4(1.0, 0.0, 0.0, 1.0);
    out.clipSpacePosition = float4((vid & 2 ? 1:-1), (vid & 1 ? 1:-1), 0.0, 1.0);
    out.mode = LineOrientationNone;
    return out;
}

// Fragment function
fragment float4 fragmentShader(RasterizerData in [[stage_in]]) {
    // We return the color we just set which will be written to our color attachment.
    if (in.mode) {
        if (in.mode == LineOrientationHorizontal) {
            if (int(in.clipSpacePosition.x) % int(in.dashPattern[0] + in.dashPattern[1]) > in.dashPattern[0]) {
                discard_fragment();
            }
        }
        else if (in.mode == LineOrientationVertical) {
            if (int(in.clipSpacePosition.y) % int(in.dashPattern[0] + in.dashPattern[1]) > in.dashPattern[0]) {
                discard_fragment();
            }
        } else {
            discard_fragment();
        }
    }
    
    return in.color;
}
