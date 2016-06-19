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
    NSString *appKey = configuration[@"appKey"];
    NSString *appSecret = configuration[@"appSecret"];
    if (!self || !appKey || !appSecret) {
        return nil;
    }

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
@end
