//
//  ShaderTypes.h
//  GraphPresenter
//
//  Created by Andre on 3/27/19.
//  Copyright © 2019 BB. All rights reserved.
//  Updated by leonid@leeloo ©2019 Horns&Hoofs.®
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

typedef enum {
    AAPLVertexInputIndexVertices = 0,
    AAPLVertexInputIndexChartContext = 1,
    AAPLVertexInputIndexColor
} AAPLVertexInputIndex;

typedef enum {
    VShaderModeStroke = 0,
    VShaderModeFill = 1,
    VShaderModeDash = 2
} VShaderMode;

typedef enum {
    LineOrientationNone = 0,
    LineOrientationHorizontal = 1,
    LineOrientationVertical = 2
} LineOrientation;

/// line chart
typedef struct {
    vector_float4 graphRect;
    vector_int2 screenSize;
    float lineWidth;
    uint vertexCount;
    uint32_t vshaderMode; // VShaderMode

    vector_float4 color;
    // extra
    float extraFloat[8];
    uint32_t extraInt[8];
} ChartContext;  // <-- AAPLVertexInputIndexChartContext

#endif /* ShaderTypes_h */
