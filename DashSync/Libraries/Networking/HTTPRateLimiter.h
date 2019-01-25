//
//  Created by Andrew Podkovyrin
//  Copyright © 2018-2019 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HTTPRateLimiter : NSObject

@property (readonly, assign, nonatomic) NSTimeInterval window;
@property (readonly, assign, nonatomic) NSUInteger delayAfter;
@property (readonly, assign, nonatomic) NSTimeInterval delay;
@property (readonly, assign, nonatomic) NSUInteger maximum;

- (instancetype)initWithWindow:(NSTimeInterval)window
                    delayAfter:(NSUInteger)delayAfter
                         delay:(NSTimeInterval)delay
                       maximum:(NSUInteger)maximum NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (NSTimeInterval)earliestTimeUntilRequestCanBeExecuted;
- (void)executedRequest;

@end

NS_ASSUME_NONNULL_END
