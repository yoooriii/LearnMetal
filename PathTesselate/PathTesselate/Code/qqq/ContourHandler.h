//
//  ContourHandler.h
//  MetalExtrudedText-iOS
//
//  Created by Leonid Lokhmatov on 4/22/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

#import <Foundation/Foundation.h>
//#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>
#import "tesselator.h"
#import "TestDefinitions.h"

NS_ASSUME_NONNULL_BEGIN

@interface ContourHandler : NSObject

@property (nonatomic, readonly) int count;
@property (nonatomic, readonly) TestVertex* vertices;
// how many points handled, iterations number
@property (nonatomic, assign) int iterationCount;

@property (nonatomic, readonly) unsigned short* closeIndices;
@property (nonatomic, readonly) int countCloseIndices;

@property (nonatomic, assign) int debugLevel;

// add a point to the current contour (opens a new contour if one is not open)
//- (void)addPoint:(CGPoint)point;
//- (void)closeContour;
- (void)evaluatePath:(CGPathRef)path;
- (id<MTLBuffer> __nullable)createVertexBufferWithDevice:(id<MTLDevice>)device;
- (MetalPathBuffers* __nullable)createBuffersWithDevice:(id<MTLDevice>)device;
- (MetalPathBuffers* __nullable)createMeshWithDevice:(id<MTLDevice>)device;

@end


static inline float lerp(float a, float b, float t);
static inline CGPoint evalQuadCurve(CGPoint a, CGPoint b, CGPoint c, CGFloat t);
static inline CGPoint evalCubicCurve(CGPoint p0, CGPoint p1, CGPoint p2, CGPoint p3, CGFloat t);

/// CGPathApplierFunction
//void PathApplierFunction(void *info, const CGPathElement *element);


NS_ASSUME_NONNULL_END
