//
//  YDRouter.m
//  YDRouter
//
//  Created by 王远东 on 2022/8/18.
//  Copyright © 2022 wangyuandong. All rights reserved.
//

#import "YDRouter.h"
#import <objc/runtime.h>
#import "MGJRouter.h"

#define SuppressPerformSelectorLeakWarning(Stuff) \
do { \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
Stuff; \
_Pragma("clang diagnostic pop") \
} while (0)

static const void *RouterURL = &RouterURL;
static const void *HandlerUserInfo = &HandlerUserInfo;

@interface UIViewController (XLBaseViewController)

- (UIViewController *)baseViewController;

@end

@implementation UIViewController (XLBaseViewController)

- (UIViewController *)baseViewController {
    __weak UIViewController *result = self;
    while ([result isKindOfClass:[UITabBarController class]] || [result isKindOfClass:[UINavigationController class]]) {
        if ([result isKindOfClass:[UITabBarController class]]) {
            __weak UITabBarController *tbVC = (UITabBarController *)result;
            result = tbVC.selectedViewController;
        } else if ([result isKindOfClass:[UINavigationController class]]) {
            __weak UINavigationController *navVC = (UINavigationController *)result;
            result = navVC.viewControllers.lastObject;
        }
    }
    if (result) {
        return result;
    }
    return self;
}

@end

@implementation UIViewController (YDRouter)
@dynamic routerURL;
@dynamic handlerUserInfo;

- (void)setRouterURL:(NSString *)routerURL {
    NSArray *vcs = self.childViewControllers;
    if (vcs && vcs.count > 0) {
        [vcs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            __weak UIViewController *vc = obj;
            vc.routerURL = [routerURL copy];
        }];
    }
    objc_setAssociatedObject(self, RouterURL, routerURL, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setHandlerUserInfo:(NSDictionary *)handlerUserInfo {
    NSArray *vcs = self.childViewControllers;
    if (vcs && vcs.count > 0) {
        [vcs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            __weak UIViewController *vc = obj;
            vc.handlerUserInfo = [handlerUserInfo copy];
        }];
    }
    objc_setAssociatedObject(self, HandlerUserInfo, handlerUserInfo, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)routerURL {
    return objc_getAssociatedObject(self, RouterURL);
}

- (NSDictionary *)handlerUserInfo {
    return objc_getAssociatedObject(self, HandlerUserInfo);
}

@end

@interface YDRouter ()
@property (nonatomic, copy) NSArray *vcMap;
@property (nonatomic, weak) UINavigationController *navVC;
@property (nonatomic, weak) UITabBarController *tbVC;
@property (nonatomic, copy) NSString *schemeUrl;
@end

@implementation YDRouter

+ (instancetype)sharedInstance
{
    static YDRouter *instance = nil;
    if (!instance) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            instance = [[self class] new];
            __weak UIWindow *window = nil;
            id appDelegate = [UIApplication sharedApplication].delegate;
            SEL sel = NSSelectorFromString(@"window");
            if ([appDelegate respondsToSelector:sel]) {
                IMP imp = [appDelegate methodForSelector:sel];
                UIWindow *(*func)(id, SEL) = (void *)imp;
                window = func(appDelegate, sel);
            }
        });
    }
    return instance;
}

- (void)configSetScheme:(NSString *)scheme
{
    self.schemeUrl = scheme;
}

+ (UIViewController *)currentVC
{
    UIViewController *result = nil;
    UIWindow * window = [[UIApplication sharedApplication] keyWindow];
    if (window.windowLevel != UIWindowLevelNormal) {
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for(UIWindow * tmpWin in windows) {
            if (tmpWin.windowLevel == UIWindowLevelNormal) {
                window = tmpWin;
                break;
            }
        }
    }
    
    UIView *frontView = [[window subviews] objectAtIndex:0];
    id nextResponder = [frontView nextResponder];
    
    if ([nextResponder isKindOfClass:[UIViewController class]]) {
        result = nextResponder;
    } else {
        result = window.rootViewController;
    }
    
    result = result.baseViewController;
    
    if (result.presentedViewController) {
        result = result.presentedViewController.baseViewController;;
    }
    
    return result;
}

+ (void)pushVC:(UIViewController *)vc userInfo:(NSDictionary *)userInfo {
    
    __weak YDRouter *router = [self sharedInstance];
    NSMutableString *finalURL = [NSMutableString new];
    
    NSString *url = userInfo[@":"];
    if ([url isKindOfClass:[NSString class]] && url.length > 0) {
        [finalURL appendString:url];
        
        NSMutableArray *params = [NSMutableArray new];
        NSString *paramRegex = @"[a-zA-Z_][a-zA-Z0-9_]{0,}";
        NSPredicate *paramPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", paramRegex];
        
        [userInfo enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if ([paramPredicate evaluateWithObject:key]) {
                if ([obj isKindOfClass:[NSString class]] && [obj length] > 0) {
                    [params addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
                } else if ([obj isKindOfClass:[NSNumber class]]) {
                    NSNumberFormatter *formater = [[NSNumberFormatter alloc] init];
                    NSString *str = [formater stringFromNumber:obj];
                    if (str && str.length > 0) {
                        [params addObject:[NSString stringWithFormat:@"%@=%@", key, str]];
                    }
                }
            }
        }];
        
        if (params.count > 0) {
            [finalURL appendString:@"?"];
            [finalURL appendString:[params componentsJoinedByString:@"&"]];
        }
    }
    
    vc.routerURL = finalURL;
    
    id navVC = nil;
    
    UIViewController *currentVC = [[router class] currentVC];
    navVC = currentVC ? (currentVC.navigationController ?: router.navVC) : router.navVC;
    
    [navVC pushViewController:vc animated:YES];
}

+ (void)setup {
    __weak YDRouter *router = [self sharedInstance];
    // 依据XLVCMap.plist添加界面调用到Router
    NSArray *vcMap = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"YDVCMap" ofType:@"plist"]];
    router.vcMap = vcMap;
    for (id map in router.vcMap) {
        NSString *scheme = [self jsonString:@"scheme" with:map];
        NSString *host = [self jsonString:@"host" with:map];
        NSString *hClass = [self jsonString:@"class" with:map];
        NSDictionary *paramsDict = [self jsonDict:@"params" with:map];
        NSString *sbname = [self jsonString:@"sbname" with:map];
        //NSLog(@"注册url=%@",host);
        [router registerURLPattern:[[scheme.lowercaseString stringByAppendingString:@"://"] stringByAppendingString:[host lowercaseString]] toHandler:^(NSDictionary *userInfo) {
            Class vcClass = NSClassFromString(hClass);
            id vc = nil;
            if (!sbname || [[sbname stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]) {
                vc = [vcClass new];
            }
            else{
                UIStoryboard * s_storyboard = [UIStoryboard storyboardWithName:sbname bundle:nil];
                vc = [s_storyboard instantiateViewControllerWithIdentifier:hClass];
            }
            
            [router parseAndSetParams:vc params:paramsDict dict:userInfo];
            void(^callback)(id result) = userInfo[@"^"];
            callback(vc);
        }];
    }
    
    [self customResigtWithRouter:router];
}

// 自动注册
+ (void)autoRegister:(YDURLHelper *)URL {
    __weak YDRouter *router = [self sharedInstance];
    NSString *scheme = URL.scheme;
    NSString *host = URL.host;
    NSDictionary *paramsDict = URL.params;
    NSString *hClass;
    NSString *sbname;
    if (paramsDict[@"class"]) {
        hClass = [paramsDict objectForKey:@"class"];
    }
    if (paramsDict[@"sbname"]) {
        sbname = paramsDict[@"sbname"];
    }
    //NSLog(@"注册url=%@",host);
    [router registerURLPattern:[[scheme.lowercaseString stringByAppendingString:@"://"] stringByAppendingString:[host lowercaseString]] toHandler:^(NSDictionary *userInfo) {
        Class vcClass = NSClassFromString(hClass);
        id vc = nil;
        if (!sbname || [[sbname stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]) {
            vc = [vcClass new];
        }
        else{
            UIStoryboard * s_storyboard = [UIStoryboard storyboardWithName:sbname bundle:nil];
            vc = [s_storyboard instantiateViewControllerWithIdentifier:hClass];
        }
        
        [router parseAndSetParams:vc params:paramsDict dict:userInfo];
        void(^callback)(id result) = userInfo[@"^"];
        callback(vc);
    }];
}

+ (void)openURL:(YDURLHelper *)URL {
    [[self class] openURL:URL withUserInfo:nil];
}

+ (void)openURL:(YDURLHelper *)URL withUserInfo:(NSDictionary *)userInfo {
    [[self class] openURL:URL withUserInfo:userInfo finish:NULL];
}

+ (void)openURL:(YDURLHelper *)URL withUserInfo:(NSDictionary *)userInfo finish:(void (^)(id result))finishHandler {
    NSString *url = [NSString stringWithFormat:@"%@://%@", [URL.scheme lowercaseString], [URL.host lowercaseString]];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:URL.params];
    [dict addEntriesFromDictionary:userInfo];
    if (finishHandler) {
        dict[@"^"] = finishHandler;
    }
    
    // 设置url
    dict[@":"] = url;
    
    if (![MGJRouter canOpenURL:url]) {
        [[self class] autoRegister:URL];
    }
    //NSLog(@"打开%@",url);
    [MGJRouter openURL:url withUserInfo:dict completion:finishHandler];
}

+ (void)openURLStr:(NSString *)urlStr {
    [YDRouter openURLStr:urlStr userInfo:nil finish:NULL];
}

+ (void)openURLStr:(NSString *)urlStr finish:(void (^)(id))finishHandler {
    [YDRouter openURLStr:urlStr userInfo:nil finish:finishHandler];
}

+ (void)openURLStr:(NSString *)urlStr userInfo:(NSDictionary *)userInfo {
    [YDRouter openURLStr:urlStr userInfo:userInfo finish:NULL];
}

+ (void)openURLStr:(NSString *)urlStr userInfo:(NSDictionary *)userInfo finish:(void (^)(id))finishHandler {
//    YDURLHelper *hyrUrl = [YDURLHelper URLWithString:urlStr];
    
    // 外部 URL Schemes
    // 支付宝支付
    // 自定义 URL 跳转页面
    [YDRouter handleCustomerURLStr:urlStr userInfo:userInfo finish:finishHandler];
}

// native
+ (void) handleCustomerURLStr:(NSString*) urlStr  userInfo:(NSDictionary *)userInfo finish:(void (^)(id result))finishHandler{
    // native
    YDURLHelper *hyrUrl = [YDURLHelper URLWithString:urlStr];
    [YDRouter openURL:hyrUrl withUserInfo:userInfo finish:finishHandler];
}

+ (NSString *)generateURLWithPattern:(NSString *)pattern parameters:(NSDictionary *)parameters {
    
    NSMutableString *finalURL = [NSMutableString new];
    
    NSString *url = pattern;
    if ([url isKindOfClass:[NSString class]] && url.length > 0) {
        [finalURL appendString:url];
        
        NSMutableArray *params = [NSMutableArray new];
        NSString *paramRegex = @"[a-zA-Z_][a-zA-Z0-9_]{0,}";
        NSPredicate *paramPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", paramRegex];
        
        [parameters enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if ([paramPredicate evaluateWithObject:key]) {
                if ([obj isKindOfClass:[NSString class]] && [obj length] > 0) {
                    [params addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
                } else if ([obj isKindOfClass:[NSNumber class]]) {
                    NSNumberFormatter *formater = [[NSNumberFormatter alloc] init];
                    NSString *str = [formater stringFromNumber:obj];
                    if (str && str.length > 0) {
                        [params addObject:[NSString stringWithFormat:@"%@=%@", key, str]];
                    }
                }
            }
        }];
        
        if (params.count > 0) {
            [finalURL appendString:@"?"];
            [finalURL appendString:[params componentsJoinedByString:@"&"]];
        }
    }
    
    return finalURL;
}


- (void)registerURLPattern:(NSString *)URLPattern toHandler:(void (^)(NSDictionary *userInfo))handler {
    if ([URLPattern rangeOfString:@"://"].location != NSNotFound) {
        [MGJRouter registerURLPattern:URLPattern toHandler:^(NSDictionary *routerParameters) {
            NSDictionary *d = routerParameters[@"MGJRouterParameterUserInfo"];
            if (d && [d isKindOfClass:[NSDictionary class]]) {
                handler(d);
            }
        }];
    }else {
        NSString *url = [[self.schemeUrl?:@"project".lowercaseString stringByAppendingString:@"://"] stringByAppendingString:[URLPattern lowercaseString]];
        //NSLog(@"注册%@",url);
        [MGJRouter registerURLPattern:url toHandler:^(NSDictionary *routerParameters) {
            NSDictionary *d = routerParameters[@"MGJRouterParameterUserInfo"];
            if (d && [d isKindOfClass:[NSDictionary class]]) {
                handler(d);
            }
        }];
    }
}

// 通过plist文件配置信息，对属性及关联对象赋值
- (void)parseAndSetParams:(id)obj params:(NSDictionary *)paramsDict dict:(NSDictionary *)userInfo {
//    NSDictionary *keyMapDictionary = [paramsDict copy];
    NSDictionary *valueMapDictionary = [userInfo copy];
    NSMutableDictionary *unmatchedKeyMapDictionary = [NSMutableDictionary dictionaryWithDictionary:valueMapDictionary];
    
    // 属性赋值
    Class baseClass = [obj class];
    Class superClass = baseClass;
    do {
        baseClass = superClass;
        unsigned int propertyCount;
        objc_property_t *properties = class_copyPropertyList(baseClass, &propertyCount);
        for (int i = 0; i < propertyCount; i++) {
            objc_property_t property = properties[i];
            
            //取属性名称
            NSString *propertyName = [NSString stringWithUTF8String:property_getName(property)];
            
            //key映射
            if (![valueMapDictionary.allKeys containsObject:propertyName]) {
                continue;
            }
            [unmatchedKeyMapDictionary removeObjectForKey:propertyName];
            
            NSString *key = propertyName;
            
            id value = valueMapDictionary[key];
            
            //如果value为空，则进入下一个循环
            if (!value) {
                continue;
            }
            
            NSString *attributeString = [NSString stringWithUTF8String:property_getAttributes(property)];
            NSString *typeString = [[attributeString componentsSeparatedByString:@","] objectAtIndex:0];
            
            //类名，非基础类型
            NSString *classNameString = [self getClassNameFromAttributeString:typeString];
            
            //基础类型
            if ([value isKindOfClass:[NSNumber class]]) {
                //当对应的属性为基础类型或者 NSNumber 时才处理
                if ([typeString isEqualToString:@"Td"] || [typeString isEqualToString:@"Ti"] || [typeString isEqualToString:@"Tf"] || [typeString isEqualToString:@"Tl"] || [typeString isEqualToString:@"Tc"] || [typeString isEqualToString:@"Ts"] || [typeString isEqualToString:@"TI"]|| [typeString isEqualToString:@"Tq"] || [typeString isEqualToString:@"TQ"] || [typeString isEqualToString:@"TB"] ||[classNameString isEqualToString:@"NSNumber"]) {
                    [self setObj:obj prama:propertyName value:value type:typeString];
                }
                else {
                    if ([classNameString isEqualToString:@"NSString"]) {
                        [self setObj:obj prama:propertyName value:[(NSNumber *)value stringValue] type:typeString];
                    }
                    else{
                        //NSLog(@"type error -- name:%@ attribute:%@ ", propertyName, typeString);
                    }
                }
            }
            //字符串
            else if ([value isKindOfClass:[NSString class]]) {
                if ([classNameString isEqualToString:@"NSString"]) {
                    [self setObj:obj prama:propertyName value:value type:typeString];
                }
                else if ([classNameString isEqualToString:@"NSMutableString"]) {
                    [self setObj:obj prama:propertyName value:[NSMutableString stringWithString:value] type:typeString];
                }
                //对应的属性为基础类型时，先转成 NSNumber
                else if ([typeString isEqualToString:@"Td"] || [typeString isEqualToString:@"Ti"] || [typeString isEqualToString:@"Tf"] || [typeString isEqualToString:@"Tl"] || [typeString isEqualToString:@"Tc"] || [typeString isEqualToString:@"Ts"] || [typeString isEqualToString:@"TI"]|| [typeString isEqualToString:@"Tq"] || [typeString isEqualToString:@"TQ"] || [typeString isEqualToString:@"TB"]) {
                    
                    NSNumberFormatter *formater = [[NSNumberFormatter alloc] init];
                    NSNumber *number = [formater numberFromString:value];
                    if (number) {
                        [self setObj:obj prama:propertyName value:number type:typeString];
                    }
                }
            }
            //字典
            else if ([value isKindOfClass:[NSDictionary class]]) {
                [self setObj:obj prama:propertyName value:value type:typeString];
            }
            //数组
            else if ([value isKindOfClass:[NSArray class]]) {
                [self setObj:obj prama:propertyName value:value type:typeString];
            }
            //自定义对象
            else if ([value isKindOfClass:[NSObject class]]) {
                [self setObj:obj prama:propertyName value:value type:typeString];
            }
            //空
            else if ([value isKindOfClass:[NSNull class]]) {
                continue;
            }
            //其它(Block等)
            else {
                [self setObj:obj prama:propertyName value:value type:typeString];
                continue;
            }
            
        }
        
        free(properties);
        superClass = class_getSuperclass(baseClass);
    } while (superClass != baseClass && superClass != [NSObject class]);
    
    // 关联对象赋值
    [unmatchedKeyMapDictionary enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull classKey, BOOL * _Nonnull stop) {
        id value = valueMapDictionary[key];
        [self setObj:obj associated:key value:value];
    }];
    
    if (valueMapDictionary) {
        [self setObj:obj associated:@"handlerUserInfo" value:valueMapDictionary];
    }

}

- (NSString *)getClassNameFromAttributeString:(NSString *)attributeString
{
    NSString *className = nil;
    
    NSScanner *scanner = [NSScanner scannerWithString: attributeString];
    
    [scanner scanUpToString:@"T" intoString: nil];
    [scanner scanString:@"T" intoString:nil];
    
    if ([scanner scanString:@"@\"" intoString: &className]) {
        
        [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"]
                                intoString:&className];
    }
    
    return className;
}

- (void)setObj:(id)obj prama:(NSString *)name value:(id)v type:(NSString *)type{
    if (!name || name.length == 0) {
        return;
    }
    NSString *selName = [NSString stringWithFormat:@"set%@%@:", [[name substringToIndex:1] uppercaseString], [name substringFromIndex:1]];
    SEL sel = NSSelectorFromString(selName);
    if ([obj respondsToSelector:sel]) {
        IMP imp = [obj methodForSelector:sel];
        if ([type isEqualToString:@"Td"]) {
            void (*func)(id, SEL, double) = (void *)imp;
            func(obj, sel, [v doubleValue]);
        } else if ([type isEqualToString:@"Ti"]) {
            void (*func)(id, SEL, int) = (void *)imp;
            func(obj, sel, [v intValue]);
        } else if ([type isEqualToString:@"Tf"]) {
            void (*func)(id, SEL, float) = (void *)imp;
            func(obj, sel, [v floatValue]);
        } else if ([type isEqualToString:@"Tl"]) {
            void (*func)(id, SEL, long) = (void *)imp;
            func(obj, sel, [v longValue]);
        } else if ([type isEqualToString:@"Tc"]) {
            void (*func)(id, SEL, char) = (void *)imp;
            func(obj, sel, [v charValue]);
        } else if ([type isEqualToString:@"Ts"]) {
            void (*func)(id, SEL, short) = (void *)imp;
            func(obj, sel, [v shortValue]);
        } else if ([type isEqualToString:@"TI"]) {
            void (*func)(id, SEL, unsigned int) = (void *)imp;
            func(obj, sel, [v unsignedIntValue]);
        } else if ([type isEqualToString:@"Tq"]) {
            void (*func)(id, SEL, long long) = (void *)imp;
            func(obj, sel, [v longLongValue]);
        } else if ([type isEqualToString:@"TQ"]) {
            void (*func)(id, SEL, unsigned long long) = (void *)imp;
            func(obj, sel, [v unsignedLongLongValue]);
        } else if ([type isEqualToString:@"TB"]) {
            void (*func)(id, SEL, BOOL) = (void *)imp;
            func(obj, sel, [v boolValue]);
        } else {
            void (*func)(id, SEL, id) = (void *)imp;
            func(obj, sel, v);
        }
    }
}

- (void)setObj:(id)obj associated:(NSString *)name value:(id)v {
    if (!name || name.length == 0) {
        return;
    }
    NSString *selName = [NSString stringWithFormat:@"set%@%@:", [[name substringToIndex:1] uppercaseString], [name substringFromIndex:1]];
    SEL sel = NSSelectorFromString(selName);
    if ([obj respondsToSelector:sel]) {
        SuppressPerformSelectorLeakWarning({
            [obj performSelector:sel withObject:v];
        });
    }
}

+ (NSString *)jsonString:(NSString *)key with:(NSDictionary *)dict
{
    id object = [dict objectForKey:key];
    if ([object isKindOfClass:[NSString class]])
    {
        return object;
    }
    else if([object isKindOfClass:[NSNumber class]])
    {
        return [object stringValue];
    }
    return nil;
}

+ (NSDictionary *)jsonDict:(NSString *)key with:(NSDictionary *)dict
{
    id object = [dict objectForKey:key];
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}


+ (void)backToServiceIndexPage:(YDRouter *)router{
    
}


// 此方法由主工程分类实现
+ (void)customResigtWithRouter:(YDRouter *)router{
    
}

@end
