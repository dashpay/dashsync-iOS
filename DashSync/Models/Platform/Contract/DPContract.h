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

#import "DPBaseObject.h"
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString* const DPContractDidUpdateNotification;
FOUNDATION_EXPORT NSString* const DSContractUpdateNotificationKey;

@class DSChain,DSContractTransition,DSBlockchainIdentity;

typedef NS_ENUM(NSUInteger, DPContractState) {
    DPContractState_Unknown,
    DPContractState_NotRegistered,
    DPContractState_Registered,
    DPContractState_Registering,
};

@interface DPContract : DPBaseObject

@property (readonly, copy, nonatomic) NSString *localContractIdentifier;
@property (readonly, nonatomic) UInt256 registeredBlockchainIdentityUniqueID;
@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic) NSString *base58ContractID;
@property (readonly, copy, nonatomic) NSString *statusString;
@property (readonly, nonatomic) DPContractState contractState;
@property (readonly, copy, nonatomic) NSString *jsonSchemaId;
@property (readonly, copy, nonatomic) DSStringValueDictionary *objectDictionary;

@property (readonly, nonatomic) DSChain *chain;

@property (assign, nonatomic) NSInteger version;
@property (copy, nonatomic) NSString *jsonMetaSchema;
@property (copy, nonatomic) NSDictionary<NSString *, DSStringValueDictionary *> *documents;
@property (copy, nonatomic) NSDictionary<NSString *, DSStringValueDictionary *> *definitions;

- (instancetype)initWithLocalContractIdentifier:(NSString *)contractID
                   documents:(NSDictionary<NSString *, DSStringValueDictionary *> *)documents onChain:(DSChain*)chain;

- (instancetype)init NS_UNAVAILABLE;

- (BOOL)isDocumentDefinedForType:(NSString *)type;
- (void)setDocumentSchema:(DSStringValueDictionary *)schema forType:(NSString *)type;
- (nullable DSStringValueDictionary *)documentSchemaForType:(NSString *)type;

- (nullable NSDictionary<NSString *, NSString *> *)documentSchemaRefForType:(NSString *)type;

- (void)registerCreator:(DSBlockchainIdentity*)blockchainIdentity inContext:(NSManagedObjectContext*)context;

+ (DPContract *)localDashpayContractForChain:(DSChain*)chain;
+ (DPContract *)localDPNSContractForChain:(DSChain*)chain;

@end

NS_ASSUME_NONNULL_END
