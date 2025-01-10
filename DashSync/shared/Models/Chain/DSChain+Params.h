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
#import "DSChain.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSChain (Params)

/*! @brief The chain type (MainNet, TestNet or DevNet).  */
@property (nonatomic, assign) dash_spv_crypto_network_chain_type_ChainType *chainType;

// MARK: Sync

/*! @brief The genesis hash is the hash of the first block of the chain. For a devnet this is actually the second block as the first block is created in a special way for devnets.  */
@property (nonatomic, assign) UInt256 genesisHash;

/*! @brief headersMaxAmount is the maximum amount of headers that is expected from peers.  */
@property (nonatomic, assign) uint64_t headersMaxAmount;

/*! @brief This is the minimum amount that can be entered into an amount for a output for it not to be considered dust.  */
@property (nonatomic, readonly) uint64_t minOutputAmount;

/*! @brief The magic number is used in message headers to indicate what network (or chain) a message is intended for.  */
@property (nonatomic, readonly) uint32_t magicNumber;

/*! @brief The base reward is the intial mining reward at genesis for the chain. This goes down by 7% every year. A SPV client does not validate that the reward amount is correct as it would not make sense for miners to enter incorrect rewards as the blocks would be rejected by full nodes.  */
@property (nonatomic, readonly) uint64_t baseReward;
@property (nonatomic, readonly) uint32_t coinType;

/*! @brief minProtocolVersion is the minimum protocol version that peers on this chain can communicate with. This should only be changed in the case of devnets.  */
@property (nonatomic, assign) uint32_t minProtocolVersion;

/*! @brief protocolVersion is the protocol version that we currently use for this chain. This should only be changed in the case of devnets.  */
@property (nonatomic, assign) uint32_t protocolVersion;

/*! @brief maxProofOfWork is the lowest amount of work effort required to mine a block on the chain.  */
@property (nonatomic, readonly) UInt256 maxProofOfWork;

/*! @brief maxProofOfWorkTarget is the lowest amount of work effort required to mine a block on the chain. Here it is represented as the compact target.  */
@property (nonatomic, readonly) uint32_t maxProofOfWorkTarget;

/*! @brief allowMinDifficultyBlocks is set to TRUE on networks where mining is low enough that it can be attacked by increasing difficulty with ASICs and then no longer running ASICs. This is set to NO for Mainnet, and generally should be YES on all other networks.  */
@property (nonatomic, readonly) BOOL allowMinDifficultyBlocks;

/*! @brief The number of minimumDifficultyBlocks.  */
@property (nonatomic, assign) uint32_t minimumDifficultyBlocks;

/*! @brief The default transaction version used when sending transactions.  */
@property (nonatomic, readonly) uint16_t transactionVersion;

/*! @brief A threshold after which a peer will be banned.  */
@property (nonatomic, readonly) uintptr_t peerMisbehavingThreshold;

/*! @brief The flag represents whether the quorum rotation is enabled in this chain.  */
@property (nonatomic, assign) BOOL isRotatedQuorumsPresented;

// MARK: Ports

/*! @brief The standard port for the chain for L1 communication.  */
@property (nonatomic, assign) uint32_t standardPort;

/*! @brief The standard port for the chain for L2 communication through JRPC.  */
@property (nonatomic, assign) uint32_t standardDapiJRPCPort;

/*! @brief The standard port for the chain for L2 communication through GRPC.  */
@property (nonatomic, assign) uint32_t standardDapiGRPCPort;

// MARK: Names and Identifiers

/*! @brief The unique identifier of the chain. This unique id follows the same chain accross devices because it is the short hex string of the genesis hash.  */
@property (nonatomic, readonly) NSString *uniqueID;

/*! @brief The name of the chain (Mainnet-Testnet-Devnet).  */
@property (nonatomic, readonly) NSString *name;

/*! @brief The localized name of the chain (Mainnet-Testnet-Devnet).  */
@property (nonatomic, readonly) NSString *localizedName;

/*! @brief The network name. Currently main, test, dev or reg.  */
@property (nonatomic, readonly) NSString *networkName;


- (void)setDevnetNetworkName:(NSString *)networkName;

// MARK: Sporks

/*! @brief The spork public key as a hex string.  */
@property (nonatomic, strong, nullable) NSString *sporkPublicKeyHexString;

/*! @brief The spork private key as a base 58 string.  */
@property (nonatomic, strong, nullable) NSString *sporkPrivateKeyBase58String;

/*! @brief The spork address base 58 string (addresses are known to be base 58).  */
@property (nonatomic, strong, nullable) NSString *sporkAddress;



// MARK: - L2 Network Chain Info

/*! @brief platformProtocolVersion is the protocol version that we currently use for the platform chain. This should only be changed in the case of devnets.  */
@property (nonatomic, assign) uint32_t platformProtocolVersion;

/*! @brief The dpns contract id.  */
@property (nonatomic, assign) UInt256 dpnsContractID;

/*! @brief The dashpay contract id.  */
@property (nonatomic, assign) UInt256 dashpayContractID;


// MARK: Fees

@property (nonatomic, assign) uint64_t feePerByte;

/*! @brief The fee for transactions in L1 are now entirely dependent on their size.  */
- (uint64_t)feeForTxSize:(NSUInteger)size;


// MARK: - Chain Info methods

- (BOOL)isMainnet;
- (BOOL)isTestnet;
- (BOOL)isDevnetAny;
- (BOOL)isEvolutionEnabled;
- (BOOL)isDevnetWithGenesisHash:(UInt256)genesisHash;
- (BOOL)isCore19Active;
- (BOOL)isCore20Active;
- (BOOL)isCore20ActiveAtHeight:(uint32_t)height;
//- (KeyKind)activeBLSType;

@end

NS_ASSUME_NONNULL_END
