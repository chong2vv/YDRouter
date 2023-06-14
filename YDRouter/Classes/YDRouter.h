//
//  YDRouter.h
//  YDRouter
//
//  Created by 王远东 on 2022/8/18.
//  Copyright © 2022 wangyuandong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YDURLHelper.h"

@interface YDRouter : NSObject

/**
 * URL注册映射表plist文件说明
 *
 * desc       描述
 * host       URL的host
 * class      跳转的类(__kindof UIViewController)
 * params     参数映射表
 *            {key:value}, key为class的属性名/关联对象名, value为String类型的URL
 *                         参数名并支持透传和直接赋值
 *            (透传userInfo:~, userInfo为AMURL的params+AMURLHandler的userInfo+
 *                             block回调finishHandler, 例如:
 *                             关联对象dict透传userInfo, 则为
 *                             <key>dict</key>
 *                             <string>~</string>)
 *            (直接赋值:~<data>, <data>为需要赋的值, 例如:
 *                              属性age赋值18, 则为
 *                              <key>age</key>
 *                              <string>18</string>)
 */

@property (nonatomic, copy, readonly) NSString *schemeUrl;

+ (void)setup;

+ (instancetype)sharedInstance;

/**
 配置scheme， 默认project
 */
- (void)configSetScheme:(NSString *)scheme;

// 自定义添加的跳转注册（非plist文件管理）
/**
 *  pattern不能包含大写字母
 */
+ (void)customResigtWithRouter:(YDRouter *)router;

/**
 *  调用此方法来拼接 urlpattern 和 parameters
 *
 *  #define MGJ_ROUTE_BEAUTY @"beauty/:id"
 *  [MGJRouter generateURLWithPattern:MGJ_ROUTE_BEAUTY, @[@13]];
 *
 *
 *  @param pattern    url pattern 比如 @"beauty/:id"
 *  @param parameters 一个数组，数量要跟 pattern 里的变量一致
 *
 *  @return 生成链接
 */
+ (NSString *)generateURLWithPattern:(NSString *)pattern parameters:(NSArray *)parameters;

/**
 不会直接跳转，而是回调注册时返回的构成数据，VC啦、UID啦等等，这样pod库或者扩展也都可以用
 */
+ (void)openURL:(YDURLHelper *)URL;
+ (void)openURL:(YDURLHelper *)URL withUserInfo:(NSDictionary *)userInfo;
+ (void)openURL:(YDURLHelper *)URL withUserInfo:(NSDictionary *)userInfo finish:(void (^)(id result))finishHandler;

/**
  不会直接跳转，而是回调注册时返回的构成数据，VC啦、UID啦等等，这样pod库或者扩展也都可以用
 */
+ (void)openURLStr:(NSString *)urlStr;
+ (void)openURLStr:(NSString *)urlStr finish:(void (^)(id result))finishHandler;
+ (void)openURLStr:(NSString *)urlStr userInfo:(NSDictionary *)userInfo;
+ (void)openURLStr:(NSString *)urlStr userInfo:(NSDictionary *)userInfo finish:(void (^)(id result))finishHandler;


/**
 注册路由回调，例如：
 [YDRouter.sharedInstance registerURLPattern:@"YDCheckLogin" toHandler:^(NSDictionary *userInfo) {
     NSDictionary *aParams = userInfo;
     YDLoginViewController *svc = [YDLoginViewController new];
     svc.modalPresentationStyle = UIModalPresentationFullScreen;
     svc.successCallback = [aParams objectForKey:kSuccessCallback];
     void(^callback)(id result) = userInfo[@"^"];
     callback(svc);
 }];
 */
- (void)registerURLPattern:(NSString *)URLPattern toHandler:(void (^)(NSDictionary *userInfo))handler;

@end

@interface UIViewController (YDRouter)

@property (nonatomic, copy) NSString *routerURL;


@end
