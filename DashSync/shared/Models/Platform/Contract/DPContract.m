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

#import "DPContract+Protected.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSChain+Params.h"
#import "DSContractEntity+CoreDataClass.h"
#import "DSDashPlatform.h"
#import "DSWallet.h"
//#import "NSData+DSCborDecoding.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"
#import "NSError+Dash.h"

NS_ASSUME_NONNULL_BEGIN

//static NSInteger const DEFAULT_VERSION = 1;
//static NSString *const DEFAULT_SCHEMA = @"https://schema.dash.org/dpp-0-4-0/meta/data-contract";
//static NSString *const DPCONTRACT_SCHEMA_ID = @"contract";

@interface DPContract ()

@property (assign, nonatomic) dpp_data_contract_DataContract *raw_contract;
//@property (strong, nonatomic) NSMutableDictionary<NSString *, DSStringValueDictionary *> *mutableDocuments;
@property (copy, nonatomic, null_resettable) NSString *localContractIdentifier;
@property (assign, nonatomic) UInt256 contractId;
@property (assign, nonatomic) UInt256 registeredIdentityUniqueID;
@property (assign, nonatomic) UInt256 entropy;

@end

@implementation DPContract

@synthesize chain = _chain;

#pragma mark - Init

- (void)dealloc {
    if (self.raw_contract) {
        dpp_data_contract_DataContract_destroy(self.raw_contract);
    }
}

- (instancetype)initWithLocalContractIdentifier:(NSString *)localContractIdentifier
                                   raw_contract:(dpp_data_contract_DataContract *)raw_contract
//                                      documents:(NSDictionary<NSString *, DSStringValueDictionary *> *)documents
                                        onChain:(DSChain *)chain {
    NSParameterAssert(localContractIdentifier);
    NSParameterAssert(raw_contract);

    if (!(self = [super init])) return nil;
//    _version = DEFAULT_VERSION;
    _localContractIdentifier = localContractIdentifier;
//    _jsonMetaSchema = DEFAULT_SCHEMA;
    _raw_contract = raw_contract;
//    _mutableDocuments = [documents mutableCopy];
//    _definitions = @{};
    _chain = chain;

    //        [self.chain.chainManagedObjectContext performBlockAndWait:^{
    //            DSContractEntity * entity = [self contractEntityInContext:self.chain.chainManagedObjectContext];
    //            if (entity) {
    //                self.registeredBlockchainIdentityUniqueID = entity.registeredBlockchainIdentityUniqueID.UInt256;
    //                _contractState = entity.state;
    //            }
    //        }];
    return self;
}


#pragma mark - Contract Info

- (UInt256)contractId {
    if (uint256_is_zero(_contractId)) {
        NSAssert(uint256_is_not_zero(self.registeredIdentityUniqueID), @"Registered Identity needs to be set");
        NSAssert(uint256_is_not_zero(self.entropy), @"Entropy needs to be set");
        NSMutableData *mData = [NSMutableData data];
        [mData appendUInt256:self.registeredIdentityUniqueID];
        [mData appendUInt256:self.entropy];
        _contractId = [mData SHA256_2];
    }
    return _contractId;
}

- (UInt256)contractIdIfRegisteredByIdentity:(DSIdentity *)identity {
    NSMutableData *mData = [NSMutableData data];
    [mData appendUInt256:identity.uniqueID];
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath identitiesECDSAKeysDerivationPathForWallet:identity.wallet];
    Result_ok_Vec_u8_err_dash_spv_platform_error_Error *result = dash_spv_platform_contract_manager_ContractsManager_contract_serialized_hash(self.chain.shareCore.contractsManager->obj, self.raw_contract);
    NSData *serializedHash = NSDataFromPtr(result->ok);
    Result_ok_Vec_u8_err_dash_spv_platform_error_Error_destroy(result);
    NSMutableData *entropyData = [serializedHash mutableCopy];
    [entropyData appendUInt256:identity.uniqueID];
    [entropyData appendData:[derivationPath publicKeyDataAtIndex:UINT32_MAX - 1]]; //use the last key in 32 bit space (it won't probably ever be used anyways)
    [mData appendData:uint256_data([entropyData SHA256])];
    return [mData SHA256_2]; //this is the contract ID
}

- (NSString *)base58ContractId {
    return uint256_base58(self.contractId);
}

- (NSString *)base58OwnerId {
    NSAssert(uint256_is_not_zero(self.registeredIdentityUniqueID), @"Registered Identity can not be 0");
    return uint256_base58(self.registeredIdentityUniqueID);
}

- (NSString *)localContractIdentifier {
    if (!_localContractIdentifier) {
        Result_ok_Vec_u8_err_dash_spv_platform_error_Error *result = dash_spv_platform_contract_manager_ContractsManager_contract_serialized_hash(self.chain.shareCore.contractsManager->obj, self.raw_contract);
        NSData *serializedData = NSDataFromPtr(result->ok);
        Result_ok_Vec_u8_err_dash_spv_platform_error_Error_destroy(result);
//        NSData *serializedData = uint256_data([self.serialized SHA256_2]);
        _localContractIdentifier = [NSString stringWithFormat:@"%@-%@", [serializedData base58String], self.chain.uniqueID];
    }
    return _localContractIdentifier;
}

//- (NSString *)jsonSchemaId {
//    return DPCONTRACT_SCHEMA_ID;
//}
//
//- (void)setVersion:(NSInteger)version {
//    _version = version;
//    [self resetSerializedValues];
//}
//
//- (void)setJsonMetaSchema:(NSString *)jsonMetaSchema {
//    _jsonMetaSchema = [jsonMetaSchema copy];
//    [self resetSerializedValues];
//}
//
- (DDocumentTypes *)documents {
    return self.raw_contract->v0->document_types;
//    return [self.mutableDocuments copy];
}

//- (void)setDocuments:(NSDictionary<NSString *, DSStringValueDictionary *> *)documents {
//    _mutableDocuments = [documents mutableCopy];
//    [self resetSerializedValues];
//}
//
//- (void)setDefinitions:(NSDictionary<NSString *, DSStringValueDictionary *> *)definitions {
//    _definitions = [definitions copy];
//    [self resetSerializedValues];
//}
//
//- (BOOL)isDocumentDefinedForType:(NSString *)type {
//    NSParameterAssert(type);
//    return dash_spv_platform_contract_manager_is_document_defined_for_type(self.raw_contract, (char *) [type UTF8String]);
//}
//
//- (void)setDocumentSchema:(DSStringValueDictionary *)schema forType:(NSString *)type {
//    NSParameterAssert(schema);
//    NSParameterAssert(type);
//    if (!schema || !type) return;
//    self.mutableDocuments[type] = schema;
//}
//
//- (nullable DSStringValueDictionary *)documentSchemaForType:(NSString *)type {
//    NSParameterAssert(type);
//    return type ? self.mutableDocuments[type] : nil;
//}
//
//- (nullable NSDictionary<NSString *, NSString *> *)documentSchemaRefForType:(NSString *)type {
//    NSParameterAssert(type);
//    return type && [self isDocumentDefinedForType:type]
//        ? @{@"$ref": [NSString stringWithFormat:@"%@#/documents/%@", self.jsonSchemaId, type]}
//        : nil;
//}

//- (void)resetSerializedValues {
//    [super resetSerializedValues];
//    
//    _keyValueDictionary = nil;
//}

- (NSString *)name {
    return [DSDashPlatform nameForContractWithIdentifier:self.localContractIdentifier];
}

- (NSString *)statusString {
    switch (self.contractState) {
        case DPContractState_Unknown:
            return @"Unknown";
        case DPContractState_Registered:
            return @"Registered";
        case DPContractState_Registering:
            return @"Registering";
        case DPContractState_NotRegistered:
            return @"Not Registered";
    }
    return @"Other State";
}

- (void)unregisterCreator {
    self.registeredIdentityUniqueID = UINT256_ZERO;
    self.contractId = UINT256_ZERO; //will be lazy loaded
    self.entropy = UINT256_ZERO;
}

- (void)registerCreator:(DSIdentity *)identity {
    NSParameterAssert(identity);
    self.registeredIdentityUniqueID = identity ? identity.uniqueID : UINT256_ZERO;
    self.contractId = UINT256_ZERO; //will be lazy loaded
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath identitiesECDSAKeysDerivationPathForWallet:identity.wallet];
    Result_ok_Vec_u8_err_dash_spv_platform_error_Error *result = dash_spv_platform_contract_manager_ContractsManager_contract_serialized_hash(self.chain.shareCore.contractsManager->obj, self.raw_contract);
    NSData *serializedHash = NSDataFromPtr(result->ok);
    Result_ok_Vec_u8_err_dash_spv_platform_error_Error_destroy(result);
    NSMutableData *entropyData = [serializedHash mutableCopy];
//    NSMutableData *entropyData = [self.serializedHash mutableCopy];
    [entropyData appendUInt256:identity.uniqueID];
    [entropyData appendData:[derivationPath publicKeyDataAtIndex:UINT32_MAX - 1]]; //use the last key in 32 bit space (it won't probably ever be used anyways)
    self.entropy = [entropyData SHA256];
}


#pragma mark - Saving

- (DSContractEntity *)contractEntityInContext:(NSManagedObjectContext *)context {
    __block DSContractEntity *entity = nil;
    [context performBlockAndWait:^{
        entity = [DSContractEntity entityWithLocalContractIdentifier:self.localContractIdentifier onChain:self.chain inContext:context];
    }];
    return entity;
}

- (void)saveAndWaitInContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSContractEntity *entity = [self contractEntityInContext:context];
        BOOL hasChange = NO;
        if (!entity) {
            entity = [DSContractEntity managedObjectInBlockedContext:context];
            entity.chain = [self.chain chainEntityInContext:context];
            entity.localContractIdentifier = self.localContractIdentifier;
            if (uint256_is_not_zero(self.registeredIdentityUniqueID))
                entity.registeredBlockchainIdentityUniqueID = uint256_data(self.registeredIdentityUniqueID);
            if (uint256_is_not_zero(self.entropy))
                entity.entropy = uint256_data(self.entropy);
            hasChange = YES;
        }
        if (uint256_is_not_zero(self.registeredIdentityUniqueID) && (!entity.registeredBlockchainIdentityUniqueID || !uint256_eq(entity.registeredBlockchainIdentityUniqueID.UInt256, self.registeredIdentityUniqueID))) {
            entity.registeredBlockchainIdentityUniqueID = uint256_data(self.registeredIdentityUniqueID);
            hasChange = YES;
        } else if (uint256_is_zero(self.registeredIdentityUniqueID) && entity.registeredBlockchainIdentityUniqueID) {
            entity.registeredBlockchainIdentityUniqueID = nil;
            hasChange = YES;
        }

        if (uint256_is_not_zero(self.entropy) && (!entity.entropy || !uint256_eq(entity.entropy.UInt256, self.entropy))) {
            entity.entropy = uint256_data(self.entropy);
            hasChange = YES;
        } else if (uint256_is_zero(self.entropy) && entity.entropy) {
            entity.entropy = nil;
            hasChange = YES;
        }

        if (entity.state != self.contractState) {
            entity.state = self.contractState;
            hasChange = YES;
        }

        if (hasChange) {
            [context ds_save];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DPContractDidUpdateNotification
                                                                    object:nil
                                                                  userInfo:@{DSContractUpdateNotificationKey: self}];
            });
        }
    }];
}


#pragma mark - Special Contracts

//+ (DPContract *)contractAtPath:(NSString *)resource
//                        ofType:(NSString *)type
//                    identifier:(NSString *)identifier
//                      forChain:(DSChain *)chain {
//    // TODO: read async'ly
//    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
//    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
//    NSString *path = [bundle pathForResource:resource ofType:type];
//    NSError *error = nil;
//    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:&error];
//    NSAssert(error == nil, @"Failed reading contract json");
//    DSStringValueDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
//    NSAssert(error == nil, @"Failed parsing json");
//    NSString *localIdentifier = [NSString stringWithFormat:@"%@-%@", identifier, chain.uniqueID];
//    
//    NSDictionary<NSString *, DSStringValueDictionary *> *documents = jsonObject[@"documents"];
//    
//    
//    DPContract *contract = [[DPContract alloc] initWithLocalContractIdentifier:localIdentifier
//                                                                  raw_contract:
//                                                                       onChain:chain];
//    NSString *jsonMetaSchema = jsonObject[@"$schema"];
//    if (jsonMetaSchema)
//        contract.jsonMetaSchema = jsonMetaSchema;
//    NSNumber *version = jsonObject[@"version"];
//    if (version)
//        contract.version = version.integerValue;
//    NSDictionary<NSString *, DSStringValueDictionary *> *definitions = jsonObject[@"definitions"];
//    if (definitions)
//        contract.definitions = definitions;
//    return contract;
//}

+ (DPContract *)localDashpayContractForChain:(DSChain *)chain {
    dpp_data_contract_DataContract *raw_contract = dash_spv_platform_contract_manager_ContractsManager_load_dashpay_contract(chain.shareCore.contractsManager->obj);
    DPContract *contract = [[DPContract alloc] initWithLocalContractIdentifier:[NSString stringWithFormat:@"%@-%@", DASHPAY_CONTRACT, chain.uniqueID]
                                                                  raw_contract:raw_contract
                                                                       onChain:chain];

    
//    DPContract *contract = [self contractAtPath:@"dashpay-contract" ofType:@"json" identifier:DASHPAY_CONTRACT forChain:chain];
    if (uint256_is_not_zero(chain.dashpayContractID) && contract.contractState == DPContractState_Unknown) {
        contract.contractState = DPContractState_Registered;
        contract.contractId = chain.dashpayContractID;
        [contract saveAndWaitInContext:[NSManagedObjectContext platformContext]];
    }
    return contract;
}

+ (DPContract *)localDPNSContractForChain:(DSChain *)chain {
    dpp_data_contract_DataContract *raw_contract = dash_spv_platform_contract_manager_ContractsManager_load_dpns_contract(chain.shareCore.contractsManager->obj);
    DPContract *contract = [[DPContract alloc] initWithLocalContractIdentifier:[NSString stringWithFormat:@"%@-%@", DPNS_CONTRACT, chain.uniqueID]
                                                                  raw_contract:raw_contract
                                                                       onChain:chain];

//    DPContract *contract = [self /*contractAtPath*/:@"dpns-contract" ofType:@"json" identifier:DPNS_CONTRACT forChain:chain];
    if (uint256_is_not_zero(chain.dpnsContractID) && contract.contractState == DPContractState_Unknown) {
        contract.contractState = DPContractState_Registered;
        contract.contractId = chain.dpnsContractID;
        [contract saveAndWaitInContext:[NSManagedObjectContext platformContext]];
    }
    return contract;
}
//
//+ (DPContract *)localDashThumbnailContractForChain:(DSChain *)chain {
//    DPContract *contract = [self contractAtPath:@"dashthumbnail-contract" ofType:@"json" identifier:DASHTHUMBNAIL_CONTRACT forChain:chain];
//    return contract;
//}
//
//#pragma mark - DPPSerializableObject
//
//@synthesize keyValueDictionary = _keyValueDictionary;
//
//- (DSMutableStringValueDictionary *)objectDictionary {
//    if (_keyValueDictionary == nil) {
//        DSMutableStringValueDictionary *json = [[DSMutableStringValueDictionary alloc] init];
//        json[@"$schema"] = self.jsonMetaSchema;
//        json[@"ownerId"] = uint256_data(self.registeredIdentityUniqueID);
//        json[@"$id"] = uint256_data(self.contractId);
//        json[@"documents"] = self.documents;
//        json[@"protocolVersion"] = @(0);
//        if (self.definitions.count > 0) {
//            json[@"definitions"] = self.definitions;
//        }
//        _keyValueDictionary = json;
//    }
//    return _keyValueDictionary;
//}

@end

NS_ASSUME_NONNULL_END
