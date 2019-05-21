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
} ZVxShaderBid;

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
    uint32_t vshaderMode; // VShaderMode
    vector_float4 color;
    // extra
    float extraFloat[8];
    int32_t extraInt[8];
} ChartContext;         // metal buffer index ZVxShaderBidChartContext

typedef struct {
    vector_float4 color;
    uint stride;
    uint offsetIY;   // in buffer an offset from X
} InstanceDescriptor;

#endif /* ShaderTypes_h */
