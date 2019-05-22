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
    VShaderModeArrow
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
    uint32_t vshaderMode;   // VShaderMode
    // point
    float ptRadius1;        // min pointer radius
    float ptRadius2;        // max pointer radius
    float ptOffsetNX;       // pointer normalized x offset [0...1]
    vector_int2  ptRange;          // pointer range: it is located between 2 points in given range
    // extra
    float extraFloat[8];
    int32_t extraInt[8];
} ChartContext;         // metal buffer index ZVxShaderBidChartContext

typedef struct {
    vector_float4 color;
    uint stride;
    uint offsetIY;   // in buffer an offset from X
} InstanceDescriptor;

typedef struct {
    vector_float4 color;
    int isVertical;  // 1 = vertical, 0 = horizontal
    vector_float2 dashPattern;
    float lineWidth;
    float offset; // x or y offset in absolute coordinates
} LineDescriptor;

#endif /* ShaderTypes_h */
