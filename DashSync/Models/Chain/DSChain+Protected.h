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

#import "DSChain.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSChain ()

@property (nonatomic, readonly, nullable) NSString * registeredPeersKey;

+ (DSChain*)setUpDevnetWithIdentifier:(NSString*)identifier withCheckpoints:(NSArray<DSCheckpoint*>* _Nullable)checkpointArray withDefaultPort:(uint32_t)port withDefaultDapiJRPCPort:(uint32_t)dapiJRPCPort withDefaultDapiGRPCPort:(uint32_t)dapiGRPCPort dpnsContractID:(UInt256)dpnsContractID dashpayContractID:(UInt256)dashpayContractID isTransient:(BOOL)isTransient;

- (void)setEstimatedBlockHeight:(uint32_t)estimatedBlockHeight fromPeer:(DSPeer*)peer;
- (void)removeEstimatedBlockHeightOfPeer:(DSPeer*)peer;
- (BOOL)addBlock:(DSMerkleBlock *)block fromPeer:(DSPeer*)peer;

@property (nonatomic, assign) UInt256 masternodeBaseBlockHash;

- (void)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes;

/*! @brief Add a wallet to the chain. It is only temporarily in the chain if externaly added this way.  */
- (void)addWallet:(DSWallet*)wallet;

/*! @brief Add a standalone derivation path to the chain. It is only temporarily in the chain if externaly added this way.  */
- (void)addStandaloneDerivationPath:(DSDerivationPath*)derivationPath;

- (void)saveBlocks;

- (void)save;

- (void)wipeWalletsAndDerivatives;
- (void)reloadDerivationPaths;
- (void)clearOrphans;

//This removes all blockchain information from the chain's wallets and derivation paths
- (void)wipeBlockchainInfo;

- (void)wipeMasternodesInContext:(NSManagedObjectContext*)context;

- (BOOL)registerSpecialTransaction:(DSTransaction*)transaction saveImmediately:(BOOL)saveImmediately;

- (void)triggerUpdatesForLocalReferences:(DSTransaction*)transaction;

- (void)updateAddressUsageOfSimplifiedMasternodeEntries:(NSArray*)simplifiedMasternodeEntries;

- (DSWallet* _Nullable)walletHavingBlockchainIdentityCreditFundingRegistrationHash:(UInt160)creditFundingRegistrationHash foundAtIndex:(uint32_t* _Nullable)rIndex;

- (DSWallet* _Nullable)walletHavingProviderVotingAuthenticationHash:(UInt160)votingAuthenticationHash foundAtIndex:(uint32_t* _Nullable)rIndex;

- (DSWallet* _Nullable)walletHavingProviderOwnerAuthenticationHash:(UInt160)owningAuthenticationHash foundAtIndex:(uint32_t* _Nullable)rIndex;

- (DSWallet* _Nullable)walletHavingProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey foundAtIndex:(uint32_t* _Nullable)rIndex;

- (DSWallet * _Nullable)walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:(DSProviderRegistrationTransaction * _Nonnull)transaction foundAtIndex:(uint32_t* _Nullable)rIndex;

@end

NS_ASSUME_NONNULL_END
