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

NS_ASSUME_NONNULL_BEGIN

@interface DSChainParams : NSObject

- (instancetype)initWithChainType:(ChainType)type;

// MARK: - Chain Info methods

- (BOOL)isEvolutionEnabled;
- (BOOL)isCore20ActiveAtHeight:(uint32_t)height;

// MARK: Fees

@property (nonatomic, assign) uint64_t feePerByte;
- (uint64_t)feeForTxSize:(NSUInteger)size;

// MARK: Other

/*! @brief The magic number is used in message headers to indicate what network (or chain) a message is intended for.  */
@property (nonatomic, readonly) uint32_t magicNumber;

/*! @brief The base reward is the intial mining reward at genesis for the chain. This goes down by 7% every year. A SPV client does not validate that the reward amount is correct as it would not make sense for miners to enter incorrect rewards as the blocks would be rejected by full nodes.  */
@property (nonatomic, readonly) uint64_t baseReward;

/*! @brief minProtocolVersion is the minimum protocol version that peers on this chain can communicate with. This should only be changed in the case of devnets.  */
@property (nonatomic, assign) uint32_t minProtocolVersion;

/*! @brief protocolVersion is the protocol version that we currently use for this chain. This should only be changed in the case of devnets.  */
@property (nonatomic, assign) uint32_t protocolVersion;

/*! @brief headersMaxAmount is the maximum amount of headers that is expected from peers.  */
@property (nonatomic, assign) uint64_t headersMaxAmount;

/*! @brief maxProofOfWork is the lowest amount of work effort required to mine a block on the chain.  */
@property (nonatomic, readonly) UInt256 maxProofOfWork;

/*! @brief maxProofOfWorkTarget is the lowest amount of work effort required to mine a block on the chain. Here it is represented as the compact target.  */
@property (nonatomic, readonly) uint32_t maxProofOfWorkTarget;

/*! @brief allowMinDifficultyBlocks is set to TRUE on networks where mining is low enough that it can be attacked by increasing difficulty with ASICs and then no longer running ASICs. This is set to NO for Mainnet, and generally should be YES on all other networks.  */
@property (nonatomic, readonly) BOOL allowMinDifficultyBlocks;


/*! @brief This is the minimum amount that can be entered into an amount for a output for it not to be considered dust.  */
@property (nonatomic, readonly) uint64_t minOutputAmount;


// MARK: - L2 Network Chain Info

/*! @brief platformProtocolVersion is the protocol version that we currently use for the platform chain. This should only be changed in the case of devnets.  */
@property (nonatomic, assign) uint32_t platformProtocolVersion;

/*! @brief The dpns contract id.  */
@property (nonatomic, assign) UInt256 dpnsContractID;

/*! @brief The dashpay contract id.  */
@property (nonatomic, assign) UInt256 dashpayContractID;

// MARK: Ports

/*! @brief The standard port for the chain for L1 communication.  */
@property (nonatomic, assign) uint32_t standardPort;

/*! @brief The standard port for the chain for L2 communication through JRPC.  */
@property (nonatomic, assign) uint32_t standardDapiJRPCPort;

/*! @brief The standard port for the chain for L2 communication through GRPC.  */
@property (nonatomic, assign) uint32_t standardDapiGRPCPort;

@end

NS_ASSUME_NONNULL_END
