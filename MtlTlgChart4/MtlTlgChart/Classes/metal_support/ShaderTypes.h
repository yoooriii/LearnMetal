//
//  ShaderTypes.h
//  GraphPresenter
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// vertex buffer index: [[ buffer(ZVxShaderBid...) ]]
typedef enum {
    ZVxShaderBidVertices,
    ZVxShaderBidChartContext,
    ZVxShaderBidInstanceDescriptor
} ZVxShaderBid; // buffer index (id)

typedef enum {
    VShaderModeStroke = 0,
    VShaderModeFill,
    VShaderModeDash,
    VShaderModeArrow,
    VShaderModeExtMarker,
    VShaderModeVerticalLine
} VShaderMode;

#define ArrowCircleStepCount 10
// ArrowCircleVertexCount = (ArrowCircleStepCount * 2 + 2)
#define ArrowCircleVertexCount 22

typedef struct {
    vector_float4 visibleRect;
    vector_float4 boundingBox;
    vector_int2 screenSize;
    float lineWidth;
    uint vertexCount;
    uint stride;
    uint32_t vshaderMode;   // VShaderMode
    // point
    float ptRadius1;        // min pointer radius
    float ptRadius2;        // max pointer radius
    float ptOffsetNX;       // pointer normalized x offset [0...1]
    vector_int2  ptRange;          // pointer range: it is located between 2 points in given range
    //
//    vector_float4 gridColor;
//    float gridLineWidth;
    // extra
    float extraFloat[8];
    int32_t extraInt[8];
} ChartContext;         // metal buffer index ZVxShaderBidChartContext

typedef struct {
    vector_float4 color;
    uint offsetIY;   // in buffer an offset from X to get a Y value
} InstanceDescriptor;

typedef struct {
    vector_float4 color;
    int isVertical;  // 1 = vertical, 0 = horizontal
    vector_float2 dashPattern;
    float lineWidth;
    float offset; // x or y offset in absolute coordinates
} LineDescriptor;

// VerticalLineDescriptor:
typedef struct {
    vector_float4 color;
    vector_float2 dashPattern;
    float lineWidth;
    uint count; // indices count (1 to array-size)
    uint vxIndices[20];   // it is connected with a given vertex; it contains repeatCount instances
} VerticalLineDescriptor;

typedef struct {
    vector_float4 color;
    uint stride;
    uint offsetIY;
    float size;
    float direction;    // +1 = points upward, -1 = points downward
    uint index;         // vertex index
} ExtMarkerDescriptor;  // points to a min/max vertice

#endif /* ShaderTypes_h */
