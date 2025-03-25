//  
//  Created by Vladimir Pirogov
//  Copyright © 2025 Dash Core Group. All rights reserved.
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

typedef NS_ENUM(NSUInteger, DSGapLimitFundsDirection) {
    DSGapLimitFundsDirection_Internal = 1,
    DSGapLimitFundsDirection_External = 2,
    DSGapLimitFundsDirection_Both = DSGapLimitFundsDirection_Internal | DSGapLimitFundsDirection_External,
};


@interface DSGapLimit : NSObject
@property (readwrite, nonatomic, assign) uintptr_t gapLimit;
+ (instancetype)withLimit:(uintptr_t)limit;
+ (instancetype)single;
@end

@interface DSGapLimitFunds : DSGapLimit
@property (readwrite, nonatomic) DSGapLimitFundsDirection direction;
+ (instancetype)withLimit:(uintptr_t)limit direction:(DSGapLimitFundsDirection)direction;
+ (instancetype)internalSingle;
+ (instancetype)externalSingle;
+ (instancetype)internal:(uintptr_t)limit;
+ (instancetype)external:(uintptr_t)limit;
@end

@interface DSGapLimitIdentity : DSGapLimit
@property (readwrite, nonatomic, assign) uint32_t identityID;
+ (instancetype)withLimit:(uintptr_t)limit identityID:(uint32_t)identityID;
@end


NS_ASSUME_NONNULL_END
