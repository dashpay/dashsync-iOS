//
//  Created by Andrew Podkovyrin
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
#import "DSKeyManager.h"
#import "DPBaseObject.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const DPContractDidUpdateNotification;
FOUNDATION_EXPORT NSString *const DSContractUpdateNotificationKey;

@class DSChain, DSIdentity;

typedef NS_ENUM(NSUInteger, DPContractState)
{
    DPContractState_Unknown,
    DPContractState_NotRegistered,
    DPContractState_Registered,
    DPContractState_Registering,
};

@interface DPContract : DPBaseObject

@property (readonly, copy, nonatomic) NSString *localContractIdentifier;
@property (readonly, nonatomic) UInt256 registeredIdentityUniqueID;
@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, nonatomic) UInt256 contractId;
@property (readonly, copy, nonatomic) NSString *base58ContractId;
@property (readonly, nonatomic) UInt256 entropy;
@property (readonly, copy, nonatomic) NSString *base58OwnerId;
@property (readonly, copy, nonatomic) NSString *statusString;
@property (readonly, nonatomic) DPContractState contractState;
@property (readonly, copy, nonatomic) NSString *jsonSchemaId;
@property (readonly, copy, nonatomic) DSStringValueDictionary *objectDictionary;

@property (assign, nonatomic) NSInteger version;
@property (copy, nonatomic) NSString *jsonMetaSchema;
@property (readonly, nonatomic) dpp_data_contract_DataContract *raw_contract;
@property (readonly, nonatomic) DDocumentTypes *documents;
//@property (copy, nonatomic) NSDictionary<NSString *, DSStringValueDictionary *> *documents;
//@property (copy, nonatomic) NSDictionary<NSString *, DSStringValueDictionary *> *definitions;

- (instancetype)initWithLocalContractIdentifier:(NSString *)contractID
//                                      documents:(NSDictionary<NSString *, DSStringValueDictionary *> *)documents
                                      raw_contract:(dpp_data_contract_DataContract *)raw_contract
                                        onChain:(DSChain *)chain;

- (instancetype)init NS_UNAVAILABLE;

- (BOOL)isDocumentDefinedForType:(NSString *)type;
//- (void)setDocumentSchema:(DSStringValueDictionary *)schema forType:(NSString *)type;
//- (nullable DSStringValueDictionary *)documentSchemaForType:(NSString *)type;
//- (nullable NSDictionary<NSString *, NSString *> *)documentSchemaRefForType:(NSString *)type;

- (void)registerCreator:(DSIdentity *)identity;
- (void)unregisterCreator;

+ (DPContract *)localDashpayContractForChain:(DSChain *)chain;
+ (DPContract *)localDPNSContractForChain:(DSChain *)chain;
//+ (DPContract *)localDashThumbnailContractForChain:(DSChain *)chain;


- (UInt256)contractIdIfRegisteredByIdentity:(DSIdentity *)identity;

@end

NS_ASSUME_NONNULL_END
