# Basic Buffers

Demonstrates how to manage hundreds of vertices with a vertex buffer.

## Overview

In the [Hello Triangle](https://developer.apple.com/documentation/metal/hello_triangle) sample, you learned how to render basic geometry in Metal

In this sample, you'll learn how to use a vertex buffer to improve your rendering efficiency. In particular, you'll learn how to use a vertex buffer to store and load vertex data for multiple quads.

## Getting Started

The Xcode project contains schemes for running the sample on macOS, iOS, or tvOS. Metal is not supported in the iOS or tvOS Simulator, so the iOS and tvOS schemes require a physical device to run the sample. The default scheme is macOS, which runs the sample as is on your Mac.

## Manage Large Amounts of Vertex Data

In the [Hello Triangle](https://developer.apple.com/documentation/metal/hello_triangle) sample, the sample renders three vertices of 32 bytes each, amounting to 96 bytes of vertex data. This small amount of vertex data is sent to a vertex function through a call to the `setVertexBytes:length:atIndex:` method. This method allocates a small amount of memory that's accessible to the graphics processing unit (GPU) and can be allocated in each frame without a noticeable performance cost.

Unlike the [Hello Triangle](https://developer.apple.com/documentation/metal/hello_triangle) sample, this sample renders 2,250 vertices of 32 bytes each, amounting to 72,000 bytes of vertex data. This amount of vertex data needs to be managed more efficiently. In fact, Metal does not allow use of the `setVertexBytes:length:atIndex:` method for vertex data that exceeds 4 kilobytes (4,096 bytes). More importantly, the vertex data should not be reallocated and copied in each frame.

Typically, Metal apps or games draw models with thousands of vertices, each with multiple vertex attributes, that consume several megabytes of memory. For these apps or games to scale well and be managed efficiently, Metal provides specialized data containers represented by `MTLBuffer` objects. These buffers are GPU-accessible memory allocations for storing many kinds of custom data, although they're typically used for vertex data. This sample allocates a large amount of vertex data once, copies it into a `MTLBuffer` object, and then reuses the vertex data in each frame.

## Allocate, Generate, and Copy Vertex Data

In Objective-C, byte buffers are wrapped by `NSData` or `NSMutableData` objects, which are safe and convenient to use. The `AAPLVertex` data type is used for each vertex in the sample, and each quad is made up of 6 of these vertex values (with two triangles per quad). The 30 x 20 grid of quads amounts to 3,600 vertices occupying 115,200 bytes of memory, the amount to allocate for the sample's vertex data.

``` objective-c
const AAPLVertex quadVertices[] =
{
    // Pixel positions, RGBA colors
    { { -20,   20 },    { 1, 0, 0, 1 } },
    { {  20,   20 },    { 0, 0, 1, 1 } },
    { { -20,  -20 },    { 0, 1, 0, 1 } },

    { {  20,  -20 },    { 1, 0, 0, 1 } },
    { { -20,  -20 },    { 0, 1, 0, 1 } },
    { {  20,   20 },    { 0, 0, 1, 1 } },
};
const NSUInteger NUM_COLUMNS = 25;
const NSUInteger NUM_ROWS = 15;
const NSUInteger NUM_VERTICES_PER_QUAD = sizeof(quadVertices) / sizeof(AAPLVertex);
const float QUAD_SPACING = 50.0;

NSUInteger dataSize = sizeof(quadVertices) * NUM_COLUMNS * NUM_ROWS;
NSMutableData *vertexData = [[NSMutableData alloc] initWithLength:dataSize];
```

Typically, Metal apps or games load vertex data from model files. The complexity of model-loading code varies by model, but ultimately the vertex data is also stored in a byte buffer that's handed off to Metal code. To avoid introducing model-loading code, this sample simulates the vertex data handoff with the `generateVertexData` method, which generates simple vertex data at runtime.

Both `NSData` and `MTLBuffer` objects store custom data, which means your app is responsible for defining and interpreting this data correctly during read or write operations.  In this sample, the vertex data is read-only and its memory layout is defined by the `AAPLVertex` data type, which is what the `vertexShader` vertex function requires.

``` metal
vertex RasterizerData
vertexShader(uint vertexID [[ vertex_id ]],
             device AAPLVertex *vertices [[ buffer(AAPLVertexInputIndexVertices) ]],
             constant vector_uint2 *viewportSizePointer  [[ buffer(AAPLVertexInputIndexViewportSize) ]])
```

Fundamentally, both `NSData` and `MTLBuffer` objects are quite similar. However, a `MTLBuffer` object is a specialized container accessible to the GPU, enabling the graphics render pipeline to read vertex data from it.

``` objective-c
NSData *vertexData = [AAPLRenderer generateVertexData];

// Create a vertex buffer by allocating storage that can be read by the GPU
_vertexBuffer = [_device newBufferWithLength:vertexData.length
                                     options:MTLResourceStorageModeShared];

// Copy the vertex data into the vertex buffer by accessing a pointer via
// the buffer's `contents` property
memcpy(_vertexBuffer.contents, vertexData.bytes, vertexData.length);
```

First, the `newBufferWithLength:options:` method creates a new `MTLBuffer` object of a certain byte size and with certain access options. The vertex data occupies 115,200 bytes of memory (`vertexData.length`) that's written by the CPU and read by the GPU (`MTLResourceStorageModeShared`).

Second, the `memcpy()` function copies vertex data from a source `NSData` object to a destination `MTLBuffer` object. The `_vertexBuffer.contents` query returns a CPU-accessible pointer to the buffer's memory. The vertex data is copied into this destination through a pointer to the source data (`vertexData.bytes`) and a specified amount of data to be copied (`vertexData.length`).

## Set and Draw Vertex Data

Because the sample's vertex data is now stored in a `MTLBuffer` object, the `setVertexBytes:length:atIndex:` method can no longer be called; the `setVertexBuffer:offset:atIndex:` method is called instead. This method takes as parameters a vertex buffer, a byte offset to the vertex data in that buffer, and an index that maps the buffer to the vertex function.

- Note: Using a `MTLBuffer` as a vertex function argument does not prevent an app or game from using the `setVertexBytes:length:atIndex:` method to set data for another argument. In fact, this sample still uses the `viewportSizePointer` argument introduced in the [Hello Triangle](https://developer.apple.com/documentation/metal/hello_triangle) sample.

Finally, all vertices are drawn by issuing a draw call that starts from the first vertex in the array (`0`) and ends at the last (`_numVertices`).

``` objective-c
[renderEncoder setVertexBuffer:_vertexBuffer
                        offset:0
                       atIndex:AAPLVertexInputIndexVertices];

[renderEncoder setVertexBytes:&_viewportSize
                       length:sizeof(_viewportSize)
                      atIndex:AAPLVertexInputIndexViewportSize];

// Draw the vertices of the quads
[renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                  vertexStart:0
                  vertexCount:_numVertices];
```

## Next Steps

In this sample, you learned how to use a vertex buffer to improve your rendering efficiency.

In the [Basic Texturing](https://developer.apple.com/documentation/metal/basic_texturing) sample, you'll learn how to load image data and texture a quad.
