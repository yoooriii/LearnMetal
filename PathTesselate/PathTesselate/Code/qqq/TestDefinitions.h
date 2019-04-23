//
//  TestDefinitions.h
//  MetalExtrudedText-iOS
//
//  Created by Leonid Lokhmatov on 4/22/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

#import <Foundation/Foundation.h>
#import "tesselator.h"
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct TestVertex {
    float x, y;
} TestVertex;

typedef struct PathMeshContent {
    int vertexCount;
    int indexCount;
    const TESSreal *vertices;
    const TESSindex *indices;
} PathMeshContent;

@interface MetalPathBuffers : NSObject
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> indexBuffer;
@property (nonatomic, assign) int vertexCount;
@property (nonatomic, assign) int indexCount;
@end


NS_ASSUME_NONNULL_END
