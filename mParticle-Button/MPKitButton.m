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

static NSString * const BTNReferrerTokenDefaultsKey = @"com.usebutton.referrer";

@interface MPKitButton ()

@property (nonatomic, strong) NSFileManager  *fileManager;
@property (nonatomic, strong) NSUserDefaults *userDefaults;

@property (nonatomic, copy, readwrite) NSString *buttonReferrerToken;

@end

@implementation MPKitButton

+ (NSNumber *)kitCode {
    return @1022;
}

+ (void)load {
    @autoreleasepool {
        MPKitRegister *kitRegister = [[MPKitRegister alloc] initWithName:@"Button" className:@"MPKitButton" startImmediately:YES];
        [MParticle registerExtension:kitRegister];
    }
}

#pragma mark MPKitInstanceProtocol methods

- (nonnull instancetype)initWithConfiguration:(nonnull NSDictionary *)configuration startImmediately:(BOOL)startImmediately {
    self = [super init];

// TODO: Why is this in the example if it's never present?
//
//    NSString *appKey = configuration[@"appKey"];
//    NSString *appSecret = configuration[@"appSecret"];
//    if (!self || !appKey || !appSecret) {
//        return nil;
//    }

    _fileManager  = [NSFileManager defaultManager];
    _userDefaults = [NSUserDefaults standardUserDefaults];

    _configuration = configuration;
    _started = startImmediately;

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *userInfo = @{ mParticleKitInstanceKey:[[self class] kitCode] };

        [[NSNotificationCenter defaultCenter] postNotificationName:mParticleKitDidBecomeActiveNotification
                                                            object:nil
                                                          userInfo:userInfo];
    });

    return self;
}

- (id)providerKitInstance {
    return self;
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
