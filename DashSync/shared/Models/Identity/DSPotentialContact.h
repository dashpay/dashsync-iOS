//
//  Created by Sam Westrich
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "BigIntTypes.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSDashpayUserEntity, DSKey;

@interface DSPotentialContact : NSObject

@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *avatarPath;
@property (nonatomic, copy) NSString *publicMessage;
@property (nonatomic, assign) UInt256 associatedBlockchainIdentityUniqueId;

- (instancetype)initWithUsername:(NSString *)username;

- (instancetype)initWithUsername:(NSString *)username avatarPath:(NSString *)avatarPath publicMessage:(NSString *)publicMessage;

- (instancetype)initWithDashpayUser:(DSDashpayUserEntity *)contactEntity;

- (void)addPublicKey:(DSKey *)key atIndex:(NSUInteger)index;

- (DSKey *)publicKeyAtIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
