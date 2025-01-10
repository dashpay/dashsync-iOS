//
//  Created by Vladimir Pirogov
//  Copyright © 2022 Dash Core Group. All rights reserved.
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
#import "DSDerivationPath.h"
#import "DSLocalMasternode.h"
#import "DSMasternodeManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSWallet.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeManager (LocalMasternode)

@property (nonatomic, readonly) NSUInteger localMasternodesCount;
@property (nonatomic, readonly) NSArray<DSLocalMasternode *> *localMasternodes;

- (DSLocalMasternode *)createNewMasternodeWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inWallet:(DSWallet *)wallet;
- (DSLocalMasternode *)createNewMasternodeWithIPAddress:(UInt128)ipAddress
                                                 onPort:(uint32_t)port
                                          inFundsWallet:(DSWallet *_Nullable)fundsWallet
                                       inOperatorWallet:(DSWallet *_Nullable)operatorWallet
                                          inOwnerWallet:(DSWallet *_Nullable)ownerWallet
                                         inVotingWallet:(DSWallet *_Nullable)votingWallet
                                   inPlatformNodeWallet:(DSWallet *_Nullable)platformNodeWallet;
- (DSLocalMasternode *)createNewMasternodeWithIPAddress:(UInt128)ipAddress
                                                 onPort:(uint32_t)port
                                          inFundsWallet:(DSWallet *_Nullable)fundsWallet
                                       fundsWalletIndex:(uint32_t)fundsWalletIndex
                                       inOperatorWallet:(DSWallet *_Nullable)operatorWallet
                                    operatorWalletIndex:(uint32_t)operatorWalletIndex
                                          inOwnerWallet:(DSWallet *_Nullable)ownerWallet
                                       ownerWalletIndex:(uint32_t)ownerWalletIndex
                                         inVotingWallet:(DSWallet *_Nullable)votingWallet
                                      votingWalletIndex:(uint32_t)votingWalletIndex
                                   inPlatformNodeWallet:(DSWallet *_Nullable)platformNodeWallet
                                platformNodeWalletIndex:(uint32_t)platformNodeWalletIndex;
- (DSLocalMasternode *)createNewMasternodeWithIPAddress:(UInt128)ipAddress
                                                 onPort:(uint32_t)port
                                          inFundsWallet:(DSWallet *_Nullable)fundsWallet
                                       fundsWalletIndex:(uint32_t)fundsWalletIndex
                                       inOperatorWallet:(DSWallet *_Nullable)operatorWallet
                                    operatorWalletIndex:(uint32_t)operatorWalletIndex
                                      operatorPublicKey:(DOpaqueKey *)operatorPublicKey
                                          inOwnerWallet:(DSWallet *_Nullable)ownerWallet
                                       ownerWalletIndex:(uint32_t)ownerWalletIndex
                                        ownerPrivateKey:(DOpaqueKey *)ownerPrivateKey
                                         inVotingWallet:(DSWallet *_Nullable)votingWallet
                                      votingWalletIndex:(uint32_t)votingWalletIndex
                                              votingKey:(DOpaqueKey *)votingKey
                                   inPlatformNodeWallet:(DSWallet *_Nullable)platformNodeWallet platformNodeWalletIndex:(uint32_t)platformNodeWalletIndex
                                        platformNodeKey:(DOpaqueKey *)platformNodeKey;
- (DSLocalMasternode *_Nullable)localMasternodeFromProviderRegistrationTransaction:(DSProviderRegistrationTransaction *)providerRegistrationTransaction save:(BOOL)save;
- (DSLocalMasternode *)localMasternodeFromSimplifiedMasternodeEntry:(DMasternodeEntry *)simplifiedMasternodeEntry
                                             claimedWithOwnerWallet:(DSWallet *)wallet
                                                      ownerKeyIndex:(uint32_t)ownerKeyIndex
                                                            onChain:(DSChain *)chain;
- (DSLocalMasternode *_Nullable)localMasternodeHavingProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash;
- (DSLocalMasternode *_Nullable)localMasternodeUsingIndex:(uint32_t)index atDerivationPath:(DSDerivationPath *)derivationPath;
- (NSArray<DSLocalMasternode *> *_Nullable)localMasternodesPreviouslyUsingIndex:(uint32_t)index atDerivationPath:(DSDerivationPath *)derivationPath;
- (void)wipeLocalMasternodeInfo;

@end

NS_ASSUME_NONNULL_END
