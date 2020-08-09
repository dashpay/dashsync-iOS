//
//  DSDashSync.h
//  dashsync
//
//  Created by Sam Westrich on 3/4/18.
//  Copyright © 2019 dashcore. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "DSError.h"

#import "DSReachabilityManager.h"
#import "DSEnvironment.h"
#import "DSPeerManager.h"
#import "DSChain.h"
#import "DSCheckpoint.h"
#import "DSBlockchainIdentity.h"

#import "DSECDSAKey.h"
#import "DSBLSKey.h"
#import "DSKey.h"

#import "DSDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSSimpleIndexedDerivationPath.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSCreditFundingDerivationPath.h"
#import "DSFundsDerivationPath.h"

#import "DSSparseMerkleTree.h"

#import "DSBlockchainIdentity.h"
#import "DSCreditFundingTransaction.h"

#import "DSChainsManager.h"
#import "DSChainManager.h"
#import "DSTransactionManager.h"
#import "DSPriceManager.h"
#import "DSMasternodeManager.h"
#import "DSDAPINetworkService.h"
#import "DSIdentitiesManager.h"
#import "DSGovernanceSyncManager.h"
#import "DSGovernanceObject.h"
#import "DSGovernanceVote.h"
#import "DSSporkManager.h"
#import "DSVersionManager.h"
#import "DSAuthenticationManager.h"
#import "DSInsightManager.h"
#import "DSEventManager.h"
#import "DSShapeshiftManager.h"
#import "DSBIP39Mnemonic.h"
#import "DSWallet.h"
#import "DSAccount.h"
#import "DSDerivationPath.h"
#import "NSString+Dash.h"
#import "NSMutableData+Dash.h"

#import "DSOptionsManager.h"
#import "DSErrorSimulationManager.h"

#import "NSData+Dash.h"
#import "NSArray+Dash.h"
#import "NSDate+Utils.h"
#import "DSLocalMasternodeEntity+CoreDataProperties.h"
#import "DSAddressEntity+CoreDataProperties.h"
#import "DSDerivationPathEntity+CoreDataProperties.h"
#import "DSPeerEntity+CoreDataProperties.h"
#import "DSMerkleBlockEntity+CoreDataProperties.h"
#import "DSGovernanceObjectEntity+CoreDataProperties.h"
#import "DSGovernanceObjectHashEntity+CoreDataProperties.h"
#import "DSGovernanceVoteEntity+CoreDataProperties.h"
#import "DSGovernanceVoteHashEntity+CoreDataProperties.h"
#import "DSSporkEntity+CoreDataProperties.h"
#import "DSTransactionEntity+CoreDataProperties.h"
#import "DSTransactionHashEntity+CoreDataProperties.h"
#import "DSChainLockEntity+CoreDataProperties.h"
#import "DSTxOutputEntity+CoreDataProperties.h"
#import "DSTxInputEntity+CoreDataProperties.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSMasternodeList.h"
#import "DSLocalMasternode.h"
#import "DSSpecialTransactionsWalletHolder.h"

#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateRevocationTransaction.h"

#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
#import "NSManagedObject+Sugar.h"
#import "NSPredicate+DSUtils.h"
#import "NSPredicate+CBORData.h"
#import "DSPaymentRequest.h"
#import "DSPaymentProtocol.h"

#import "DSTransactionFactory.h"
#import "DSTransaction+Utils.h"

#import "DSBlockchainIdentityTopupTransition.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBlockchainIdentityUpdateTransition.h"
#import "DSBlockchainIdentityCloseTransition.h"

#import "DSMasternodeList.h"
#import "DSMasternodeListEntity+CoreDataProperties.h"
#import "DSQuorumEntryEntity+CoreDataProperties.h"
#import "DSQuorumEntry.h"
#import "DSBlockchainIdentity.h"
#import "DSPotentialOneWayFriendship.h"
#import "DSPotentialContact.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSBlockchainIdentityKeyPathEntity+CoreDataClass.h"

#import "DSNetworking.h"

NS_ASSUME_NONNULL_BEGIN

#define SHAPESHIFT_ENABLED 0

//! Project version number for dashsync.
FOUNDATION_EXPORT double DashSyncVersionNumber;

//! Project version string for dashsync.
FOUNDATION_EXPORT const unsigned char DashSyncVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <dashsync/PublicHeader.h>

@interface DashSync : NSObject

@property (nonatomic,assign) BOOL deviceIsJailbroken;

+ (instancetype)sharedSyncController;

/// Registration must be complete before the end of application:didFinishLaunchingWithOptions:
- (void)registerBackgroundFetchOnce;
- (void)setupDashSyncOnce;

-(void)startSyncForChain:(DSChain*)chain;
-(void)stopSyncForChain:(DSChain*)chain;
-(void)stopSyncAllChains;

-(void)wipePeerDataForChain:(DSChain*)chain inContext:(NSManagedObjectContext*)context;
-(void)wipeBlockchainDataForChain:(DSChain*)chain inContext:(NSManagedObjectContext*)context;
-(void)wipeBlockchainNonTerminalDataForChain:(DSChain*)chain inContext:(NSManagedObjectContext*)context;
-(void)wipeGovernanceDataForChain:(DSChain*)chain inContext:(NSManagedObjectContext*)context;
-(void)wipeMasternodeDataForChain:(DSChain*)chain inContext:(NSManagedObjectContext*)context;
-(void)wipeSporkDataForChain:(DSChain*)chain inContext:(NSManagedObjectContext*)context;
-(void)wipeWalletDataForChain:(DSChain*)chain forceReauthentication:(BOOL)forceReauthentication inContext:(NSManagedObjectContext*)context;

-(uint64_t)dbSize;

- (void)scheduleBackgroundFetch;
- (void)performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

@end

NS_ASSUME_NONNULL_END
