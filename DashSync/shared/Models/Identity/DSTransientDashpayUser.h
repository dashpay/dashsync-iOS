//
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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
#import "dash_spv_apple_bindings.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSTransientDashpayUser : NSObject

@property (nullable, nonatomic, readonly) NSString *displayName;
@property (nullable, nonatomic, readonly) NSString *avatarPath;
@property (nullable, nonatomic, readonly) NSData *avatarFingerprint;
@property (nullable, nonatomic, readonly) NSData *avatarHash;
@property (nullable, nonatomic, readonly) NSString *publicMessage;
@property (nonatomic, readonly) int32_t revision;
@property (nonatomic, readonly) NSData *documentIdentifier;
@property (nonatomic, readonly) NSTimeInterval createdAt;
@property (nonatomic, readonly) NSTimeInterval updatedAt;

- (instancetype)initWithDashpayProfileDocument:(NSDictionary *)profileDocument;
- (instancetype)initWithDocument:(DDocument *)document;

@end

NS_ASSUME_NONNULL_END
