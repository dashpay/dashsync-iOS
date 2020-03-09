//
//  DSDashSync.h
//  dashsync
//
//  Created by Sam Westrich on 3/4/18.
//  Copyright © 2019 dashcore. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "DSError.h"

#import "DSBlockchainIdentity.h"
#import "DSChain.h"
#import "DSEnvironment.h"
#import "DSPeerManager.h"
#import "DSReachabilityManager.h"

#import "DSBLSKey.h"
#import "DSECDSAKey.h"
#import "DSKey.h"

#import "DSAuthenticationKeysDerivationPath.h"
#import "DSCreditFundingDerivationPath.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSFundsDerivationPath.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSSimpleIndexedDerivationPath.h"

#import "DSSparseMerkleTree.h"

#import "DSBlockchainIdentity.h"
#import "DSCreditFundingTransaction.h"

#import "DSAccount.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSAddressEntity+CoreDataProperties.h"
#import "DSAuthenticationManager.h"
#import "DSBIP39Mnemonic.h"
#import "DSChainLockEntity+CoreDataProperties.h"
#import "DSChainManager.h"
#import "DSChainsManager.h"
#import "DSDAPINetworkService.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathEntity+CoreDataProperties.h"
#import "DSEventManager.h"
#import "DSGovernanceObject.h"
#import "DSGovernanceObjectEntity+CoreDataProperties.h"
#import "DSGovernanceObjectHashEntity+CoreDataProperties.h"
#import "DSGovernanceSyncManager.h"
#import "DSGovernanceVote.h"
#import "DSGovernanceVoteEntity+CoreDataProperties.h"
#import "DSGovernanceVoteHashEntity+CoreDataProperties.h"
#import "DSInsightManager.h"
#import "DSLocalMasternode.h"
#import "DSLocalMasternodeEntity+CoreDataProperties.h"
#import "DSMasternodeList.h"
#import "DSMasternodeManager.h"
#import "DSMerkleBlockEntity+CoreDataProperties.h"
#import "DSOptionsManager.h"
#import "DSPeerEntity+CoreDataProperties.h"
#import "DSPriceManager.h"
#import "DSShapeshiftManager.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "DSSporkEntity+CoreDataProperties.h"
#import "DSSporkManager.h"
#import "DSTransactionEntity+CoreDataProperties.h"
#import "DSTransactionHashEntity+CoreDataProperties.h"
#import "DSTransactionManager.h"
#import "DSTxInputEntity+CoreDataProperties.h"
#import "DSTxOutputEntity+CoreDataProperties.h"
#import "DSVersionManager.h"
#import "DSWallet.h"
#import "NSArray+Dash.h"
#import "NSData+Dash.h"
#import "NSDate+Utils.h"
#import "NSMutableData+Dash.h"
#import "NSString+Dash.h"

#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"

#import "DSPaymentProtocol.h"
#import "DSPaymentRequest.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
#import "NSManagedObject+Sugar.h"

#import "DSTransaction+Utils.h"
#import "DSTransactionFactory.h"

#import "DSBlockchainIdentityCloseTransition.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBlockchainIdentityTopupTransition.h"
#import "DSBlockchainIdentityUpdateTransition.h"

#import "DSBlockchainIdentity.h"
#import "DSContactEntity+CoreDataClass.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSMasternodeList.h"
#import "DSMasternodeListEntity+CoreDataProperties.h"
#import "DSPotentialContact.h"
#import "DSPotentialOneWayFriendship.h"
#import "DSQuorumEntry.h"
#import "DSQuorumEntryEntity+CoreDataProperties.h"

#import "DSNetworking.h"

NS_ASSUME_NONNULL_BEGIN

#define SHAPESHIFT_ENABLED 0

//! Project version number for dashsync.
FOUNDATION_EXPORT double DashSyncVersionNumber;

//! Project version string for dashsync.
FOUNDATION_EXPORT const unsigned char DashSyncVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <dashsync/PublicHeader.h>

@interface DashSync : NSObject

@property (nonatomic, assign) BOOL deviceIsJailbroken;

+ (instancetype)sharedSyncController;

/// Registration must be complete before the end of application:didFinishLaunchingWithOptions:
- (void)registerBackgroundFetchOnce;
- (void)setupDashSyncOnce;

- (void)startSyncForChain:(DSChain *_Nonnull)chain;
- (void)stopSyncForChain:(DSChain *_Nonnull)chain;
- (void)stopSyncAllChains;

- (void)wipePeerDataForChain:(DSChain *_Nonnull)chain;
- (void)wipeBlockchainDataForChain:(DSChain *_Nonnull)chain;
- (void)wipeGovernanceDataForChain:(DSChain *_Nonnull)chain;
- (void)wipeMasternodeDataForChain:(DSChain *_Nonnull)chain;
- (void)wipeSporkDataForChain:(DSChain *_Nonnull)chain;
- (void)wipeWalletDataForChain:(DSChain *_Nonnull)chain forceReauthentication:(BOOL)forceReauthentication;

- (uint64_t)dbSize;

- (void)scheduleBackgroundFetch;
- (void)performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

@end

NS_ASSUME_NONNULL_END
