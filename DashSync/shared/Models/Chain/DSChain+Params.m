//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import "DSChain+Params.h"
#import "DSChainConstants.h"
#import "DSWallet.h"
#import "NSData+Dash.h"
#import "NSString+Bitcoin.h"
#import <objc/runtime.h>

#define PROTOCOL_VERSION_LOCATION @"PROTOCOL_VERSION_LOCATION"
#define DEFAULT_MIN_PROTOCOL_VERSION_LOCATION @"MIN_PROTOCOL_VERSION_LOCATION"

#define PLATFORM_PROTOCOL_VERSION_LOCATION @"PLATFORM_PROTOCOL_VERSION_LOCATION"
#define PLATFORM_DEFAULT_MIN_PROTOCOL_VERSION_LOCATION @"PLATFORM_MIN_PROTOCOL_VERSION_LOCATION"

#define QUORUM_ROTATION_PRESENCE_KEY @"QUORUM_ROTATION_PRESENCE_KEY"

#define STANDARD_PORT_LOCATION @"STANDARD_PORT_LOCATION"
#define JRPC_PORT_LOCATION @"JRPC_PORT_LOCATION"
#define GRPC_PORT_LOCATION @"GRPC_PORT_LOCATION"

#define DPNS_CONTRACT_ID @"DPNS_CONTRACT_ID"
#define DASHPAY_CONTRACT_ID @"DASHPAY_CONTRACT_ID"

#define MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY @"MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY"

#define SPORK_PUBLIC_KEY_LOCATION @"SPORK_PUBLIC_KEY_LOCATION"
#define SPORK_ADDRESS_LOCATION @"SPORK_ADDRESS_LOCATION"
#define SPORK_PRIVATE_KEY_LOCATION @"SPORK_PRIVATE_KEY_LOCATION"

NSString const *chainTypeKey = @"chainTypeKey";
NSString const *protocolVersionKey = @"protocolVersionKey";
NSString const *minProtocolVersionKey = @"minProtocolVersionKey";
NSString const *standardPortKey = @"standardPortKey";
NSString const *standardDapiGRPCPortKey = @"standardDapiGRPCPortKey";
NSString const *standardDapiJRPCPortKey = @"standardDapiJRPCPortKey";
NSString const *minimumDifficultyBlocksKey = @"minimumDifficultyBlocksKey";
NSString const *maxProofOfWorkKey = @"maxProofOfWorkKey";
NSString const *dpnsContractIDKey = @"dpnsContractIDKey";
NSString const *dashpayContractIDKey = @"dashpayContractIDKey";
NSString const *uniqueIDKey = @"uniqueIDKey";
NSString const *networkNameKey = @"networkNameKey";
NSString const *headersMaxAmountKey = @"headersMaxAmountKey";
NSString const *genesisHashKey = @"genesisHashKey";
NSString const *minOutputAmountKey = @"minOutputAmountKey";
NSString const *cachedIsQuorumRotationPresentedKey = @"cachedIsQuorumRotationPresentedKey";
NSString const *feePerByteKey = @"feePerByteKey";

@implementation DSChain (Params)

- (dash_spv_crypto_network_chain_type_ChainType *)chainType {
    NSValue *value = objc_getAssociatedObject(self, &chainTypeKey);
    return value.pointerValue;
}
- (void)setChainType:(dash_spv_crypto_network_chain_type_ChainType *)chainType {
    objc_setAssociatedObject(self, &chainTypeKey, [NSValue valueWithPointer:chainType], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// MARK: Sync Parameters

- (uint32_t)magicNumber {
    return (uint32_t) dash_spv_crypto_network_chain_type_ChainType_magic_number(self.chainType);
}

- (void)setProtocolVersion:(uint32_t)protocolVersion {
    if (dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType)) {
        setKeychainInt(protocolVersion, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], PROTOCOL_VERSION_LOCATION], NO);
    }
}

- (uint32_t)protocolVersion {
    switch (self.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet:
            return PROTOCOL_VERSION_MAINNET; //(70216 + (self.headersMaxAmount / 2000));
        case dash_spv_crypto_network_chain_type_ChainType_TestNet:
            return PROTOCOL_VERSION_TESTNET;
        case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
            NSError *error = nil;
            uint32_t protocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], PROTOCOL_VERSION_LOCATION], &error);
            if (!error && protocolVersion)
                return protocolVersion;
            else
                return PROTOCOL_VERSION_DEVNET;
        }
    }
}

- (BOOL)isRotatedQuorumsPresented {
    BOOL cachedIsQuorumRotationPresented = objc_getAssociatedObject(self, &cachedIsQuorumRotationPresentedKey);
    if (cachedIsQuorumRotationPresented) return cachedIsQuorumRotationPresented;
    switch (self.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet: {
            NSError *error = nil;
            BOOL isPresented = (BOOL)getKeychainInt([NSString stringWithFormat:@"MAINNET_%@", QUORUM_ROTATION_PRESENCE_KEY], &error);
            objc_setAssociatedObject(self, &cachedIsQuorumRotationPresentedKey, @(!error && isPresented), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            break;
        }
        case dash_spv_crypto_network_chain_type_ChainType_TestNet: {
            NSError *error = nil;
            BOOL isPresented = (BOOL)getKeychainInt([NSString stringWithFormat:@"TESTNET_%@", QUORUM_ROTATION_PRESENCE_KEY], &error);
            objc_setAssociatedObject(self, &cachedIsQuorumRotationPresentedKey, @(!error && isPresented), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            break;
        }
        case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
            NSError *error = nil;
            BOOL isPresented = (BOOL)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], QUORUM_ROTATION_PRESENCE_KEY], &error);
            objc_setAssociatedObject(self, &cachedIsQuorumRotationPresentedKey, @(!error && isPresented), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
          break;
        }
    }
    return objc_getAssociatedObject(self, &cachedIsQuorumRotationPresentedKey);
}


- (void)setIsRotatedQuorumsPresented:(BOOL)isRotatedQuorumsPresented {
    switch (self.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet:
            setKeychainInt(isRotatedQuorumsPresented, [NSString stringWithFormat:@"MAINNET_%@", QUORUM_ROTATION_PRESENCE_KEY], NO);
            break;
        case dash_spv_crypto_network_chain_type_ChainType_TestNet:
            setKeychainInt(isRotatedQuorumsPresented, [NSString stringWithFormat:@"TESTNET_%@", QUORUM_ROTATION_PRESENCE_KEY], NO);
            break;
        case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
            setKeychainInt(isRotatedQuorumsPresented, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], QUORUM_ROTATION_PRESENCE_KEY], NO);
            break;
        }
    }
    objc_setAssociatedObject(self, &cachedIsQuorumRotationPresentedKey, @(isRotatedQuorumsPresented), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (uint32_t)minProtocolVersion {
    @synchronized(self) {
        NSNumber *cachedMinProtocolVersion = objc_getAssociatedObject(self, &minProtocolVersionKey);
        if (cachedMinProtocolVersion) return [cachedMinProtocolVersion unsignedIntValue];
        NSError *error = nil;
        switch (self.chainType->tag) {
            case dash_spv_crypto_network_chain_type_ChainType_MainNet: {
                uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"MAINNET_%@", DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
                uint32_t version = !error && minProtocolVersion ? MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_MAINNET) : DEFAULT_MIN_PROTOCOL_VERSION_MAINNET;
                cachedMinProtocolVersion = @(version);
                break;
            }
            case dash_spv_crypto_network_chain_type_ChainType_TestNet: {
                uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"TESTNET_%@", DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
                uint32_t version = !error && minProtocolVersion ? MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_TESTNET) : DEFAULT_MIN_PROTOCOL_VERSION_TESTNET;
                cachedMinProtocolVersion = @(version);
                break;
            }
            case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
                uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
                uint32_t version = !error && minProtocolVersion ? MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_DEVNET) : DEFAULT_MIN_PROTOCOL_VERSION_DEVNET;
                cachedMinProtocolVersion = @(version);
                break;
            }
        }
        objc_setAssociatedObject(self, &minProtocolVersionKey, cachedMinProtocolVersion, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return [cachedMinProtocolVersion unsignedIntValue];
    }
}


- (void)setMinProtocolVersion:(uint32_t)minProtocolVersion {
    @synchronized(self) {
        if (minProtocolVersion < MIN_VALID_MIN_PROTOCOL_VERSION || minProtocolVersion > MAX_VALID_MIN_PROTOCOL_VERSION) return;
        switch (self.chainType->tag) {
            case dash_spv_crypto_network_chain_type_ChainType_MainNet:
                setKeychainInt(MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_MAINNET), [NSString stringWithFormat:@"MAINNET_%@", DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
                objc_setAssociatedObject(self, &minProtocolVersionKey, @(MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_MAINNET)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                break;
            case dash_spv_crypto_network_chain_type_ChainType_TestNet:
                setKeychainInt(MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_TESTNET), [NSString stringWithFormat:@"TESTNET_%@", DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
                objc_setAssociatedObject(self, &minProtocolVersionKey, @(MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_TESTNET)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                break;
            case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
                setKeychainInt(MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_DEVNET), [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
                objc_setAssociatedObject(self, &minProtocolVersionKey, @(MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_DEVNET)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                break;
            }
        }
    }
}

- (uint32_t)standardPort {
    NSNumber *cachedStandardPort = objc_getAssociatedObject(self, &standardPortKey);
    if (cachedStandardPort) return [cachedStandardPort unsignedIntValue];
    switch (self.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet:
            objc_setAssociatedObject(self, &standardPortKey, @(MAINNET_STANDARD_PORT), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return MAINNET_STANDARD_PORT;
        case dash_spv_crypto_network_chain_type_ChainType_TestNet:
            objc_setAssociatedObject(self, &standardPortKey, @(TESTNET_STANDARD_PORT), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return TESTNET_STANDARD_PORT;
        case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
            NSError *error = nil;
            uint32_t port = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], STANDARD_PORT_LOCATION], &error);
            if (!error && port) {
                objc_setAssociatedObject(self, &standardPortKey, @(port), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                return port;
            } else {
                return DEVNET_STANDARD_PORT;
            }
        }
    }
}

- (void)setStandardPort:(uint32_t)standardPort {
    if (dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType)) {
        objc_setAssociatedObject(self, &standardPortKey, @(standardPort), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        setKeychainInt(standardPort, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], STANDARD_PORT_LOCATION], NO);
    }
}

- (uint32_t)standardDapiGRPCPort {
    NSNumber *cachedStandardDapiGRPCPort = objc_getAssociatedObject(self, &standardDapiGRPCPortKey);
    if (cachedStandardDapiGRPCPort) return [cachedStandardDapiGRPCPort unsignedIntValue];
    switch (self.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet:
            objc_setAssociatedObject(self, &standardDapiGRPCPortKey, @(MAINNET_DAPI_GRPC_STANDARD_PORT), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return MAINNET_DAPI_GRPC_STANDARD_PORT;
        case dash_spv_crypto_network_chain_type_ChainType_TestNet:
            objc_setAssociatedObject(self, &standardDapiGRPCPortKey, @(TESTNET_DAPI_GRPC_STANDARD_PORT), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return TESTNET_DAPI_GRPC_STANDARD_PORT;
        case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
            NSError *error = nil;
            uint32_t cachedStandardDapiGRPCPort = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], GRPC_PORT_LOCATION], &error);
            if (!error && cachedStandardDapiGRPCPort) {
                objc_setAssociatedObject(self, &standardDapiGRPCPortKey, @(cachedStandardDapiGRPCPort), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                return cachedStandardDapiGRPCPort;
            } else
                return DEVNET_DAPI_GRPC_STANDARD_PORT;
        }
    }
}

- (void)setStandardDapiGRPCPort:(uint32_t)standardDapiGRPCPort {
    if (dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType)) {
        objc_setAssociatedObject(self, &standardDapiGRPCPortKey, @(standardDapiGRPCPort), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        setKeychainInt(standardDapiGRPCPort, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], GRPC_PORT_LOCATION], NO);
    }
}
- (uint32_t)standardDapiJRPCPort {
    NSNumber *cached = objc_getAssociatedObject(self, &standardDapiJRPCPortKey);
    if (cached) return [cached unsignedIntValue];
    switch (self.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet:
            objc_setAssociatedObject(self, &standardDapiJRPCPortKey, @(MAINNET_DAPI_JRPC_STANDARD_PORT), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return MAINNET_DAPI_JRPC_STANDARD_PORT;
        case dash_spv_crypto_network_chain_type_ChainType_TestNet:
            objc_setAssociatedObject(self, &standardDapiJRPCPortKey, @(TESTNET_DAPI_JRPC_STANDARD_PORT), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return TESTNET_DAPI_JRPC_STANDARD_PORT;
        case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
            NSError *error = nil;
            uint32_t cachedStandardDapiJRPCPort = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], JRPC_PORT_LOCATION], &error);
            if (!error && cachedStandardDapiJRPCPort) {
                objc_setAssociatedObject(self, &standardDapiJRPCPortKey, @(cachedStandardDapiJRPCPort), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                return cachedStandardDapiJRPCPort;
            } else
                return DEVNET_DAPI_JRPC_STANDARD_PORT;
        }
    }
}

- (void)setStandardDapiJRPCPort:(uint32_t)standardDapiJRPCPort {
    if (dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType)) {
        objc_setAssociatedObject(self, &standardDapiJRPCPortKey, @(standardDapiJRPCPort), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        setKeychainInt(standardDapiJRPCPort, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], JRPC_PORT_LOCATION], NO);
    }
}

// MARK: Mining and Dark Gravity Wave Parameters

- (UInt256)maxProofOfWork {
    NSData *cachedMaxProofOfWork = objc_getAssociatedObject(self, &maxProofOfWorkKey);
    if (cachedMaxProofOfWork != nil) {
        UInt256 work = cachedMaxProofOfWork.UInt256;
        if (uint256_is_not_zero(work))
            return work;
    }
    switch (self.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet:
            cachedMaxProofOfWork = MAX_PROOF_OF_WORK_MAINNET_DATA;
            break;
        case dash_spv_crypto_network_chain_type_ChainType_TestNet:
            cachedMaxProofOfWork = MAX_PROOF_OF_WORK_TESTNET_DATA;
            break;
        case dash_spv_crypto_network_chain_type_ChainType_DevNet:
            cachedMaxProofOfWork = MAX_PROOF_OF_WORK_DEVNET_DATA;
            break;
    }
    objc_setAssociatedObject(self, &maxProofOfWorkKey, cachedMaxProofOfWork, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return cachedMaxProofOfWork.UInt256;
}

- (uint32_t)maxProofOfWorkTarget {
    return dash_spv_crypto_network_chain_type_ChainType_max_proof_of_work_target(self.chainType);
}

- (BOOL)allowMinDifficultyBlocks {
    return dash_spv_crypto_network_chain_type_ChainType_allow_min_difficulty_blocks(self.chainType);
}

- (uint64_t)baseReward {
    if (dash_spv_crypto_network_chain_type_ChainType_is_mainnet(self.chainType)) return 5 * DUFFS;
    return 50 * DUFFS;
}
- (uint32_t)coinType {
    return dash_spv_crypto_network_chain_type_ChainType_coin_type(self.chainType);
}

// MARK: Spork Parameters

- (NSString *)sporkPublicKeyHexString {
    switch (self.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet:
            return SPORK_PUBLIC_KEY_MAINNET;
        case dash_spv_crypto_network_chain_type_ChainType_TestNet:
            return SPORK_PUBLIC_KEY_TESTNET;
        case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
            NSError *error = nil;
            NSString *publicKey = getKeychainString([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_PUBLIC_KEY_LOCATION], &error);
            if (!error && publicKey) {
                return publicKey;
            } else {
                return nil;
            }
        }
    }
    return nil;
}

- (void)setSporkPublicKeyHexString:(NSString *)sporkPublicKey {
    if (dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType)) {
        setKeychainString(sporkPublicKey, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_PUBLIC_KEY_LOCATION], NO);
    }
}

- (NSString *)sporkPrivateKeyBase58String {
    if (dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType)) {
        NSError *error = nil;
        NSString *publicKey = getKeychainString([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_PRIVATE_KEY_LOCATION], &error);
        if (!error && publicKey) {
            return publicKey;
        }
    }
    return nil;
}

- (void)setSporkPrivateKeyBase58String:(NSString *)sporkPrivateKey {
    if (dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType)) {
        setKeychainString(sporkPrivateKey, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_PRIVATE_KEY_LOCATION], YES);
    }
}

- (NSString *)sporkAddress {
    switch (self.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet:
            return SPORK_ADDRESS_MAINNET;
        case dash_spv_crypto_network_chain_type_ChainType_TestNet:
            return SPORK_ADDRESS_TESTNET;
        case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
            NSError *error = nil;
            NSString *publicKey = getKeychainString([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_ADDRESS_LOCATION], &error);
            if (!error && publicKey) {
                return publicKey;
            } else {
                return nil;
            }
        }
    }
    return nil;
}

- (void)setSporkAddress:(NSString *)sporkAddress {
    if (dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType)) {
        setKeychainString(sporkAddress, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_ADDRESS_LOCATION], NO);
    }
}

// MARK: - L2 Chain Parameters

- (uint32_t)platformProtocolVersion {
    switch (self.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet:
            return PLATFORM_PROTOCOL_VERSION_MAINNET; //(70216 + (self.headersMaxAmount / 2000));
        case dash_spv_crypto_network_chain_type_ChainType_TestNet:
            return PLATFORM_PROTOCOL_VERSION_TESTNET;
        case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
            NSError *error = nil;
            uint32_t platformProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], PLATFORM_PROTOCOL_VERSION_LOCATION], &error);
            if (!error && platformProtocolVersion)
                return platformProtocolVersion;
            else
                return PLATFORM_PROTOCOL_VERSION_DEVNET;
        }
    }
}

- (void)setPlatformProtocolVersion:(uint32_t)platformProtocolVersion {
    if (dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType)) {
        setKeychainInt(platformProtocolVersion, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], PLATFORM_PROTOCOL_VERSION_LOCATION], NO);
    }
}

- (UInt256)dpnsContractID {
    if (!self.isEvolutionEnabled) return UINT256_ZERO;
    NSData *cachedDpnsContractIDData = objc_getAssociatedObject(self, &dpnsContractIDKey);
    if (cachedDpnsContractIDData != nil) {
        UInt256 cachedDpnsContractID = cachedDpnsContractIDData.UInt256;
        if (uint256_is_not_zero(cachedDpnsContractID))
            return cachedDpnsContractID;
    }
    switch (self.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet:
            cachedDpnsContractIDData = MAINNET_DPNS_CONTRACT_ID.base58ToData;
            break;
        case dash_spv_crypto_network_chain_type_ChainType_TestNet:
            cachedDpnsContractIDData = TESTNET_DPNS_CONTRACT_ID.base58ToData;
            break;
        case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
            NSError *error = NULL;
            NSData *data = getKeychainData([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DPNS_CONTRACT_ID], &error);
            if (!error && data) {
                cachedDpnsContractIDData = data;
                break;
            } else {
                return UINT256_ZERO;
            }
        }
    }
    objc_setAssociatedObject(self, &dpnsContractIDKey, cachedDpnsContractIDData, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return cachedDpnsContractIDData.UInt256;

}

- (void)setDpnsContractID:(UInt256)dpnsContractID {
    if (dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType)) {
        objc_setAssociatedObject(self, &dpnsContractIDKey, uint256_data(dpnsContractID), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSString *identifier = [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DPNS_CONTRACT_ID];
        if (uint256_is_zero(dpnsContractID)) {
            NSError *error = nil;
            BOOL hasDashpayContractID = (getKeychainData(identifier, &error) != nil);
            if (hasDashpayContractID) {
                setKeychainData(nil, identifier, NO);
            }
        } else {
            setKeychainData(uint256_data(dpnsContractID), identifier, NO);
        }
    }
}

- (UInt256)dashpayContractID {
    if (!self.isEvolutionEnabled) return UINT256_ZERO;
    NSData *cachedData = objc_getAssociatedObject(self, &dashpayContractIDKey);
    if (cachedData != nil) {
        UInt256 cachedDpnsContractID = cachedData.UInt256;
        if (uint256_is_not_zero(cachedDpnsContractID))
            return cachedDpnsContractID;
    }
    switch (self.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet:
            cachedData = MAINNET_DASHPAY_CONTRACT_ID.base58ToData;
            break;
        case dash_spv_crypto_network_chain_type_ChainType_TestNet:
            cachedData = TESTNET_DASHPAY_CONTRACT_ID.base58ToData;
            break;
        case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
            NSError *error = NULL;
            NSData *data = getKeychainData([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DASHPAY_CONTRACT_ID], &error);

            if (!error && data) {
                cachedData = data;
                break;
            } else {
                return UINT256_ZERO;
            }
        }
    }
    objc_setAssociatedObject(self, &dashpayContractIDKey, cachedData, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return cachedData.UInt256;
}

- (void)setDashpayContractID:(UInt256)dashpayContractID {
    if (dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType)) {
        objc_setAssociatedObject(self, &dashpayContractIDKey, uint256_data(dashpayContractID), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (uint256_is_zero(dashpayContractID)) {
            NSError *error = nil;
            NSString *identifier = [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DASHPAY_CONTRACT_ID];
            BOOL hasDashpayContractID = (getKeychainData(identifier, &error) != nil);
            if (hasDashpayContractID) {
                setKeychainData(nil, identifier, NO);
            }
        } else {
            setKeychainData(uint256_data(dashpayContractID), [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DASHPAY_CONTRACT_ID], NO);
        }
    }
}

- (void)setMinimumDifficultyBlocks:(uint32_t)minimumDifficultyBlocks {
    if (dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType)) {
        objc_setAssociatedObject(self, &minimumDifficultyBlocksKey, @(minimumDifficultyBlocks), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        setKeychainInt(minimumDifficultyBlocks, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY], NO);
    }
}

- (uint32_t)minimumDifficultyBlocks {
    NSNumber *cached = objc_getAssociatedObject(self, &minimumDifficultyBlocksKey);
    if (cached) return [cached unsignedIntValue];
    if (dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType)) {
        NSError *error = nil;
        uint32_t cachedMinimumDifficultyBlocks = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY], &error);

        if (!error && cachedMinimumDifficultyBlocks) {
            objc_setAssociatedObject(self, &minimumDifficultyBlocksKey, @(cachedMinimumDifficultyBlocks), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return cachedMinimumDifficultyBlocks;
        } else {
            return 0;
        }
    } else {
        objc_setAssociatedObject(self, &minimumDifficultyBlocksKey, @(0), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return 0;
    }
}

// MARK: - Names and Identifiers

- (NSString *)uniqueID {
    NSString *cached = objc_getAssociatedObject(self, &uniqueIDKey);
    if (!cached) {
        cached = [[NSData dataWithUInt256:[self genesisHash]] shortHexString];
        objc_setAssociatedObject(self, &uniqueIDKey, cached, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cached;
}


- (NSString *)networkName {
    switch (self.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet:
            return @"main";
        case dash_spv_crypto_network_chain_type_ChainType_TestNet:
            return @"test";
        case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
            NSString *cached = objc_getAssociatedObject(self, &networkNameKey);
            if (cached) return cached;
            return @"dev";
        }
    }
}

- (NSString *)name {
    return [DSKeyManager NSStringFrom:dash_spv_crypto_network_chain_type_ChainType_name(self.chainType)];
}

- (NSString *)localizedName {
    switch (self.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet:
            return DSLocalizedString(@"Mainnet", nil);
        case dash_spv_crypto_network_chain_type_ChainType_TestNet:
            return DSLocalizedString(@"Testnet", nil);
        case dash_spv_crypto_network_chain_type_ChainType_DevNet: {
            NSString *cached = objc_getAssociatedObject(self, &networkNameKey);
            if (cached) return cached;
            cached = [DSKeyManager NSStringFrom:dash_spv_crypto_network_chain_type_DevnetType_name(self.chainType->dev_net)];
            objc_setAssociatedObject(self, &networkNameKey, cached, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return cached;
        }
    }
}

- (void)setDevnetNetworkName:(NSString *)networkName {
    if (dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType)) {
        objc_setAssociatedObject(self, &networkNameKey, @"Evonet", OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (uint16_t)transactionVersion {
    return dash_spv_crypto_network_chain_type_ChainType_transaction_version(self.chainType);
}

- (uintptr_t)peerMisbehavingThreshold {
    return dash_spv_crypto_network_chain_type_ChainType_peer_misbehaving_threshold(self.chainType);
}


- (uint64_t)headersMaxAmount {
    NSNumber *cached = objc_getAssociatedObject(self, &headersMaxAmountKey);
    return [cached unsignedLongValue];
}
- (void)setHeadersMaxAmount:(uint64_t)headersMaxAmount {
    objc_setAssociatedObject(self, &headersMaxAmountKey, @(headersMaxAmount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UInt256)genesisHash {
    NSData *data = objc_getAssociatedObject(self, &genesisHashKey);
    return data.UInt256;
}

- (void)setGenesisHash:(UInt256)genesisHash {
    objc_setAssociatedObject(self, &genesisHashKey, uint256_data(genesisHash), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// outputs below this amount are uneconomical due to fees
- (uint64_t)minOutputAmount {
    uint64_t amount = (TX_MIN_OUTPUT_AMOUNT * self.feePerByte + MIN_FEE_PER_B - 1) / MIN_FEE_PER_B;
    return (amount > TX_MIN_OUTPUT_AMOUNT) ? amount : TX_MIN_OUTPUT_AMOUNT;

}

// MARK: Fee Parameters

// fee that will be added for a transaction of the given size in bytes
- (uint64_t)feeForTxSize:(NSUInteger)size {
    uint64_t standardFee = size * TX_FEE_PER_B; //!OCLINT // standard fee based on tx size
#if (!!FEE_PER_KB_URL)
    uint64_t fee = ((size * self.feePerByte + 99) / 100) * 100; // fee using feePerByte, rounded up to nearest 100 satoshi
    return (fee > standardFee) ? fee : standardFee;
#else
    return standardFee;
#endif
}

- (uint64_t)feePerByte {
    NSNumber *value = objc_getAssociatedObject(self, &feePerByteKey);
    return [value unsignedLongValue];
}
- (void)setFeePerByte:(uint64_t)feePerByte {
    objc_setAssociatedObject(self, &feePerByteKey, @(feePerByte), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// MARK: - Check Type

- (BOOL)isMainnet {
    return dash_spv_crypto_network_chain_type_ChainType_is_mainnet(self.chainType);
}

- (BOOL)isTestnet {
    return dash_spv_crypto_network_chain_type_ChainType_is_testnet(self.chainType);
}

- (BOOL)isDevnetAny {
    return dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType);
}

- (BOOL)isEvolutionEnabled {
    return YES;
}

- (BOOL)isDevnetWithGenesisHash:(UInt256)genesisHash {
    return [self isDevnetAny] && uint256_eq([self genesisHash], genesisHash);
}

// MARK: - Helpers

- (BOOL)isCore19Active {
    return self.lastTerminalBlockHeight >=  dash_spv_crypto_network_chain_type_ChainType_core19_activation_height(self.chainType);
}

- (BOOL)isCore20Active {
    return self.lastTerminalBlockHeight >=  dash_spv_crypto_network_chain_type_ChainType_core20_activation_height(self.chainType);
}

- (BOOL)isCore20ActiveAtHeight:(uint32_t)height {
    return height >= dash_spv_crypto_network_chain_type_ChainType_core20_activation_height(self.chainType);
}

//- (KeyKind)activeBLSType {
//    return [self isCore19Active] ? KeyKind_BLSBasic : KeyKind_BLS;
//}

@end
