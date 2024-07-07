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

#import <Foundation/Foundation.h>
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSKeyManager.h"

#define SPORK_PUBLIC_KEY_LOCATION @"SPORK_PUBLIC_KEY_LOCATION"
#define SPORK_ADDRESS_LOCATION @"SPORK_ADDRESS_LOCATION"
#define SPORK_PRIVATE_KEY_LOCATION @"SPORK_PRIVATE_KEY_LOCATION"

@interface DSChain ()
@end

@implementation DSChain (Params)

- (BOOL)isMainnet {
    return self.chainType.tag == ChainType_MainNet;
}

- (BOOL)isTestnet {
    return self.chainType.tag == ChainType_TestNet;
}

- (BOOL)isDevnetAny {
    return chain_type_is_devnet_any(self.chainType);
}

- (BOOL)isEvolutionEnabled {
    return [self.params isEvolutionEnabled];
}

- (BOOL)isCore20ActiveAtHeight:(uint32_t)height {
    return [self.params isCore20ActiveAtHeight:height];
}


- (BOOL)allowMinDifficultyBlocks {
    return [self.params allowMinDifficultyBlocks];
}

- (uint64_t)baseReward {
    return [self.params baseReward];
}

- (UInt256)dashpayContractID {
    return [self.params dashpayContractID];
}

- (void)setDashpayContractID:(UInt256)dashpayContractID {
    self.params.dashpayContractID = dashpayContractID;
}

- (UInt256)dpnsContractID {
    return [self.params dpnsContractID];
}

- (void)setDpnsContractID:(UInt256)dpnsContractID {
    self.params.dpnsContractID = dpnsContractID;
}

- (uint32_t)platformProtocolVersion {
    return [self.params platformProtocolVersion];
}

- (void)setPlatformProtocolVersion:(uint32_t)platformProtocolVersion {
    self.params.platformProtocolVersion = platformProtocolVersion;
}

- (uint64_t)feePerByte {
    return [self.params feePerByte];
}

- (uint64_t)headersMaxAmount {
    return [self.params headersMaxAmount];
}

- (void)setHeadersMaxAmount:(uint64_t)headersMaxAmount {
    self.params.headersMaxAmount = headersMaxAmount;
}

- (uint32_t)magicNumber {
    return [self.params magicNumber];
}

- (UInt256)maxProofOfWork {
    return [self.params maxProofOfWork];
}

- (uint32_t)maxProofOfWorkTarget {
    return [self.params maxProofOfWorkTarget];
}

- (uint64_t)minOutputAmount {
    return [self.params minOutputAmount];
}

- (uint32_t)minProtocolVersion {
    return [self.params minProtocolVersion];
}

- (void)setMinProtocolVersion:(uint32_t)minProtocolVersion {
    self.params.minProtocolVersion = minProtocolVersion;
}

- (uint32_t)protocolVersion {
    return [self.params protocolVersion];
}

- (void)setProtocolVersion:(uint32_t)protocolVersion {
    self.params.protocolVersion = protocolVersion;
}

- (uint32_t)standardPort {
    return [self.params standardPort];
}

- (void)setStandardPort:(uint32_t)standardPort {
    self.params.standardPort = standardPort;
}

- (uint32_t)standardDapiGRPCPort {
    return [self.params standardDapiGRPCPort];
}

- (void)setStandardDapiGRPCPort:(uint32_t)standardDapiGRPCPort {
    self.params.standardDapiGRPCPort = standardDapiGRPCPort;
}

- (uint32_t)standardDapiJRPCPort {
    return [self.params standardDapiJRPCPort];
}

- (void)setStandardDapiJRPCPort:(uint32_t)standardDapiJRPCPort {
    self.params.standardDapiJRPCPort = standardDapiJRPCPort;
}

// MARK: Spork Parameters

- (NSString *)sporkPublicKeyHexString {
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            return SPORK_PUBLIC_KEY_MAINNET;
        case ChainType_TestNet:
            return SPORK_PUBLIC_KEY_TESTNET;
        case ChainType_DevNet: {
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
    if (chain_type_is_devnet_any(self.chainType)) {
        setKeychainString(sporkPublicKey, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_PUBLIC_KEY_LOCATION], NO);
    }
}

- (NSString *)sporkPrivateKeyBase58String {
    if (chain_type_is_devnet_any(self.chainType)) {
        NSError *error = nil;
        NSString *publicKey = getKeychainString([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_PRIVATE_KEY_LOCATION], &error);
        if (!error && publicKey) {
            return publicKey;
        }
    }
    return nil;
}

- (void)setSporkPrivateKeyBase58String:(NSString *)sporkPrivateKey {
    if (chain_type_is_devnet_any(self.chainType)) {
        setKeychainString(sporkPrivateKey, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_PRIVATE_KEY_LOCATION], YES);
    }
}

- (NSString *)sporkAddress {
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            return SPORK_ADDRESS_MAINNET;
        case ChainType_TestNet:
            return SPORK_ADDRESS_TESTNET;
        case ChainType_DevNet: {
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
    if (chain_type_is_devnet_any(self.chainType)) {
        setKeychainString(sporkAddress, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_ADDRESS_LOCATION], NO);
    }
}
- (uint64_t)feeForTxSize:(NSUInteger)size {
    return [self.params feeForTxSize:size];
}

@end
