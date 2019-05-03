//
//  TestPathMath.h
//  MetalExtrudedText-iOS
//
//  Created by Leonid Lokhmatov on 4/22/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <MetalKit/MetalKit.h>
#import "tesselator.h"

NS_ASSUME_NONNULL_BEGIN

@interface TestPathMath : NSObject
+ (CGPathRef)createTestPathInRect:(CGRect)rect;
@end

NS_ASSUME_NONNULL_END
