//
//  TestShapeTesselate.m
//  PathTesselate
//
//  Created by Leonid Lokhmatov on 4/21/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

#import "TestShapeTesselate.h"
#import "tesselator.h"

@implementation TestShapeTesselate

//- (void) test1 {
//    TESStesselator *tessellator = tessNewTess(NULL);
//    tessSetOption(tessellator, TESS_CONSTRAINED_DELAUNAY_TRIANGULATION, 1);
//
//    tessAddContour(tessellator, 2, vertices, sizeof(PathVertex), vertexCount);
//    tessTesselate(tessellator, TESS_WINDING_ODD, TESS_POLYGONS, 3, 2, NULL);
//
//    int vertexCount = tessGetVertexCount(tessellator);
//    const TESSreal *vertices = tessGetVertices(tessellator);
//    int indexCount = tessGetElementCount(tessellator) * 3;
//    const TESSindex *indices = tessGetElements(tessellator);
//
//    MDLSubmesh *submesh = [[MDLSubmesh alloc] initWithIndexBuffer:indexBuffer
//                                                       indexCount:indexCount
//                                                        indexType:MDLIndexBitDepthUInt32
//                                                     geometryType:MDLGeometryTypeTriangles
//                                                         material:nil];
//    NSArray *submeshes = @[submesh];
//    MDLMesh *mdlMesh = [self meshForVertexBuffer:vertexBuffer
//                                     vertexCount:vertexCount
//                                       submeshes:submeshes
//                                vertexDescriptor:vertexDescriptor];
//
//    NSError *error = nil;
//    MTKMesh *mesh = [[MTKMesh alloc] initWithMesh:mdlMesh
//                                           device:device
//                                            error:&error];
//}

@end
