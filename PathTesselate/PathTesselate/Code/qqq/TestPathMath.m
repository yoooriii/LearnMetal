//
//  TestPathMath.m
//  MetalExtrudedText-iOS
//
//  Created by Leonid Lokhmatov on 4/22/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

#import "TestPathMath.h"
#import "ContourHandler.h"
#import <MetalKit/MetalKit.h>

@implementation TestPathMath



+ (CGPathRef)createTestPathInRect:(CGRect)rect {
    CGMutablePathRef path = CGPathCreateMutable();
    
    CGPathMoveToPoint(path, NULL, CGRectGetMinX(rect), CGRectGetMidY(rect));
    int count = 10;
    for (int i = 0; i < count; ++i) {
        CGFloat x = rect.size.width * ((CGFloat)i + 0.5) / (CGFloat)count + CGRectGetMinX(rect);
        CGFloat y = (i & 1) ? CGRectGetMinY(rect) : CGRectGetMaxY(rect);
        CGPathAddLineToPoint(path, NULL, x, y);
    }
    CGPathAddLineToPoint(path, NULL, CGRectGetMaxX(rect), CGRectGetMidY(rect));
    
    return path;
}



@end
