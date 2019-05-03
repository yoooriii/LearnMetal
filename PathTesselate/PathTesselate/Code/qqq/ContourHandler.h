//
//  ContourHandler.h
//  MetalExtrudedText-iOS
//
//  Created by Leonid Lokhmatov on 4/22/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MTLBuffer;

@interface PathMesh : NSObject
@property (nonatomic, strong) id<MTLBuffer> __nullable vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> __nullable indexBuffer;
@property (nonatomic, assign) int32_t vertexCount;
@property (nonatomic, assign) int32_t indexCount;
@end


@interface ContourHandler : NSObject

@property (nonatomic, readonly) int count;
// how many points handled, iterations number
@property (nonatomic, assign) int iterationCount;

@property (nonatomic, readonly) unsigned short* closeIndices;
@property (nonatomic, readonly) int countCloseIndices;
@property (nonatomic, assign) int debugLevel;

- (void)evaluatePath:(CGPathRef)path;
- (PathMesh* __nullable)createMeshWithDevice:(id<MTLDevice>)device;

@end

NS_ASSUME_NONNULL_END
