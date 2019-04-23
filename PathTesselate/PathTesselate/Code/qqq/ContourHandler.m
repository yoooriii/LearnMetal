//
//  ContourHandler.m
//  MetalExtrudedText-iOS
//
//  Created by Leonid Lokhmatov on 4/22/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

#import "ContourHandler.h"

#define DEFAULT_CURVE_SUBDIVISIONS 5

/// CGPathApplierFunction
void PathApplierFunction(void *info, const CGPathElement *element);

static inline float lerp(float a, float b, float t) {
    return a + t * (b - a);
}

static inline CGPoint evalQuadCurve(CGPoint a, CGPoint b, CGPoint c, CGFloat t) {
    CGPoint q0 = CGPointMake(lerp(a.x, c.x, t), lerp(a.y, c.y, t));
    CGPoint q1 = CGPointMake(lerp(c.x, b.x, t), lerp(c.y, b.y, t));
    CGPoint r = CGPointMake(lerp(q0.x, q1.x, t), lerp(q0.y, q1.y, t));
    return r;
}

static inline CGPoint evalCubicCurve(CGPoint p0, CGPoint p1, CGPoint p2, CGPoint p3, CGFloat t) {
    const CGFloat invT = 1.0-t;
    const CGFloat x = invT*invT*invT*p0.x + 3.0*invT*invT*t*p1.x + 3.0*invT*t*t*p2.x + t*t*t*p3.x;
    const CGFloat y = invT*invT*invT*p0.y + 3.0*invT*invT*t*p1.y + 3.0*invT*t*t*p2.y + t*t*t*p3.y;
    return CGPointMake(x, y);
}

inline static TestVertex TestVertexMake(CGPoint pt) {
    TestVertex vertex;
    vertex.x = pt.x;
    vertex.y = pt.y;
    return vertex;
}

#pragma mark -

@interface ContourHandler ()

@property (nonatomic, assign) int count;
@property (nonatomic, assign) TestVertex* vertices;
@property (nonatomic, assign) int capacity;

@property (nonatomic, assign) unsigned short* closeIndices;
@property (nonatomic, assign) int countCloseIndices;
@property (nonatomic, assign) int indCapacity;

@property (nonatomic, assign) CGPoint lastPoint;
@end

@implementation ContourHandler

- (instancetype)init {
    if ((self = [super init])) {
        self.capacity = 256;
        self.vertices = malloc(sizeof(TestVertex) * self.capacity);
        
        self.indCapacity = 16;
        self.closeIndices = malloc(sizeof(unsigned short) * self.indCapacity);
        
        [self cleanup];
    }
    return self;
}

- (void)dealloc {
    if (self.vertices) {
        free(self.vertices);
        self.vertices = NULL;
    }
    if (self.closeIndices) {
        free(self.closeIndices);
        self.closeIndices = NULL;
    }
}

- (void)cleanup {
    self.iterationCount = 0;
    self.lastPoint = CGPointMake(-100, -100);
    self.count = 0;
    self.countCloseIndices = 0;
    //debug: fill arrays with fake data
    for (int i=0; i< self.countCloseIndices; ++i) {
        self.closeIndices[i] = 999;
    }
    for (int i=0; i< self.capacity; ++i) {
        self.vertices[i].x = -99.1;
        self.vertices[i].y = -99.2;
    }
}

- (void)addCloseIndex:(unsigned short)index {
    if (self.countCloseIndices >= self.indCapacity) {
        self.indCapacity *= 2;
        self.closeIndices = realloc(self.closeIndices, self.indCapacity);
    }
    self.closeIndices[self.countCloseIndices++] = index;
}

- (void)addStartPoint:(CGPoint)point {
    // maybe add start new contour logic here
    [self addPoint:point];
}

- (void)addPoint:(CGPoint)point {
    self.lastPoint = point;
    if (self.count >= self.capacity) {
        self.capacity *= 2;
        self.vertices = realloc(self.vertices, sizeof(TestVertex) * self.capacity);
    }
    TestVertex vx = TestVertexMake(point);
    self.vertices[self.count++] = vx;
}

#define VERT_COMPONENT_COUNT 2 // 2D vertices (x, y)

- (void)closeContour {
    if (self.count > 0) {
        // the previous point closes this contour
        [self addCloseIndex:(unsigned short)self.count-1];
    }
    self.lastPoint = CGPointMake(-100, -100);

    if (self.debugLevel > 0) {
        NSLog(@"Close contour [%d:%d]", self.iterationCount, self.count);
    }
}

- (void)evaluatePath:(CGPathRef)path {
    [self cleanup];
    CGPathApply(path, (void*)self, PathApplierFunction);
}

- (id<MTLBuffer>)createVertexBufferWithDevice:(id<MTLDevice>)device {
    if (!self.count) {
        return nil;
    }
    
    const int vertexBufSize = self.count * sizeof(TestVertex);
    id<MTLBuffer> vertexBuffer = [device newBufferWithBytes:self.vertices
                                               length:vertexBufSize
                                              options:MTLResourceCPUCacheModeDefaultCache];
    return vertexBuffer;
}

- (MetalPathBuffers*)createBuffersWithDevice:(id<MTLDevice>)device {
    if (!self.count) {
        return nil;
    }
    if (!device) {
        return nil;
    }

    MetalPathBuffers *buffers = [MetalPathBuffers new];
    buffers.vertexCount = self.count;
    
    const int vertexBufSize = self.count * sizeof(TestVertex);
    buffers.vertexBuffer = [device newBufferWithBytes:self.vertices
                                               length:vertexBufSize
                                              options:MTLResourceCPUCacheModeDefaultCache];

    int maxIndCount = self.count * 2 + 16; // count + magic number
    unsigned short *buf = malloc(sizeof(unsigned short) * maxIndCount);
    
    int indexCounter = 0;
    int iClose = 0;
    int iStartContour = 0; // start contour index
    for (int i=0; i < self.count; ++i) {
        buf[indexCounter++] = (unsigned short)i;
        
        if (iClose < self.countCloseIndices) {
            if (self.closeIndices[iClose] == i) {
                // close contour
                buf[indexCounter++] = (unsigned short)iStartContour;
                iStartContour = i; // start another contour
                ++iClose;
            }
        }
    }
    
    buffers.indexCount = indexCounter;
    const int indexBufSize = sizeof(unsigned short) * indexCounter;
    buffers.indexBuffer = [device newBufferWithBytes:buf
                                              length:indexBufSize
                                             options:MTLResourceCPUCacheModeDefaultCache];

    free(buf); buf = NULL;
    return buffers;
}

- (MetalPathBuffers*)createMeshWithDevice:(id<MTLDevice>)device {
    if (!device) {
        return nil;
    }
    if (!self.count) {
        // no vertices
        return nil;
    }
    if (!self.countCloseIndices) {
        // no close contours
        return nil;
    }
    
    // Create a new libtess tessellator, requesting constrained Delaunay triangulation
    TESStesselator *tesselator = tessNewTess(NULL);
    tessSetOption(tesselator, TESS_CONSTRAINED_DELAUNAY_TRIANGULATION, 1);
    
    int startContour = 0;
    for (int i=0; i< self.countCloseIndices; ++i) {
        int vertexCount = self.closeIndices[i] - startContour + 1;
        if (self.debugLevel > 0) {
            NSLog(@"#%d: add contour in range [start:count] = [%d:%d]", i, startContour, vertexCount);
        }
        tessAddContour(tesselator, 2, self.vertices + startContour, sizeof(TestVertex), vertexCount);
        startContour = self.closeIndices[i];
    }

    // Do the actual tessellation work
    const int polygonIndexCount = 3; // triangles only
    int result = tessTesselate(tesselator, TESS_WINDING_NONZERO, TESS_POLYGONS, polygonIndexCount, VERT_COMPONENT_COUNT, NULL);
    if (!result) {
        NSLog(@"Unable to tessellate path");
    }
    
    MetalPathBuffers* buffers = [MetalPathBuffers new];
    // Retrieve the tessellated mesh from the tessellator and copy the contour list and geometry to the current glyph
    buffers.vertexCount = tessGetVertexCount(tesselator);
    buffers.indexCount = tessGetElementCount(tesselator) * polygonIndexCount;
    
    if (buffers.vertexCount == 0 || buffers.indexCount == 0) {
        NSLog(@"");
        return nil;
    }
    
    const TESSreal *vertices = tessGetVertices(tesselator);
    const TESSindex *indices = tessGetElements(tesselator);
    
    if (self.debugLevel > 0) {
        NSLog(@"iteration:vertex:indices count = [%d:%d:%d]", self.iterationCount, buffers.vertexCount, buffers.indexCount);
        if (self.debugLevel > 1) {
            NSMutableString *debug = [NSMutableString new];
            [debug setString:@"indices: {"];
            for (int i=0; i< buffers.indexCount; ++i) {
                int indx = indices[i];
                [debug appendFormat:@" %d", indx];
            }
            [debug appendString:@" }"];
            NSLog(@"%@", debug);
            
            [debug setString:@"vertices: "];
            for (int i=0; i< buffers.vertexCount * 2; i+=2) {
                float v1 = vertices[i];
                float v2 = vertices[i+1];
                [debug appendFormat:@" p%d:[%2.1f, %2.1f]", i, v1, v2];
            }
            NSLog(@"%@", debug);
        }
    }
    
    const int vertexBufSize = buffers.vertexCount * sizeof(TESSreal) * 2;
    buffers.vertexBuffer = [device newBufferWithBytes:(void *)vertices
                                               length:vertexBufSize
                                              options:MTLResourceCPUCacheModeDefaultCache];
    
    const int indexBufSize = buffers.indexCount * sizeof(TESSindex);
    buffers.indexBuffer = [device newBufferWithBytes:(void *)indices
                                              length:indexBufSize
                                             options:MTLResourceCPUCacheModeDefaultCache];
    
    tessDeleteTess(tesselator);
    tesselator = NULL;
    
    return buffers;

}


- (NSString *)description {
    NSMutableString *text = [NSMutableString string];
    [text appendString:NSStringFromClass([self class])];
    [text appendFormat:@" [(%d) %d]", (int)self.iterationCount, (int)self.count];
    if (self.count) {
        [text appendString:@"{"];
        for (int i=0; i<self.count; ++i) {
            [text appendFormat:@" (%2.1f, %2.1f)", self.vertices[i].x, self.vertices[i].y];
        }
        [text appendString:@" }"];
    }
    return text;
}

@end


/// CGPathApplierFunction
void PathApplierFunction(void *info, const CGPathElement *element) {
    ContourHandler *contourHandler = (__bridge ContourHandler *)info;
    contourHandler.iterationCount += 1;
    
    switch (element->type) {
        case kCGPathElementMoveToPoint: {
            if (contourHandler.count != 0) {
                NSLog(@"Open subpaths are not supported; all contours must be closed (:)");
            }
            [contourHandler addStartPoint:element->points[0]];
        } break;
            
        case kCGPathElementAddLineToPoint: {
            [contourHandler addPoint:element->points[0]];
        } break;
            
        case kCGPathElementAddCurveToPoint: {
            CGPoint p0 = contourHandler.lastPoint;
            CGPoint p1 = element->points[0];
            CGPoint p2 = element->points[1];
            CGPoint p3 = element->points[2];
            for (int i = 0; i < DEFAULT_CURVE_SUBDIVISIONS; ++i) {
                float t = (float)i / (float)(DEFAULT_CURVE_SUBDIVISIONS - 1);
                CGPoint r = evalCubicCurve(p0, p1, p2, p3, t);
                [contourHandler addPoint:r];
            }
        } break;
            
        case kCGPathElementAddQuadCurveToPoint: {
            CGPoint p0 = contourHandler.lastPoint;
            CGPoint p1 = element->points[0];
            CGPoint p2 = element->points[1];
            for (int i = 0; i < DEFAULT_CURVE_SUBDIVISIONS; ++i) {
                float t = (float)i / (float)(DEFAULT_CURVE_SUBDIVISIONS - 1);
                CGPoint r = evalQuadCurve(p0, p2, p1, t);
                [contourHandler addPoint:r];
            }
        } break;
            
        case kCGPathElementCloseSubpath: {
            [contourHandler closeContour];
        }  break;
    }
}

#undef VERT_COMPONENT_COUNT
#undef DEFAULT_CURVE_SUBDIVISIONS
