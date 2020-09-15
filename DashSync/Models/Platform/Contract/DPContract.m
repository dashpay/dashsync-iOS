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
#import "NSData+Bitcoin.h"
#import "DSDashPlatform.h"
#import "NSData+DSCborDecoding.h"
#import "NSString+Bitcoin.h"
#import "DSContractTransition.h"
#import "DSChain.h"
#import "NSManagedObject+Sugar.h"
#import "DSContractEntity+CoreDataClass.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "NSMutableData+Dash.h"
#import "DSWallet.h"
#import "DSAuthenticationKeysDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

static NSInteger const DEFAULT_VERSION = 1;
static NSString *const DEFAULT_SCHEMA = @"https://schema.dash.org/dpp-0-4-0/meta/data-contract";
static NSString *const DPCONTRACT_SCHEMA_ID = @"contract";

@interface DPContract ()

@property (strong, nonatomic) NSMutableDictionary<NSString *, DSStringValueDictionary *> *mutableDocuments;
@property (copy, nonatomic, null_resettable) NSString *localContractIdentifier;
@property (assign, nonatomic) UInt256 contractId;
@property (assign, nonatomic) UInt256 registeredBlockchainIdentityUniqueID;
@property (assign, nonatomic) UInt160 entropy;
@property (strong, nonatomic) DSChain *chain;

@end

@implementation DPContract

#pragma mark - Init

- (instancetype)initWithLocalContractIdentifier:(NSString *)localContractIdentifier
                                      documents:(NSDictionary<NSString *, DSStringValueDictionary *> *)documents onChain:(DSChain*)chain {
    NSParameterAssert(localContractIdentifier);
    NSParameterAssert(documents);

    self = [super init];
    if (self) {
        _version = DEFAULT_VERSION;
        _localContractIdentifier = localContractIdentifier;
        _jsonMetaSchema = DEFAULT_SCHEMA;
        _mutableDocuments = [documents mutableCopy];
        _definitions = @{};
        _chain = chain;
        
        
        
//        [self.chain.chainManagedObjectContext performBlockAndWait:^{
//            DSContractEntity * entity = [self contractEntityInContext:self.chain.chainManagedObjectContext];
//            if (entity) {
//                self.registeredBlockchainIdentityUniqueID = entity.registeredBlockchainIdentityUniqueID.UInt256;
//                _contractState = entity.state;
//            }
//        }];
    }
    return self;
}

#pragma mark - Initializer Helpers

+ (DPContract *)contractWithName:(NSString *)name
             withLocalIdentifier:(NSString*)localIdentifier
                       documents:(NSDictionary<NSString *, DSStringValueDictionary *> *)documents
                         onChain:(DSChain*)chain {
    NSParameterAssert(name);
    NSParameterAssert(documents);

    NSDictionary *rawContract = @{
        @"name" : name,
        @"documents" : documents,
    };
    DPContract *contract = [self contractFromDictionary:rawContract withLocalIdentifier:localIdentifier onChain:chain];

    return contract;
}

+ (nullable DPContract *)contractFromDictionary:(DSStringValueDictionary *)contractDictionary
                            withLocalIdentifier:(NSString*)localIdentifier
                                        onChain:(DSChain*)chain
                                          error:(NSError *_Nullable __autoreleasing *)error {
    return [self contractFromDictionary:contractDictionary withLocalIdentifier:localIdentifier skipValidation:NO onChain:chain error:error];
}

+ (nullable DPContract *)contractFromDictionary:(DSStringValueDictionary *)contractDictionary
                            withLocalIdentifier:(NSString*)localIdentifier
                                 skipValidation:(BOOL)skipValidation
                                        onChain:(DSChain*)chain
                                          error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(contractDictionary);

    // TODO: validate rawContract

    DPContract *contract = [self contractFromDictionary:contractDictionary withLocalIdentifier:localIdentifier onChain:chain];

    return contract;
}

+ (nullable DPContract *)contractFromSerialized:(NSData *)data
                                        onChain:(DSChain*)chain
                                          error:(NSError *_Nullable __autoreleasing *)error {
    return [self contractFromSerialized:data withLocalIdentifier:[data base64String] skipValidation:NO onChain:chain error:error];
}

+ (nullable DPContract *)contractFromSerialized:(NSData *)data
                            withLocalIdentifier:(NSString*)identifier
                                 skipValidation:(BOOL)skipValidation
                                        onChain:(DSChain*)chain
                                          error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(data);

    DSStringValueDictionary *contractDictionary = [data ds_decodeCborError:error];
    if (!contractDictionary) {
        return nil;
    }

    return [self contractFromDictionary:contractDictionary
                    withLocalIdentifier:identifier
                         skipValidation:skipValidation
                                onChain:chain
                                  error:error];
}

+ (DPContract *)contractFromDictionary:(DSStringValueDictionary *)rawContract withLocalIdentifier:(NSString*)localContractIdentifier onChain:(DSChain*)chain {
    NSDictionary<NSString *, DSStringValueDictionary *> *documents = rawContract[@"documents"];

    DPContract *contract = [[DPContract alloc] initWithLocalContractIdentifier:localContractIdentifier
                                                  documents:documents onChain:chain];

    NSString *jsonMetaSchema = rawContract[@"$schema"];
    if (jsonMetaSchema) {
        contract.jsonMetaSchema = jsonMetaSchema;
    }

    NSNumber *version = rawContract[@"version"];
    if (version) {
        contract.version = version.integerValue;
    }

    NSDictionary<NSString *, DSStringValueDictionary *> *definitions = rawContract[@"definitions"];
    if (definitions) {
        contract.definitions = definitions;
    }
    

    return contract;
}

#pragma mark - Contract Info

-(UInt256)contractId {
    if (uint256_is_zero(_contractId)) {
        NSAssert(!uint256_is_zero(self.registeredBlockchainIdentityUniqueID),@"Registered Identity needs to be set");
        NSAssert(!uint160_is_zero(self.entropy),@"Entropy needs to be set");
        NSMutableData * mData = [NSMutableData data];
        [mData appendUInt256:self.registeredBlockchainIdentityUniqueID];
        NSString * entropyAddress = [NSString addressWithHash160:self.entropy onChain:self.chain];
        [mData appendData:entropyAddress.base58ToData];
        _contractId = [mData SHA256_2];
    }
    return _contractId;
}

-(UInt256)contractIdIfRegisteredByBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity {
    NSMutableData * mData = [NSMutableData data];
    [mData appendUInt256:blockchainIdentity.uniqueID];
    DSWallet * wallet = blockchainIdentity.wallet;
    DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentitiesECDSAKeysDerivationPathForWallet:wallet];
    NSMutableData * entropyData = [self.serializedHash mutableCopy];
    [entropyData appendUInt256:blockchainIdentity.uniqueID];
    [entropyData appendData:[derivationPath publicKeyDataAtIndex:UINT32_MAX - 1]]; //use the last key in 32 bit space (it won't probably ever be used anyways)
    NSString * entropyAddress = [NSString addressWithHash160:[entropyData RMD160] onChain:self.chain];
    [mData appendData:entropyAddress.base58ToData];
    UInt256 contractId = [mData SHA256_2];
    return contractId;
}

-(NSString*)base58ContractId {
    return uint256_base58(self.contractId);
}

-(NSString*)base58OwnerId {
    NSAssert(!uint256_is_zero(self.registeredBlockchainIdentityUniqueID),@"Registered Identity can not be 0");
    return uint256_base58(self.registeredBlockchainIdentityUniqueID);
}

- (NSString *)localContractIdentifier {
    if (!_localContractIdentifier) {
        NSData *serializedData = uint256_data([self.serialized SHA256_2]);
        _localContractIdentifier = [NSString stringWithFormat:@"%@-%@",[serializedData base58String],self.chain.uniqueID];
    }
    return _localContractIdentifier;
}

- (NSString *)jsonSchemaId {
    return DPCONTRACT_SCHEMA_ID;
}

- (void)setVersion:(NSInteger)version {
    _version = version;
    [self resetSerializedValues];
}

- (void)setJsonMetaSchema:(NSString *)jsonMetaSchema {
    _jsonMetaSchema = [jsonMetaSchema copy];
    [self resetSerializedValues];
}

- (NSDictionary<NSString *, DSStringValueDictionary *> *)documents {
    return [self.mutableDocuments copy];
}

- (void)setDocuments:(NSDictionary<NSString *, DSStringValueDictionary *> *)documents {
    _mutableDocuments = [documents mutableCopy];
    [self resetSerializedValues];
}

- (void)setDefinitions:(NSDictionary<NSString *, DSStringValueDictionary *> *)definitions {
    _definitions = [definitions copy];
    [self resetSerializedValues];
}

- (BOOL)isDocumentDefinedForType:(NSString *)type {
    NSParameterAssert(type);
    if (!type) {
        return NO;
    }

    BOOL isDefined = self.mutableDocuments[type] != nil;

    return isDefined;
}

- (void)setDocumentSchema:(DSStringValueDictionary *)schema forType:(NSString *)type {
    NSParameterAssert(schema);
    NSParameterAssert(type);
    if (!schema || !type) {
        return;
    }

    self.mutableDocuments[type] = schema;
}

- (nullable DSStringValueDictionary *)documentSchemaForType:(NSString *)type {
    NSParameterAssert(type);
    if (!type) {
        return nil;
    }

    return self.mutableDocuments[type];
}

- (nullable NSDictionary<NSString *, NSString *> *)documentSchemaRefForType:(NSString *)type {
    NSParameterAssert(type);
    if (!type) {
        return nil;
    }

    if (![self isDocumentDefinedForType:type]) {
        return nil;
    }

    NSString *refValue = [NSString stringWithFormat:@"%@#/documents/%@",
                                                    self.jsonSchemaId, type];
    NSDictionary<NSString *, NSString *> *dpObjectSchemaRef = @{ @"$ref" : refValue };

    return dpObjectSchemaRef;
}

- (void)resetSerializedValues {
    [super resetSerializedValues];
    _keyValueDictionary = nil;
}

-(NSString*)name {
    return [DSDashPlatform nameForContractWithIdentifier:self.localContractIdentifier];
}

-(NSString*)statusString {
    switch (self.contractState) {
        case DPContractState_Unknown:
            return @"Unknown";
        case DPContractState_Registered:
            return @"Registered";
        case DPContractState_Registering:
            return @"Registering";
        case DPContractState_NotRegistered:
            return @"Not Registered";
        default:
            break;
    }
    return @"Other State";
}

-(void)unregisterCreatorInContext:(NSManagedObjectContext*)context {
    self.registeredBlockchainIdentityUniqueID = UINT256_ZERO;
    self.contractId = UINT256_ZERO; //will be lazy loaded
    self.entropy = UINT160_ZERO;
    [self saveAndWaitInContext:context];
}

- (void)registerCreator:(DSBlockchainIdentity*)blockchainIdentity inContext:(NSManagedObjectContext*)context {
    NSParameterAssert(blockchainIdentity);
    self.registeredBlockchainIdentityUniqueID = blockchainIdentity?blockchainIdentity.uniqueID:UINT256_ZERO;
    self.contractId = UINT256_ZERO; //will be lazy loaded
    DSWallet * wallet = blockchainIdentity.wallet;
    DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentitiesECDSAKeysDerivationPathForWallet:wallet];
    NSMutableData * entropyData = [self.serializedHash mutableCopy];
    [entropyData appendUInt256:blockchainIdentity.uniqueID];
    [entropyData appendData:[derivationPath publicKeyDataAtIndex:UINT32_MAX - 1]]; //use the last key in 32 bit space (it won't probably ever be used anyways)
    self.entropy = [entropyData RMD160];
    [self saveAndWaitInContext:context];
}

-(void)setContractState:(DPContractState)contractState inContext:(NSManagedObjectContext*)context {
    _contractState = contractState;
    [self saveAndWaitInContext:context];
}

#pragma mark - Transitions

-(DSContractTransition*)contractRegistrationTransitionForIdentity:(DSBlockchainIdentity*)blockchainIdentity {
    return [[DSContractTransition alloc] initWithContract:self withTransitionVersion:1 blockchainIdentityUniqueId:blockchainIdentity.uniqueID onChain:self.chain];
}


#pragma mark - Saving

-(DSContractEntity*)contractEntityInContext:(NSManagedObjectContext*)context {
    __block DSContractEntity* entity = nil;
    [context performBlockAndWait:^{
        entity = [DSContractEntity anyObjectInContext:context matching:@"localContractIdentifier == %@ && chain == %@",self.localContractIdentifier,[self.chain chainEntityInContext:context]];
    }];
    return entity;
}

-(void)saveAndWaitInContext:(NSManagedObjectContext*)context {
    [context performBlockAndWait:^{
        DSContractEntity * entity = [self contractEntityInContext:context];
        BOOL hasChange = NO;
        if (!entity) {
            entity = [DSContractEntity managedObjectInContext:context];
            entity.chain = [self.chain chainEntityInContext:context];
            entity.localContractIdentifier = self.localContractIdentifier;
            if (!uint256_is_zero(self.registeredBlockchainIdentityUniqueID)) {
                entity.registeredBlockchainIdentityUniqueID = uint256_data(self.registeredBlockchainIdentityUniqueID);
            }
            if (!uint160_is_zero(self.entropy)) {
                entity.entropy = uint160_data(self.entropy);
            }
            hasChange = YES;
        }
        if (!uint256_is_zero(self.registeredBlockchainIdentityUniqueID) && (!entity.registeredBlockchainIdentityUniqueID || !uint256_eq(entity.registeredBlockchainIdentityUniqueID.UInt256, self.registeredBlockchainIdentityUniqueID))) {
            entity.registeredBlockchainIdentityUniqueID = uint256_data(self.registeredBlockchainIdentityUniqueID);
            hasChange = YES;
        } else if (uint256_is_zero(self.registeredBlockchainIdentityUniqueID) && entity.registeredBlockchainIdentityUniqueID) {
            entity.registeredBlockchainIdentityUniqueID = nil;
            hasChange = YES;
        }
        
        if (!uint160_is_zero(self.entropy) && (!entity.entropy || !uint160_eq(entity.entropy.UInt160, self.entropy))) {
            entity.entropy = uint160_data(self.entropy);
            hasChange = YES;
        } else if (uint160_is_zero(self.entropy) && entity.entropy) {
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
                [[NSNotificationCenter defaultCenter] postNotificationName:DPContractDidUpdateNotification object:nil userInfo:@{DSContractUpdateNotificationKey:self}];
            });
        }
        
    }];
}


#pragma mark - Special Contracts

+ (DPContract *)localDashpayContractForChain:(DSChain*)chain {
    // TODO: read async'ly
    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *path = [bundle pathForResource:@"dashpay-contract" ofType:@"json"];
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:&error];
    NSAssert(error == nil, @"Failed reading contract json");
    DSStringValueDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    NSAssert(error == nil, @"Failed parsing json");
    
    NSString * localIdentifier = [NSString stringWithFormat:@"%@-%@",DASHPAY_CONTRACT,chain.uniqueID];
    
    DPContract *contract = [self contractFromDictionary:jsonObject withLocalIdentifier:localIdentifier onChain:chain error:&error];
    NSAssert(error == nil, @"Failed building DPContract");
    if (!uint256_is_zero(chain.dashpayContractID) && contract.contractState == DPContractState_Unknown) {
        [contract setContractState:DPContractState_Registered inContext:[NSManagedObjectContext platformContext]];
        contract.contractId = chain.dashpayContractID;
        [contract saveAndWaitInContext:[NSManagedObjectContext platformContext]];
    }

    return contract;
}

+ (DPContract *)localDPNSContractForChain:(DSChain*)chain {
    // TODO: read async'ly
    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *path = [bundle pathForResource:@"dpns-contract" ofType:@"json"];
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:&error];
    NSAssert(error == nil, @"Failed reading contract json");
    DSStringValueDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    NSAssert(error == nil, @"Failed parsing json");
    
    NSString * localIdentifier = [NSString stringWithFormat:@"%@-%@",DPNS_CONTRACT,chain.uniqueID];
    
    DPContract *contract = [self contractFromDictionary:jsonObject withLocalIdentifier:localIdentifier onChain:chain error:&error];
    NSAssert(error == nil, @"Failed building DPContract");
    if (!uint256_is_zero(chain.dpnsContractID) && contract.contractState == DPContractState_Unknown) {
        [contract setContractState:DPContractState_Registered inContext:[NSManagedObjectContext platformContext]];
        contract.contractId = chain.dpnsContractID;
        [contract saveAndWaitInContext:[NSManagedObjectContext platformContext]];
    }
    return contract;
}

#pragma mark - DPPSerializableObject

@synthesize keyValueDictionary = _keyValueDictionary;

- (DSMutableStringValueDictionary *)objectDictionary {
    if (_keyValueDictionary == nil) {
        DSMutableStringValueDictionary *json = [[DSMutableStringValueDictionary alloc] init];
        json[@"$schema"] = self.jsonMetaSchema;
        json[@"ownerId"] = uint256_base58(self.registeredBlockchainIdentityUniqueID);
        json[@"$id"] = self.base58ContractId;
        json[@"documents"] = self.documents;
        json[@"protocolVersion"] = @(0);
        if (self.definitions.count > 0) {
            json[@"definitions"] = self.definitions;
        }
        _keyValueDictionary = json;
    }
    return _keyValueDictionary;
}

@end

NS_ASSUME_NONNULL_END
