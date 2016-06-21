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
@import AdSupport.ASIdentifierManager;

static NSString * const BTNReferrerTokenDefaultsKey   = @"com.usebutton.referrer";
static NSString * const BTNLinkFetchStatusDefaultsKey = @"com.usebutton.link.fetched";

NSString * const BTNDeferredDeepLinkURLKey = @"BTNDeferredDeepLinkURLKey";

@interface MPKitButton ()

@property (nonatomic, copy)   NSString       *applicationId;
@property (nonatomic, strong) NSURLSession   *session;

@property (nonatomic, copy, readwrite) NSString *buttonReferrerToken;

// Dependencies
@property (nonatomic, strong) NSFileManager  *fileManager;
@property (nonatomic, strong) NSUserDefaults *userDefaults;
@property (nonatomic, strong) UIDevice *device;
@property (nonatomic, strong) UIScreen *screen;
@property (nonatomic, strong) NSLocale *locale;
@property (nonatomic, strong) ASIdentifierManager *IFAManager;

@end

@implementation MPKitButton

+ (NSNumber *)kitCode {
    return @1022;
}

+ (void)load {
    @autoreleasepool {
        MPKitRegister *kitRegister = [[MPKitRegister alloc] initWithName:@"Button"
                                                               className:NSStringFromClass(self)
                                                        startImmediately:YES];
        [MParticle registerExtension:kitRegister];
    }
}

#pragma mark MPKitInstanceProtocol methods

- (id)providerKitInstance {
    return self;
}

- (nonnull instancetype)initWithConfiguration:(nonnull NSDictionary *)configuration startImmediately:(BOOL)startImmediately {
    self = [super init];

    _fileManager  = [NSFileManager defaultManager];
    _userDefaults = [NSUserDefaults standardUserDefaults];
    _device       = [UIDevice currentDevice];
    _screen       = [UIScreen mainScreen];
    _locale       = [NSLocale currentLocale];
    _IFAManager   = [ASIdentifierManager sharedManager];

    _configuration = configuration;
    _started       = startImmediately;
    _applicationId = [configuration[@"application_id"] copy];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *userInfo = @{ mParticleKitInstanceKey:[[self class] kitCode] };

        [[NSNotificationCenter defaultCenter] postNotificationName:mParticleKitDidBecomeActiveNotification
                                                            object:nil
                                                          userInfo:userInfo];
    });

    return self;
}

- (nonnull MPKitExecStatus *)checkForDeferredDeepLinkWithCompletionHandler:(void(^ _Nonnull)(NSDictionary<NSString *, NSString *> * _Nullable linkInfo, NSError * _Nullable error))completionHandler {

    BOOL isNewInstall = [self isNewInstall];
    BOOL didFetchLink = [self.userDefaults boolForKey:BTNLinkFetchStatusDefaultsKey];

    if (!isNewInstall || didFetchLink) {
        return [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode]
                                             returnCode:MPKitReturnCodeRequirementsNotMet];
    }

    [self.userDefaults setBool:YES forKey:BTNLinkFetchStatusDefaultsKey];

    if (!self.session) {
        self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    }

    NSURL *url = [NSURL URLWithString:@"https://api.usebutton.com/v1/web/deferred-deeplink"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"applicationi/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];

    NSMutableDictionary *signals = [NSMutableDictionary dictionary];
    signals[@"source"]     = @"mparticle";
    signals[@"os"]         = [self.device.systemName lowercaseString];
    signals[@"os_version"] = self.device.systemVersion;
    signals[@"device"]     = self.device.model;
    signals[@"country"]    = [self.locale objectForKey:NSLocaleCountryCode];
    signals[@"language"]   = [[[self.locale class] preferredLanguages].firstObject
                              componentsSeparatedByString:@"-"].firstObject ?: @"en";
    signals[@"screen"]     = [NSString stringWithFormat:@"%@x%@",
                              @(self.screen.bounds.size.width * self.screen.scale),
                              @(self.screen.bounds.size.height * self.screen.scale)];

    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"application_id"] = self.applicationId ?: @"";
    params[@"ifa"]            = self.IFAManager.advertisingIdentifier.UUIDString;
    params[@"signals"]        = signals;

    NSError *error;
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:[params copy] options:0 error:&error];
    if (!requestData && error) {
        return [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode]
                                             returnCode:MPKitReturnCodeFail];
    }

    request.HTTPBody = requestData;
    [[self.session dataTaskWithRequest:request completionHandler:
      ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

          NSDictionary *linkInfo;
          if (!error) {
              id responseObject    = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
              BOOL isValidResponse = [responseObject isKindOfClass:[NSDictionary class]] &&
                                     [responseObject[@"meta"] isKindOfClass:[NSDictionary class]] &&
                                     [responseObject[@"meta"][@"status"] isEqualToString:@"ok"] &&
                                     [responseObject[@"object"] isKindOfClass:[NSDictionary class]];

              NSDictionary *object = responseObject[@"object"];
              if ([object[@"attribution"] isKindOfClass:[NSDictionary class]]) {
                  NSString *referrer = object[@"attribution"][@"btn_ref"];
                  self.buttonReferrerToken = referrer.length ? referrer : self.buttonReferrerToken;
              }

              if ([object[@"action"] length]) {
                  linkInfo = @{ BTNDeferredDeepLinkURLKey: object[@"action"] };
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


#pragma mark - Button

- (BOOL)isNewInstall {
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSDictionary *attributes = [self.fileManager attributesOfItemAtPath:documentsPath error:nil];
    NSDate *twelveHoursAgo = [[NSCalendar currentCalendar] dateByAddingUnit:NSCalendarUnitHour
                                                                      value:-12
                                                                     toDate:[NSDate date]
                                                                    options:0];
    
    return [[attributes fileCreationDate] compare:twelveHoursAgo] == NSOrderedDescending;
}

- (NSString *)buttonReferrerToken {
    return [self.userDefaults objectForKey:BTNReferrerTokenDefaultsKey];
}

- (void)setButtonReferrerToken:(NSString *)buttonReferrerToken {
    if (buttonReferrerToken) {
        [self.userDefaults setObject:buttonReferrerToken forKey:BTNReferrerTokenDefaultsKey];
    }
    else {
        [self.userDefaults removeObjectForKey:BTNReferrerTokenDefaultsKey];
    }
}

@end
