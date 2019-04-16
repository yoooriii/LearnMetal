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
    AAPLVertexInputIndexViewportSize = 1,
    AAPLVertexInputIndexScreenSize = 2
} AAPLVertexInputIndex;

typedef struct {
    vector_float2 position;
    vector_float2 normal;
    vector_float2 nextNormal;
    vector_float2 direction;
    // Floating-point RGBA colors
    vector_float4 color;
} ChartRenderVertex;

#endif /* ShaderTypes_h */
