/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header containing types and enum constants shared between Metal shaders and C/ObjC source
*/

#ifndef AAPLShaderTypes_h
#define AAPLShaderTypes_h

#include <simd/simd.h>

#define MetalIndexVertices 0
#define MetalIndexRenderContext 1
#define MetalIndexTextureColor 2

typedef struct {
    // Floating-point RGBA colors
    vector_float4 strokeColor;
    vector_float4 fillColor;
    vector_uint2 viewportSize;
    float rotation;
    float animeValue;
} RenderContext;

#endif /* AAPLShaderTypes_h */
