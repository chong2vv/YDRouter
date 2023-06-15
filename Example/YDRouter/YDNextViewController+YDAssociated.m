//
//  YDNextViewController+YDAssociated.m
//  YDRouter_Example
//
//  Created by 王远东 on 2023/6/15.
//  Copyright © 2023 wangyuandong. All rights reserved.
//

#import "YDNextViewController+YDAssociated.h"
#import <objc/runtime.h>

@implementation YDNextViewController (YDAssociated)

- (NSString *)associatedObject {
    return objc_getAssociatedObject(self, @selector(associatedObject));
}

- (void)setAssociatedObject:(NSString *)associatedObject {
    objc_setAssociatedObject(self, @selector(associatedObject), associatedObject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


@end
