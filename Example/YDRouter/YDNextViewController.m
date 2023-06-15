//
//  YDNextViewController.m
//  YDRouter_Example
//
//  Created by 王远东 on 2023/6/13.
//  Copyright © 2023 wangyuandong. All rights reserved.
//

#import "YDNextViewController.h"
#import "YDNextViewController+YDAssociated.h"
#import <YDRouter/YDRouter.h>

@interface YDNextViewController ()

@end

@implementation YDNextViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    UILabel *titleLabel = [[UILabel alloc] init];
    [self.view addSubview:titleLabel];
    titleLabel.text = NSStringFromClass([self class]);
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.frame = CGRectMake(0, 0, 300, 60);
    titleLabel.center = CGPointMake([UIScreen mainScreen].bounds.size.width/2, [UIScreen mainScreen].bounds.size.height/2);
    
    NSLog(@"%@", self.associatedObject);
    NSLog(@"url: ====== %@", self.routerURL);
}


@end
