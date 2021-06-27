//
//  DSDashSync.h
//  dashsync
//
//  Created by Sam Westrich on 3/4/18.
//  Copyright © 2019 dashcore. All rights reserved.
//

#import "DSError.h"

#import "DSBlockchainIdentity.h"
#import "DSChain.h"
#import "DSCheckpoint.h"
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
#import "DSBlockchainInvitation.h"
#import "DSCreditFundingTransaction.h"

#import "DSAccount.h"
#import "DSAuthenticationManager.h"
#import "DSBIP39Mnemonic.h"
#import "DSChainManager.h"
#import "DSChainsManager.h"
#import "DSDAPICoreNetworkService.h"
#import "DSDAPIPlatformNetworkService.h"
#import "DSDerivationPath.h"
#import "DSEventManager.h"
#import "DSGovernanceObject.h"
#import "DSGovernanceSyncManager.h"
#import "DSGovernanceVote.h"
#import "DSIdentitiesManager.h"
#import "DSInsightManager.h"
#import "DSMasternodeManager.h"
#import "DSPriceManager.h"
#import "DSShapeshiftManager.h"
#import "DSSporkManager.h"
#import "DSTransactionManager.h"
#import "DSVersionManager.h"
#import "DSWallet.h"
#import "NSMutableData+Dash.h"
#import "NSString+Dash.h"

#import "DSErrorSimulationManager.h"
#import "DSOptionsManager.h"

#import "DSAccountEntity+CoreDataClass.h"
#import "DSAddressEntity+CoreDataProperties.h"
#import "DSBlock.h"
#import "DSChainLockEntity+CoreDataProperties.h"
#import "DSDerivationPathEntity+CoreDataProperties.h"
#import "DSFullBlock.h"
#import "DSGovernanceObjectEntity+CoreDataProperties.h"
#import "DSGovernanceObjectHashEntity+CoreDataProperties.h"
#import "DSGovernanceVoteEntity+CoreDataProperties.h"
#import "DSGovernanceVoteHashEntity+CoreDataProperties.h"
#import "DSLocalMasternode.h"
#import "DSLocalMasternodeEntity+CoreDataProperties.h"
#import "DSMasternodeList.h"
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataProperties.h"
#import "DSPeerEntity+CoreDataProperties.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "DSSporkEntity+CoreDataProperties.h"
#import "DSTransactionEntity+CoreDataProperties.h"
#import "DSTransactionHashEntity+CoreDataProperties.h"
#import "DSTxInputEntity+CoreDataProperties.h"
#import "DSTxOutputEntity+CoreDataProperties.h"
#import "NSArray+Dash.h"
#import "NSData+Dash.h"
#import "NSDate+Utils.h"

#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"

#import "DSPaymentProtocol.h"
#import "DSPaymentRequest.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
#import "NSManagedObject+Sugar.h"
#import "NSPredicate+CBORData.h"
#import "NSPredicate+DSUtils.h"

#import "DSTransaction+Utils.h"
#import "DSTransactionFactory.h"

#import "DSBlockchainIdentityCloseTransition.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBlockchainIdentityTopupTransition.h"
#import "DSBlockchainIdentityUpdateTransition.h"

#import "DSBlockchainIdentity.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityKeyPathEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSMasternodeList.h"
#import "DSMasternodeListEntity+CoreDataProperties.h"
#import "DSPotentialContact.h"
#import "DSPotentialOneWayFriendship.h"
#import "DSQuorumEntry.h"
#import "DSQuorumEntryEntity+CoreDataProperties.h"

#import "DSNetworking.h"

#import "DSCoreDataMigrator.h"

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

- (void)setupDashSyncOnce;

- (void)startSyncForChain:(DSChain *)chain;
- (void)stopSyncForChain:(DSChain *)chain;
- (void)stopSyncAllChains;

- (void)wipePeerDataForChain:(DSChain *)chain inContext:(NSManagedObjectContext *)context;
- (void)wipeBlockchainDataForChain:(DSChain *)chain inContext:(NSManagedObjectContext *)context;
- (void)wipeBlockchainNonTerminalDataForChain:(DSChain *)chain inContext:(NSManagedObjectContext *)context;
- (void)wipeGovernanceDataForChain:(DSChain *)chain inContext:(NSManagedObjectContext *)context;
- (void)wipeMasternodeDataForChain:(DSChain *)chain inContext:(NSManagedObjectContext *)context;
- (void)wipeSporkDataForChain:(DSChain *)chain inContext:(NSManagedObjectContext *)context;
- (void)wipeWalletDataForChain:(DSChain *)chain forceReauthentication:(BOOL)forceReauthentication inContext:(NSManagedObjectContext *)context;

- (uint64_t)dbSize;

#if TARGET_OS_IOS
/// Registration must be complete before the end of application:didFinishLaunchingWithOptions:
- (void)registerBackgroundFetchOnce;

- (void)scheduleBackgroundFetch;
- (void)performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;
#endif

@end

NS_ASSUME_NONNULL_END
