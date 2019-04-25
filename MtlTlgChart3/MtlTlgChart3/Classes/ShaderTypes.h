//
//  ShaderTypes.h
//  GraphPresenter
//
//  Created by Andre on 3/27/19.
//  Copyright © 2019 BB. All rights reserved.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

typedef enum {
    AAPLVertexInputIndexVertices = 0,
    AAPLVertexInputIndexChartContext = 1
} AAPLVertexInputIndex;

typedef enum {
    VShaderModeStroke = 0,
    VShaderModeFill = 1
} VShaderMode;

/// line chart
typedef struct {
    vector_float4 graphRect;
    vector_int2 screenSize;
    vector_float4 color;
    float lineWidth;
    uint vertexCount;
    int vshaderMode; // VShaderMode
} ChartContext;  // <-- AAPLVertexInputIndexChartContext

#endif /* ShaderTypes_h */
