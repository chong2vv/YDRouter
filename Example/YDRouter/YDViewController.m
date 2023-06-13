//
//  YDViewController.m
//  YDRouter
//
//  Created by wangyuandong on 08/18/2022.
//  Copyright (c) 2022 wangyuandong. All rights reserved.
//

#import "YDViewController.h"
#import <YDRouter/YDRouter.h>
#import "YDNextViewController.h"

@interface YDViewController ()

@end

@implementation YDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
//    [[YDRouter sharedInstance] registerURLPattern:@"nextViewController" toHandler:^(NSDictionary *userInfo) {
//        YDNextViewController * svc = [[YDNextViewController alloc] init];
//        void(^callback)(id result) = userInfo[@"^"];
//        callback(svc);
//    }];
    
}
- (IBAction)routerOpen:(id)sender {
    [YDRouter openURLStr:@"ydrouter://nextViewController" finish:^(id result) {
        UIViewController *vc = result;
        [self.navigationController pushViewController:vc animated:YES];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
