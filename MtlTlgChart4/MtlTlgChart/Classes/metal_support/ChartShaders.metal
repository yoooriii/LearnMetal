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

#define GET_POINT_AT(addr) float2(vertices[addr], vertices[addr + iiy])

RasterizerData
vShaderArrow(const uint vid,
             constant float *vertices,
             constant InstanceDescriptor *instanceDescriptor,
             constant ChartContext *context)
{
    RasterizerData out;
    
    const int2 aid2 = context->ptRange; // vx (index, leng)
    if (aid2[0] < 0 || aid2[0] >= int(context->vertexCount)) {
        out.mode = LineOrientationDiscard;
        return out;
    }
    
    const uint stride = context->stride;
    const uint offsetIY = instanceDescriptor->offsetIY;
    const uint ivx1 = (aid2[0]+1) * stride;
    const uint ivx2 = (aid2[0]+2) * stride;
    const float2 pt1 = float2(vertices[ivx1], vertices[ivx1 + offsetIY]);
    const float2 pt2 = (aid2[1] <= 0) ? pt1 : float2(vertices[ivx2], vertices[ivx2 + offsetIY]);
    
    const float4 boundBox = context->boundingBox;
    const float x0 = boundBox.x + boundBox.z * context->ptOffsetNX;
    const float dx12 = pt2.x - pt1.x;
    const float kx = (dx12 < 0.01) ? 0 : (x0 - pt1.x)/dx12; // kx = [0...1] --> between [x1...x2]
    const float y0 = pt1.y + kx * (pt2.y - pt1.y);
    const float2 center = float2(x0, y0);
    
    float2 resultOffset;
    if (vid < ArrowCircleVertexCount) {
        // circle vertices, 1st pass
        out.color = instanceDescriptor->color;
        const float radius = (vid & 1) ? context->ptRadius1 : context->ptRadius2;
        
        const uint index = vid/2;
        const float a = M_PI_F * 2.0 * float(index) / float(ArrowCircleStepCount);
        resultOffset = float2(sin(a), cos(a)) * radius;
    } else {
        // circle vertices, 2nd pass
        out.color = float4(1);
        out.color.w = 0.1;
        const float radius = (vid & 1) ? context->ptRadius1 : 0;
        
        const uint index2 = (vid - ArrowCircleVertexCount)/2;
        const float a = M_PI_F * 2.0 * float(index2) / float(ArrowCircleStepCount);
        resultOffset = float2(sin(a), cos(a)) * radius;
    }

    const float4 visibleRect = context->visibleRect; // logic absolute coordinates
    const float2 graphSize = visibleRect.zw; // width, height in graph logic points
    const float2 screenSize = float2(context->screenSize); // int --> float
    
    float2 position = center.xy - visibleRect.xy;  // move to x0, y0
    position = position / graphSize * 2.0 - 1.0;
    
    position *= screenSize;
    position += resultOffset;
    position /= screenSize;
    
    out.clipSpacePosition = float4(position.x, position.y, 0.0, 1.0);
    out.mode = 0;
    return out;
}


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
    const uint stride = context->stride;
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
    const uint stride = context->stride;
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


RasterizerData
vShaderDash(uint vid,
            constant LineDescriptor *lineDescriptor,
            constant ChartContext *context)
{
    RasterizerData out;
    out.mode = lineDescriptor->isVertical ? LineOrientationVertical : LineOrientationHorizontal;
    out.color = lineDescriptor->color;
    out.dashPattern = lineDescriptor->dashPattern;
    
    const float4 graphBox = context->visibleRect; // graph size
    const float2 graphSize = graphBox.zw; // width, height in graph logic points
    const float lineWidth2 = lineDescriptor->lineWidth / 2.0; // half line width

    float2 currPt;
    float2 resultOffset = float2(0);
    if (lineDescriptor->isVertical) {
        currPt.y = context->boundingBox.y;
        currPt.x = lineDescriptor->offset;
        if (vid & 2) {
            currPt.y += context->boundingBox.w;
        }
        resultOffset.x = (vid & 1) ? lineWidth2 : -lineWidth2;

    } else {
        currPt.x = context->boundingBox.x;
        currPt.y = lineDescriptor->offset;
        if (vid & 2) {
            currPt.x += context->boundingBox.z;
        }
        resultOffset.y = (vid & 1) ? lineWidth2 : -lineWidth2;
    }
    
    float2 position = (currPt - graphBox.xy) / graphSize * 2.0 - 1.0; // move to x0, y0 and scale to clip space 2x2
    
    
    const float2 screenSize = float2(context->screenSize);
    position *= screenSize;
    position += resultOffset;
    position /= screenSize;

    out.clipSpacePosition = float4(position.x, position.y, 0.0, 1.0);
    return out;
}

// 3 vertices, the marker points upward, to point downward multiply y by -1
constant float2 vxMarkerArray[3] = { float2(0, 0), float2(0.5, -1), float2(-0.5, -1)};

RasterizerData
vShaderExtMarker(uint vid,
            constant float *vertices,
            constant ExtMarkerDescriptor *markerDescriptor,
            constant ChartContext *context)
{
    RasterizerData out;
    if (markerDescriptor->index + 1 >= context->vertexCount) {
        out.mode = LineOrientationDiscard;
        return out;
    }
    out.color = markerDescriptor->color;
    out.mode = LineOrientationNone;

    const float4 graphBox = context->visibleRect; // graph size
    const float2 screenSize = float2(context->screenSize);
    const float2 graphSize = graphBox.zw; // width, height in graph logic points
    
    // map iid (turn a plane on/off)
    const uint iiy = markerDescriptor->offsetIY;
    const uint addr = (markerDescriptor->index + 1) * markerDescriptor->stride;
    const float2 currPt = GET_POINT_AT(addr);
    float2 resultOffset = vxMarkerArray[vid] * markerDescriptor->size;
    resultOffset.y *= markerDescriptor->direction; // up or down
    
    float2 position = (currPt - graphBox.xy) / graphSize * 2.0 - 1.0; // move to x0, y0 and scale to clip space 2x2
    position *= screenSize;
    position += resultOffset;
    position /= screenSize;
    out.clipSpacePosition = float4(position.x, position.y, 0.0, 1.0);
    
    return out;
}

RasterizerData
vShaderVerticalLine(uint vid,
                    uint iid,
                    constant float *vertices,
            constant VerticalLineDescriptor *vLineDescriptor,
            constant ChartContext *context)
{
    RasterizerData out;
    out.mode = LineOrientationVertical;
    out.color = vLineDescriptor->color;
    out.dashPattern = vLineDescriptor->dashPattern;

//    out.clipSpacePosition = float4(0, 0, 0.0, 1.0);
//    return out;

    const float4 graphBox = context->visibleRect; // graph size
    const float2 graphSize = graphBox.zw; // width, height in graph logic points
    const float lineWidth2 = vLineDescriptor->lineWidth / 2.0; // half line width
    const uint stride = context->stride;
    const uint index = vLineDescriptor->vxIndices[iid];
    
    if (index >= context->vertexCount) {
        out.mode = LineOrientationDiscard;
        return out;
    }
    
    // X connected to a vertex; Y either top or bottom boundingBox value
    float2 pt0;
    pt0.x = vertices[(index + 1) * stride];
    pt0.y = (vid & 2) ? context->boundingBox.y : context->boundingBox.y + context->boundingBox.w;
    float2 position = (pt0 - graphBox.xy) / graphSize * 2.0 - 1.0; // move to x0, y0 and scale to clip space 2x2
    
    const float resultOffsetX = (vid & 1) ? lineWidth2 : -lineWidth2;
    const float2 screenSize = float2(context->screenSize);
    position *= screenSize;
    position.x += resultOffsetX;
    position /= screenSize;
    
    out.clipSpacePosition = float4(position.x, position.y, 0.0, 1.0);
    return out;
}

/// Line Chart Vertex Function
vertex RasterizerData
vertexShader(const uint vid [[ vertex_id ]],
             const uint iid [[ instance_id ]],
             constant float *vertices [[ buffer(ZVxShaderBidVertices) ]],
             constant void *anyDescriptor [[ buffer(ZVxShaderBidInstanceDescriptor) ]],
             constant ChartContext *context  [[ buffer(ZVxShaderBidChartContext) ]] )
{
    switch (context -> vshaderMode) {
        case VShaderModeDash: {
            constant LineDescriptor *descriptors = static_cast<constant LineDescriptor*>(anyDescriptor);
            constant LineDescriptor *lnDescriptor = &descriptors[iid];
            return vShaderDash(vid, lnDescriptor, context);
        }
            
        case VShaderModeFill: {
            constant InstanceDescriptor *descriptors = static_cast<constant InstanceDescriptor*>(anyDescriptor);
            constant InstanceDescriptor *instDescriptor = &descriptors[iid];
            return vShaderFill(vid, vertices, instDescriptor, context);
        }
            
        case VShaderModeArrow: {
            constant InstanceDescriptor *descriptors = static_cast<constant InstanceDescriptor*>(anyDescriptor);
            constant InstanceDescriptor *instDescriptor = &descriptors[iid];
            return vShaderArrow(vid, vertices, instDescriptor, context);
        }
            
        case VShaderModeStroke: {
            constant InstanceDescriptor *descriptors = static_cast<constant InstanceDescriptor*>(anyDescriptor);
            constant InstanceDescriptor *instDescriptor = &descriptors[iid];
            return vShaderStroke(vid, vertices, instDescriptor, context);
        }
            
        case VShaderModeExtMarker: {
            constant ExtMarkerDescriptor *descriptors = static_cast<constant ExtMarkerDescriptor*>(anyDescriptor);
            constant ExtMarkerDescriptor *markerDescriptor = &descriptors[iid];
            return vShaderExtMarker(vid, vertices, markerDescriptor, context);
        }
            
        case VShaderModeVerticalLine: {
            constant VerticalLineDescriptor *descriptor = static_cast<constant VerticalLineDescriptor*>(anyDescriptor);
            return vShaderVerticalLine(vid, iid, vertices, descriptor, context);
        }
            
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
