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

#import "BigIntTypes.h"
#import "dash_shared_core.h"
#import "DSChainConstants.h"
#import "DSChainParams.h"
#import "DSKeyManager.h"
#import "DSWallet.h"
#import "NSData+Dash.h"
#import "NSString+Bitcoin.h"

#define FEE_PER_BYTE_KEY @"FEE_PER_BYTE"

#define MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY @"MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY"
#define STANDARD_PORT_LOCATION @"STANDARD_PORT_LOCATION"
#define JRPC_PORT_LOCATION @"JRPC_PORT_LOCATION"
#define GRPC_PORT_LOCATION @"GRPC_PORT_LOCATION"

#define DPNS_CONTRACT_ID @"DPNS_CONTRACT_ID"
#define DASHPAY_CONTRACT_ID @"DASHPAY_CONTRACT_ID"

#define PROTOCOL_VERSION_LOCATION @"PROTOCOL_VERSION_LOCATION"
#define DEFAULT_MIN_PROTOCOL_VERSION_LOCATION @"MIN_PROTOCOL_VERSION_LOCATION"
#define PLATFORM_PROTOCOL_VERSION_LOCATION @"PLATFORM_PROTOCOL_VERSION_LOCATION"
#define PLATFORM_DEFAULT_MIN_PROTOCOL_VERSION_LOCATION @"PLATFORM_MIN_PROTOCOL_VERSION_LOCATION"

#define QUORUM_ROTATION_PRESENCE_KEY @"QUORUM_ROTATION_PRESENCE_KEY"


@interface DSChainParams ()

@property (nonatomic, assign) ChainType chainType;
@property (nonatomic, assign) uint32_t cachedMinimumDifficultyBlocks;
@property (nonatomic, assign) uint32_t cachedMinProtocolVersion;
@property (nonatomic, assign) uint32_t cachedProtocolVersion;
@property (nonatomic, assign) UInt256 cachedMaxProofOfWork;
@property (nonatomic, assign) uint32_t cachedStandardPort;
@property (nonatomic, assign) uint32_t cachedStandardDapiJRPCPort;
@property (nonatomic, assign) uint32_t cachedStandardDapiGRPCPort;
@property (nonatomic, assign) UInt256 cachedDpnsContractID;
@property (nonatomic, assign) UInt256 cachedDashpayContractID;
@property (nonatomic, assign) BOOL cachedIsQuorumRotationPresented;

@end

@implementation DSChainParams

- (instancetype)init {
    if (!(self = [super init])) return nil;
    uint64_t feePerByte = [[NSUserDefaults standardUserDefaults] doubleForKey:FEE_PER_BYTE_KEY];
    self.feePerByte = (feePerByte >= MIN_FEE_PER_B && feePerByte <= MAX_FEE_PER_B) ? feePerByte : DEFAULT_FEE_PER_B;
    return self;
}

- (instancetype)initWithChainType:(ChainType)type {
    if (!(self = [self init])) return nil;
    self.headersMaxAmount = chain_headers_max_amount(type);
    self.standardPort = chain_standard_port(type);
    self.standardDapiJRPCPort = chain_standard_dapi_jrpc_port(type);

    return self;
}

// MARK: - Check Type

- (BOOL)isEvolutionEnabled {
    return NO;
    //    return [self isDevnetAny] || [self isTestnet];
}

- (BOOL)isCore20ActiveAtHeight:(uint32_t)height {
    return height >= chain_core20_activation_height(self.chainType);
}

// MARK: Sync Parameters

- (uint32_t)magicNumber {
    return chain_magic_number(_chainType);
}

- (uint32_t)protocolVersion {
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            return PROTOCOL_VERSION_MAINNET; //(70216 + (self.headersMaxAmount / 2000));
        case ChainType_TestNet:
            return PROTOCOL_VERSION_TESTNET;
        case ChainType_DevNet: {
            NSError *error = nil;
            uint32_t protocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], PROTOCOL_VERSION_LOCATION], &error);
            if (!error && protocolVersion)
                return protocolVersion;
            else
                return PROTOCOL_VERSION_DEVNET;
        }
    }
}

- (void)setProtocolVersion:(uint32_t)protocolVersion {
    if (chain_type_is_devnet_any(self.chainType)) {
        setKeychainInt(protocolVersion, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], PROTOCOL_VERSION_LOCATION], NO);
    }
}

- (BOOL)isRotatedQuorumsPresented {
    if (_cachedIsQuorumRotationPresented) return _cachedIsQuorumRotationPresented;
    switch (self.chainType.tag) {
        case ChainType_MainNet: {
            NSError *error = nil;
            BOOL isPresented = (BOOL)getKeychainInt([NSString stringWithFormat:@"MAINNET_%@", QUORUM_ROTATION_PRESENCE_KEY], &error);
            _cachedIsQuorumRotationPresented = !error && isPresented;
            break;
        }
        case ChainType_TestNet: {
            NSError *error = nil;
            BOOL isPresented = (BOOL)getKeychainInt([NSString stringWithFormat:@"TESTNET_%@", QUORUM_ROTATION_PRESENCE_KEY], &error);
            _cachedIsQuorumRotationPresented = !error && isPresented;
            break;
        }
        case ChainType_DevNet: {
            NSError *error = nil;
            BOOL isPresented = (BOOL)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], QUORUM_ROTATION_PRESENCE_KEY], &error);
            _cachedIsQuorumRotationPresented = !error && isPresented;
            break;
        }
    }
    return _cachedIsQuorumRotationPresented;
}


- (void)setIsRotatedQuorumsPresented:(BOOL)isRotatedQuorumsPresented {
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            setKeychainInt(isRotatedQuorumsPresented, [NSString stringWithFormat:@"MAINNET_%@", QUORUM_ROTATION_PRESENCE_KEY], NO);
            break;
        case ChainType_TestNet:
            setKeychainInt(isRotatedQuorumsPresented, [NSString stringWithFormat:@"TESTNET_%@", QUORUM_ROTATION_PRESENCE_KEY], NO);
            break;
        case ChainType_DevNet: {
            setKeychainInt(isRotatedQuorumsPresented, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], QUORUM_ROTATION_PRESENCE_KEY], NO);
            break;
        }
    }
    _cachedIsQuorumRotationPresented = isRotatedQuorumsPresented;
}

- (uint32_t)minProtocolVersion {
    @synchronized(self) {
        if (_cachedMinProtocolVersion) return _cachedMinProtocolVersion;
        switch (self.chainType.tag) {
            case ChainType_MainNet: {
                NSError *error = nil;
                uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"MAINNET_%@", DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
                if (!error && minProtocolVersion)
                    _cachedMinProtocolVersion = MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_MAINNET);
                else
                    _cachedMinProtocolVersion = DEFAULT_MIN_PROTOCOL_VERSION_MAINNET;
                break;
            }
            case ChainType_TestNet: {
                NSError *error = nil;
                uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"TESTNET_%@", DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
                if (!error && minProtocolVersion)
                    _cachedMinProtocolVersion = MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_TESTNET);
                else
                    _cachedMinProtocolVersion = DEFAULT_MIN_PROTOCOL_VERSION_TESTNET;
                break;
            }
            case ChainType_DevNet: {
                NSError *error = nil;
                uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
                if (!error && minProtocolVersion)
                    _cachedMinProtocolVersion = MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_DEVNET);
                else
                    _cachedMinProtocolVersion = DEFAULT_MIN_PROTOCOL_VERSION_DEVNET;
                break;
            }
        }
        return _cachedMinProtocolVersion;
    }
}


- (void)setMinProtocolVersion:(uint32_t)minProtocolVersion {
    @synchronized(self) {
        if (minProtocolVersion < MIN_VALID_MIN_PROTOCOL_VERSION || minProtocolVersion > MAX_VALID_MIN_PROTOCOL_VERSION) return;
        switch (self.chainType.tag) {
            case ChainType_MainNet:
                setKeychainInt(MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_MAINNET), [NSString stringWithFormat:@"MAINNET_%@", DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
                _cachedMinProtocolVersion = MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_MAINNET);
                break;
            case ChainType_TestNet:
                setKeychainInt(MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_TESTNET), [NSString stringWithFormat:@"TESTNET_%@", DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
                _cachedMinProtocolVersion = MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_TESTNET);
                break;
            case ChainType_DevNet: {
                setKeychainInt(MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_DEVNET), [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
                _cachedMinProtocolVersion = MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_DEVNET);
                break;
            }
        }
    }
}

- (uint32_t)standardPort {
    if (_cachedStandardPort) return _cachedStandardPort;
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            _cachedStandardPort = MAINNET_STANDARD_PORT;
            return MAINNET_STANDARD_PORT;
        case ChainType_TestNet:
            _cachedStandardPort = TESTNET_STANDARD_PORT;
            return TESTNET_STANDARD_PORT;
        case ChainType_DevNet: {
            NSError *error = nil;
            uint32_t cachedStandardPort = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], STANDARD_PORT_LOCATION], &error);
            if (!error && cachedStandardPort) {
                _cachedStandardPort = cachedStandardPort;
                return _cachedStandardPort;
            }
            return DEVNET_STANDARD_PORT;
        }
    }
}

- (void)setStandardPort:(uint32_t)standardPort {
    if (chain_type_is_devnet_any(self.chainType)) {
        _cachedStandardPort = standardPort;
        setKeychainInt(standardPort, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], STANDARD_PORT_LOCATION], NO);
    }
}

- (uint32_t)standardDapiGRPCPort {
    if (_cachedStandardDapiGRPCPort) return _cachedStandardDapiGRPCPort;
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            _cachedStandardDapiGRPCPort = MAINNET_DAPI_GRPC_STANDARD_PORT;
            return MAINNET_DAPI_GRPC_STANDARD_PORT;
        case ChainType_TestNet:
            _cachedStandardDapiGRPCPort = TESTNET_DAPI_GRPC_STANDARD_PORT;
            return TESTNET_DAPI_GRPC_STANDARD_PORT;
        case ChainType_DevNet: {
            NSError *error = nil;
            uint32_t cachedStandardDapiGRPCPort = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], GRPC_PORT_LOCATION], &error);
            if (!error && cachedStandardDapiGRPCPort) {
                _cachedStandardDapiGRPCPort = cachedStandardDapiGRPCPort;
                return _cachedStandardDapiGRPCPort;
            } else
                return DEVNET_DAPI_GRPC_STANDARD_PORT;
        }
    }
}

- (void)setStandardDapiGRPCPort:(uint32_t)standardDapiGRPCPort {
    if (chain_type_is_devnet_any(self.chainType)) {
        _cachedStandardDapiGRPCPort = standardDapiGRPCPort;
        setKeychainInt(standardDapiGRPCPort, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], GRPC_PORT_LOCATION], NO);
    }
}

- (void)setMinimumDifficultyBlocks:(uint32_t)minimumDifficultyBlocks {
    if (chain_type_is_devnet_any(self.chainType)) {
        _cachedMinimumDifficultyBlocks = minimumDifficultyBlocks;
        setKeychainInt(minimumDifficultyBlocks, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY], NO);
    }
}

- (uint32_t)minimumDifficultyBlocks {
    if (_cachedMinimumDifficultyBlocks) return _cachedMinimumDifficultyBlocks;
    if (chain_type_is_devnet_any(self.chainType)) {
        NSError *error = nil;
        uint32_t cachedMinimumDifficultyBlocks = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY], &error);
        if (!error && cachedMinimumDifficultyBlocks) {
            _cachedMinimumDifficultyBlocks = cachedMinimumDifficultyBlocks;
            return _cachedMinimumDifficultyBlocks;
        } else {
            return 0;
        }
    } else {
        _cachedMinimumDifficultyBlocks = 0;
        return 0;
    }
}

- (uint32_t)standardDapiJRPCPort {
    if (_cachedStandardDapiJRPCPort) return _cachedStandardDapiJRPCPort;
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            _cachedStandardDapiJRPCPort = MAINNET_DAPI_JRPC_STANDARD_PORT;
            return MAINNET_DAPI_JRPC_STANDARD_PORT;
        case ChainType_TestNet:
            _cachedStandardDapiJRPCPort = TESTNET_DAPI_JRPC_STANDARD_PORT;
            return TESTNET_DAPI_JRPC_STANDARD_PORT;
        case ChainType_DevNet: {
            NSError *error = nil;
            uint32_t cachedStandardDapiJRPCPort = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], JRPC_PORT_LOCATION], &error);
            if (!error && cachedStandardDapiJRPCPort) {
                _cachedStandardDapiJRPCPort = cachedStandardDapiJRPCPort;
                return _cachedStandardDapiJRPCPort;
            } else
                return DEVNET_DAPI_JRPC_STANDARD_PORT;
        }
    }
}

- (void)setStandardDapiJRPCPort:(uint32_t)standardDapiJRPCPort {
    if (chain_type_is_devnet_any(self.chainType)) {
        _cachedStandardDapiJRPCPort = standardDapiJRPCPort;
        setKeychainInt(standardDapiJRPCPort, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], JRPC_PORT_LOCATION], NO);
    }
}

// MARK: Mining and Dark Gravity Wave Parameters

- (UInt256)maxProofOfWork {
    if (uint256_is_not_zero(_cachedMaxProofOfWork)) return _cachedMaxProofOfWork;
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            _cachedMaxProofOfWork = MAX_PROOF_OF_WORK_MAINNET;
            break;
        case ChainType_TestNet:
            _cachedMaxProofOfWork = MAX_PROOF_OF_WORK_TESTNET;
            break;
        case ChainType_DevNet:
            _cachedMaxProofOfWork = MAX_PROOF_OF_WORK_DEVNET;
            break;
    }
    return _cachedMaxProofOfWork;
}

- (uint32_t)maxProofOfWorkTarget {
    return chain_max_proof_of_work_target(self.chainType);
}

- (BOOL)allowMinDifficultyBlocks {
    return chain_allow_min_difficulty_blocks(self.chainType);
}

- (uint64_t)baseReward {
    if (self.chainType.tag == ChainType_MainNet) return 5 * DUFFS;
    return 50 * DUFFS;
}

// MARK: - L2 Chain Parameters

- (uint32_t)platformProtocolVersion {
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            return PLATFORM_PROTOCOL_VERSION_MAINNET; //(70216 + (self.headersMaxAmount / 2000));
        case ChainType_TestNet:
            return PLATFORM_PROTOCOL_VERSION_TESTNET;
        case ChainType_DevNet: {
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
    if (chain_type_is_devnet_any(self.chainType)) {
        setKeychainInt(platformProtocolVersion, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], PLATFORM_PROTOCOL_VERSION_LOCATION], NO);
    }
}

- (UInt256)dpnsContractID {
    if (uint256_is_not_zero(_cachedDpnsContractID)) return _cachedDpnsContractID;
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            if (!self.isEvolutionEnabled) return UINT256_ZERO;
            _cachedDpnsContractID = MAINNET_DPNS_CONTRACT_ID.base58ToData.UInt256;
            return _cachedDpnsContractID;
        case ChainType_TestNet:
            if (!self.isEvolutionEnabled) return UINT256_ZERO;
            _cachedDpnsContractID = TESTNET_DPNS_CONTRACT_ID.base58ToData.UInt256;
            return _cachedDpnsContractID;
        case ChainType_DevNet: {
            NSError *error = nil;
            NSData *cachedDpnsContractIDData = getKeychainData([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DPNS_CONTRACT_ID], &error);
            if (!error && cachedDpnsContractIDData) {
                _cachedDpnsContractID = cachedDpnsContractIDData.UInt256;
                return _cachedDpnsContractID;
            }
            return UINT256_ZERO;
        }
    }
}

- (void)setDpnsContractID:(UInt256)dpnsContractID {
    if (chain_type_is_devnet_any(self.chainType)) {
        _cachedDpnsContractID = dpnsContractID;
        if (uint256_is_zero(dpnsContractID)) {
            NSError *error = nil;
            NSString *identifier = [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DPNS_CONTRACT_ID];
            BOOL hasDashpayContractID = (getKeychainData(identifier, &error) != nil);
            if (hasDashpayContractID) {
                setKeychainData(nil, identifier, NO);
            }
        } else {
            setKeychainData(uint256_data(dpnsContractID), [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DPNS_CONTRACT_ID], NO);
        }
    }
}

- (UInt256)dashpayContractID {
    if (uint256_is_not_zero(_cachedDashpayContractID)) return _cachedDashpayContractID;
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            if (!self.isEvolutionEnabled) return UINT256_ZERO;
            _cachedDashpayContractID = MAINNET_DASHPAY_CONTRACT_ID.base58ToData.UInt256;
            return _cachedDashpayContractID;
        case ChainType_TestNet:
            if (!self.isEvolutionEnabled) return UINT256_ZERO;
            _cachedDashpayContractID = TESTNET_DASHPAY_CONTRACT_ID.base58ToData.UInt256;
            return _cachedDashpayContractID;
        case ChainType_DevNet: {
            NSError *error = nil;
            NSData *cachedDashpayContractIDData = getKeychainData([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DASHPAY_CONTRACT_ID], &error);
            if (!error && cachedDashpayContractIDData) {
                _cachedDashpayContractID = cachedDashpayContractIDData.UInt256;
                return _cachedDashpayContractID;
            }
            return UINT256_ZERO;
        }
    }
}

- (void)setDashpayContractID:(UInt256)dashpayContractID {
    if (chain_type_is_devnet_any(self.chainType)) {
        _cachedDashpayContractID = dashpayContractID;
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

// outputs below this amount are uneconomical due to fees
- (uint64_t)minOutputAmount {
    uint64_t amount = (TX_MIN_OUTPUT_AMOUNT * self.feePerByte + MIN_FEE_PER_B - 1) / MIN_FEE_PER_B;
    return (amount > TX_MIN_OUTPUT_AMOUNT) ? amount : TX_MIN_OUTPUT_AMOUNT;
}


@end
