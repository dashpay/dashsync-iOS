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
#import "BigIntTypes.h"
#import "DPTypes.h"

@class DSKey,DSBlockchainIdentity;

NS_ASSUME_NONNULL_BEGIN

@interface DSContactRequest : NSObject

@property(nonatomic,readonly) UInt256 recipientBlockchainIdentityUniqueId;
@property(nonatomic,readonly) UInt256 senderBlockchainIdentityUniqueId;
@property(nonatomic,readonly) uint32_t recipientKeyIndex;
@property(nonatomic,readonly) uint32_t senderKeyIndex;
@property(nonatomic,readonly) uint32_t accountReference;
@property(nonatomic,readonly) NSData * encryptedAccountLabel;

@property(nonatomic,readonly) NSTimeInterval createdAt;

@property(nonatomic,readonly) NSData * encryptedPublicKeyData;

+(instancetype)contactRequestFromDictionary:(DSStringValueDictionary*)serverDictionary onBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity;

-(NSData*)decryptedPublicKeyDataWithKey:(DSKey*)key;

@end

NS_ASSUME_NONNULL_END
