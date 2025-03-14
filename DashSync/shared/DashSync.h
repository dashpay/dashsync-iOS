//
//  DSDashSync.h
//  dashsync
//
//  Created by Sam Westrich on 3/4/18.
//  Copyright © 2019 dashcore. All rights reserved.
//

#import "dash_shared_core.h"
#import "DSError.h"

#import "DSIdentity.h"
#import "DSChain.h"
#import "DSChain+Identity.h"
#import "DSChain+Params.h"
#import "DSChain+Wallet.h"
#import "DSChain+Transaction.h"
#import "DSCheckpoint.h"
#import "DSEnvironment.h"
#import "DSPeerManager.h"
#import "DSReachabilityManager.h"

#import "DSAuthenticationKeysDerivationPath.h"
#import "DSAssetLockDerivationPath.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSFundsDerivationPath.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSSimpleIndexedDerivationPath.h"

#import "DSSparseMerkleTree.h"

#import "DSIdentity.h"
#import "DSIdentity+ContactRequest.h"
#import "DSIdentity+Friendship.h"
#import "DSIdentity+Profile.h"
#import "DSIdentity+Username.h"
#import "DSInvitation.h"

#import "DSAccount.h"
#import "DSAuthenticationManager.h"
#import "DSBIP39Mnemonic.h"
#import "DSChainManager.h"
#import "DSChainsManager.h"
#import "DSDerivationPath.h"
#import "DSEventManager.h"
#import "DSGovernanceObject.h"
#import "DSGovernanceSyncManager.h"
#import "DSGovernanceVote.h"
#import "DSIdentitiesManager.h"
#import "DSInsightManager.h"
#import "DSKeyManager.h"
//#import "DSMasternodeListStore.h"
#import "DSMasternodeListService.h"
#import "DSMasternodeListDiffService.h"
#import "DSQuorumRotationService.h"
#import "DSMasternodeManager.h"
#import "DSMasternodeManager+LocalMasternode.h"
#import "DSPriceManager.h"
#import "DSShapeshiftManager.h"
#import "DSSporkManager.h"
#import "DSSyncState.h"
#import "DSTransactionManager.h"
#import "DSVersionManager.h"
#import "DSWallet.h"
#import "DSWallet+Identity.h"
#import "DSWallet+Invitation.h"

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
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataProperties.h"
#import "DSPeerEntity+CoreDataProperties.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "DSSporkEntity+CoreDataProperties.h"
#import "DSTransactionEntity+CoreDataProperties.h"
#import "DSTransactionHashEntity+CoreDataProperties.h"
#import "DSTxInputEntity+CoreDataProperties.h"
#import "DSTxOutputEntity+CoreDataProperties.h"
#import "NSArray+Dash.h"
#import "NSData+DSHash.h"
#import "NSDate+Utils.h"

#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"

#import "DSPaymentProtocol.h"
#import "DSPaymentRequest.h"
#import "NSManagedObject+Sugar.h"
#import "NSPredicate+DSUtils.h"

#import "DSTransaction+Utils.h"
#import "DSTransactionFactory.h"
#import "DSTransactionInput.h"
#import "DSTransactionOutput.h"
#import "DSIdentity.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityKeyPathEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSPotentialContact.h"
#import "DSPotentialOneWayFriendship.h"

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
