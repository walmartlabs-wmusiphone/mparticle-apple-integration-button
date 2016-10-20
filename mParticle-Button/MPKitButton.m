//
//  MPKitButton.m
//
//  Copyright 2016 Button, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "MPKitButton.h"
#include <sys/types.h>
#include <sys/sysctl.h>

@import AdSupport.ASIdentifierManager;

static NSString * const BTNMPKitVersion = @"1.0.0";

static NSString * const BTNReferrerTokenDefaultsKey   = @"com.usebutton.referrer";
static NSString * const BTNLinkFetchStatusDefaultsKey = @"com.usebutton.link.fetched";

NSString * const BTNDeferredDeepLinkURLKey = @"BTNDeferredDeepLinkURLKey";

#pragma mark - MPIButton
@interface MPIButton()

@property (nonatomic, copy, nullable) NSString *referrerToken;
@property (nonatomic, strong) NSUserDefaults *userDefaults;

@end

@implementation MPIButton

- (instancetype)init {
    self = [super init];
    _userDefaults = [NSUserDefaults standardUserDefaults];
    return self;
}

- (NSString *)referrerToken {
    return [self.userDefaults objectForKey:BTNReferrerTokenDefaultsKey];
}


- (void)setReferrerToken:(NSString *)buttonReferrerToken {
    if (buttonReferrerToken) {
        [self.userDefaults setObject:buttonReferrerToken forKey:BTNReferrerTokenDefaultsKey];
    }
    else {
        [self.userDefaults removeObjectForKey:BTNReferrerTokenDefaultsKey];
    }
}

@end


#pragma mark - MPKitButton
@interface MPKitButton ()

@property (nonatomic, strong, nonnull) MPIButton *button;
@property (nonatomic, copy)   NSString *applicationId;
@property (nonatomic, strong) NSURLSession *session;

// Dependencies
@property (nonatomic, strong) NSFileManager  *fileManager;
@property (nonatomic, strong) NSUserDefaults *userDefaults;
@property (nonatomic, strong) UIDevice *device;
@property (nonatomic, strong) UIScreen *screen;
@property (nonatomic, strong) NSLocale *locale;
@property (nonatomic, strong) NSBundle *mainBundle;
@property (nonatomic, strong) ASIdentifierManager *IFAManager;

@end


@implementation MPKitButton

+ (NSNumber *)kitCode {
    return @1022;
}


+ (void)load {
    MPKitRegister *kitRegister = [[MPKitRegister alloc] initWithName:@"Button"
                                                           className:NSStringFromClass(self)
                                                    startImmediately:YES];
    [MParticle registerExtension:kitRegister];
}


#pragma mark MPKitInstanceProtocol methods

- (nonnull instancetype)initWithConfiguration:(nonnull NSDictionary *)configuration startImmediately:(BOOL)startImmediately {
    self = [super init];

    _applicationId = [configuration[@"application_id"] copy];
    if (!self || !_applicationId) {
        return nil;
    }

    _fileManager  = [NSFileManager defaultManager];
    _userDefaults = [NSUserDefaults standardUserDefaults];
    _device       = [UIDevice currentDevice];
    _screen       = [UIScreen mainScreen];
    _locale       = [NSLocale currentLocale];
    _mainBundle   = [NSBundle mainBundle];
    _IFAManager   = [ASIdentifierManager sharedManager];

    _configuration = configuration;
    _started       = startImmediately;

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *userInfo = @{ mParticleKitInstanceKey: [[self class] kitCode] };

        [[NSNotificationCenter defaultCenter] postNotificationName:mParticleKitDidBecomeActiveNotification
                                                            object:nil
                                                          userInfo:userInfo];
    });

    return self;
}

- (id)providerKitInstance {
    return [self started] ? self.button : nil;
}

- (nonnull MPKitExecStatus *)checkForDeferredDeepLinkWithCompletionHandler:(void(^ _Nonnull)(NSDictionary<NSString *, NSString *> * _Nullable linkInfo, NSError * _Nullable error))completionHandler {

    BOOL isNewInstall = [self isNewInstall];
    BOOL didFetchLink = [self.userDefaults boolForKey:BTNLinkFetchStatusDefaultsKey];

    if (!isNewInstall || didFetchLink || !self.applicationId.length) {
        return [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode]
                                             returnCode:MPKitReturnCodeRequirementsNotMet];
    }

    [self.userDefaults setBool:YES forKey:BTNLinkFetchStatusDefaultsKey];

    if (!self.session) {
        self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    }

    NSURL *url = [NSURL URLWithString:@"https://api.usebutton.com/v1/web/deferred-deeplink"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request addValue:[self userAgentString] forHTTPHeaderField:@"User-Agent"];

    NSMutableDictionary *signals = [NSMutableDictionary dictionary];
    signals[@"source"]     = @"mparticle";
    signals[@"os"]         = @"ios";
    signals[@"os_version"] = self.device.systemVersion ?: @"";
    signals[@"device"]     = self.device.model ?: @"";
    signals[@"country"]    = [self.locale objectForKey:NSLocaleCountryCode] ?: @"";
    signals[@"language"]   = [self preferredLanguage] ?: @"";
    signals[@"screen"]     = [NSString stringWithFormat:@"%@x%@",
                              @(self.screen.bounds.size.width * self.screen.scale),
                              @(self.screen.bounds.size.height * self.screen.scale)];

    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"application_id"] = self.applicationId ?: @"";
    params[@"ifa"]            = self.IFAManager.advertisingIdentifier.UUIDString ?: @"";
    params[@"signals"]        = signals;

    NSError *error = nil;
    NSData *requestData = nil;

    @try {
        requestData = [NSJSONSerialization dataWithJSONObject:[params copy] options:0 error:&error];
    } @catch (NSException *exception) {
    }

    if (!requestData && error) {
        return [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode]
                                             returnCode:MPKitReturnCodeFail];
    }

    request.HTTPBody = requestData;
    [[self.session dataTaskWithRequest:request completionHandler:
      ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

          NSDictionary *linkInfo = nil;
          if (!error) {
              id responseObject    = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
              BOOL isValidResponse = [responseObject isKindOfClass:[NSDictionary class]] &&
                                     [responseObject[@"meta"] isKindOfClass:[NSDictionary class]] &&
                                     [responseObject[@"meta"][@"status"] isEqualToString:@"ok"] &&
                                     [responseObject[@"object"] isKindOfClass:[NSDictionary class]];

              if (isValidResponse) {
                  NSDictionary *object = responseObject[@"object"];
                  if ([object[@"attribution"] isKindOfClass:[NSDictionary class]]) {
                      NSString *referrer = object[@"attribution"][@"btn_ref"];

                      if (referrer.length) {
                          self.button.referrerToken = referrer;
                      }
                  }

                  if ([object[@"action"] length]) {
                      linkInfo = @{ BTNDeferredDeepLinkURLKey: object[@"action"] };
                  }
              }
          }

          if (completionHandler) {
              dispatch_async(dispatch_get_main_queue(), ^{
                  completionHandler(linkInfo, nil);
              });
          }
    }] resume];

    return [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode]
                                         returnCode:MPKitReturnCodeSuccess];
}


- (nonnull MPKitExecStatus *)openURL:(nonnull NSURL *)url options:(nullable NSDictionary<NSString *, id> *)options {
    [self applyAttributionFromURL:url];
    return [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode]
                                         returnCode:MPKitReturnCodeSuccess];
}


- (nonnull MPKitExecStatus *)openURL:(nonnull NSURL *)url sourceApplication:(nullable NSString *)sourceApplication annotation:(nullable id)annotation {
    [self applyAttributionFromURL:url];
    return [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode]
                                         returnCode:MPKitReturnCodeSuccess];
}


- (nonnull MPKitExecStatus *)continueUserActivity:(nonnull NSUserActivity *)userActivity restorationHandler:(void(^ _Nonnull)(NSArray * _Nullable restorableObjects))restorationHandler {
    [self applyAttributionFromURL:userActivity.webpageURL];
    return [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode]
                                         returnCode:MPKitReturnCodeSuccess];
}


#pragma mark - Button specific

- (MPIButton *)button {
    if (!_button) {
        _button = [[MPIButton alloc] init];
    }

    return _button;
}

- (BOOL)isNewInstall {
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSDictionary *attributes = [self.fileManager attributesOfItemAtPath:documentsPath error:nil];
    NSDate *twelveHoursAgo = [[NSCalendar currentCalendar] dateByAddingUnit:NSCalendarUnitHour
                                                                      value:-12
                                                                     toDate:[NSDate date]
                                                                    options:0];

    return [[attributes fileCreationDate] compare:twelveHoursAgo] == NSOrderedDescending;
}


- (void)applyAttributionFromURL:(NSURL *)url {
    Class queryItemClass = NSClassFromString(@"NSURLQueryItem");
    if (queryItemClass) {
        NSURLComponents *urlComponents = [NSURLComponents componentsWithString:url.absoluteString];

        for (NSURLQueryItem *item in urlComponents.queryItems) {

            if ([item.name isEqualToString:@"btn_ref"] && item.value.length) {
                self.button.referrerToken = item.value;
                break;
            }
        }
    }
}


- (NSString *)userAgentString {
    return [NSString stringWithFormat:@"%@/%@-%@ (iOS %@; %@; %@/%@; Scale/%0.1f; %@-%@)",
            @"com.usebutton.mparticle",
            [MParticle sharedInstance].version,
            BTNMPKitVersion,
            self.device.systemVersion,
            [self platformString],
            self.mainBundle.infoDictionary[(__bridge NSString *)kCFBundleIdentifierKey],
            self.mainBundle.infoDictionary[(__bridge NSString *)kCFBundleVersionKey],
            self.screen.scale,
            [self preferredLanguage],
            [self.locale objectForKey:NSLocaleCountryCode]];
}


- (NSString *)preferredLanguage {
    return [[[self.locale class] preferredLanguages].firstObject
            componentsSeparatedByString:@"-"].firstObject ?: @"en";
}


- (NSString *)platformString {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = @(machine);
    free(machine);
    return platform;
}

@end
