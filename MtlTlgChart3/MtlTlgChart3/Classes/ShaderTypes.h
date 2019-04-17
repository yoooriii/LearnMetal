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

typedef struct {
    vector_float2 position;
    vector_float2 normal;
    vector_float2 nextNormal;
    float direction;
} ChartRenderVertex;

typedef struct {
    vector_int4 viewportSize;
    vector_int2 screenSize;
    vector_float4 color;
    float lineWidth;
    uint vertexCount;
} ChartContext;  // <-- AAPLVertexInputIndexChartContext

#endif /* ShaderTypes_h */
