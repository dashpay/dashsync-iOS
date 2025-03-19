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

@interface DSGapLimit : NSObject
@property (nonatomic, readwrite) uintptr_t gapLimit;
+ (instancetype)initWithLimit:(uintptr_t)limit;
@end

@interface DSGapLimitInternal : DSGapLimit
@property (nonatomic, readwrite) BOOL internal;
+ (instancetype)initWithLimit:(uintptr_t)limit internal:(BOOL)internal;
@end

@interface DSGapLimitIdentity : DSGapLimit
@property (nonatomic, readwrite) uint32_t identityID;
+ (instancetype)initWithLimit:(uintptr_t)limit identityID:(uint32_t)identityID;
@end


NS_ASSUME_NONNULL_END
