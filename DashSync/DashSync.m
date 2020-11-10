//
//  DSDashSync.m
//  dashsync
//
//  Created by Sam Westrich on 3/4/18.
//  Copyright © 2019 dashcore. All rights reserved.
//

#import "DashSync.h"
#import <BackgroundTasks/BackgroundTasks.h>
#import <sys/stat.h>
#import <mach-o/dyld.h>
#import "NSManagedObject+Sugar.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSPeerEntity+CoreDataClass.h"
#import "DSLocalMasternodeEntity+CoreDataClass.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSMasternodeListEntity+CoreDataClass.h"
#import "DSPeerManager+Protected.h"
#import "DSSporkManager+Protected.h"
#import "DSMasternodeManager+Protected.h"
#import "DSChainManager+Protected.h"
#import "DSChain+Protected.h"
#import "DSDataController.h"

NS_ASSUME_NONNULL_BEGIN

/*
 Notice on iOS 13+ Background Task debugging:
 
 e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"org.dashcore.dashsync.backgroundblocksync"]

 e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"org.dashcore.dashsync.backgroundblocksync"]
 */

static NSString * const BG_TASK_REFRESH_IDENTIFIER = @"org.dashcore.dashsync.backgroundblocksync";

@interface DashSync ()

@property (nullable, nonatomic, strong) id protectedDataNotificationObserver;
@property (nullable, nonatomic, strong) id syncFinishedNotificationObserver;
@property (nullable, nonatomic, strong) id syncFailedNotificationObserver;
@property (nullable, nonatomic, copy) void (^backgroundFetchCompletion)(UIBackgroundFetchResult);

@end

@implementation DashSync

+ (instancetype)sharedSyncController
{
    static DashSync *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (void)registerBackgroundFetchOnce {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // use background fetch to stay synced with the blockchain
        if (@available(iOS 13.0, *)) {
            BGTaskScheduler *taskScheduler = [BGTaskScheduler sharedScheduler];
            const BOOL registerSuccess =
            [taskScheduler registerForTaskWithIdentifier:BG_TASK_REFRESH_IDENTIFIER
                                                                  usingQueue:nil
                                                               launchHandler:^(BGTask *task) {
                [self scheduleBackgroundFetch];
                
                [task setExpirationHandler:^{
                    [self backgroundFetchTimedOut];
                }];
                
                [self performFetchWithCompletionHandler:^(UIBackgroundFetchResult backgroundFetchResult) {
                    const BOOL success = backgroundFetchResult == UIBackgroundFetchResultNewData;
                    [task setTaskCompletedWithSuccess:success];
                }];
            }];
            
            NSAssert(registerSuccess, @"Add background task identifier '%@' to the App's Info.plist",
                     BG_TASK_REFRESH_IDENTIFIER);
        } else {
            [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
        }
    });
}

- (void)setupDashSyncOnce {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if ([[DSOptionsManager sharedInstance] retrievePriceInfo]) {
                    [[DSPriceManager sharedInstance] startExchangeRateFetching];
                }
                // start the event manager
                [[DSEventManager sharedEventManager] up];
                
                struct stat s;
                self.deviceIsJailbroken = (stat("/bin/sh", &s) == 0) ? YES : NO; // if we can see /bin/sh, the app isn't sandboxed
                
                // some anti-jailbreak detection tools re-sandbox apps, so do a secondary check for any MobileSubstrate dyld images
                for (uint32_t count = _dyld_image_count(), i = 0; i < count && !self.deviceIsJailbroken; i++) {
                    if (strstr(_dyld_get_image_name(i), "MobileSubstrate")) self.deviceIsJailbroken = YES;
                }
                
        #if TARGET_IPHONE_SIMULATOR
                self.deviceIsJailbroken = NO;
        #endif
    });
}

-(void)startSyncForChain:(DSChain*)chain
{
    NSParameterAssert(chain);
    
    [[[DSChainsManager sharedInstance] chainManagerForChain:chain] startSync];
}

-(void)stopSyncAllChains {
    NSArray * chains = [[DSChainsManager sharedInstance] chains];
    for (DSChain * chain in chains) {
        [[[DSChainsManager sharedInstance] chainManagerForChain:chain].peerManager disconnect];
    }
}

-(void)stopSyncForChain:(DSChain*)chain
{
    NSParameterAssert(chain);
    
    [[[DSChainsManager sharedInstance] chainManagerForChain:chain] stopSync];
}

-(void)wipePeerDataForChain:(DSChain*)chain inContext:(NSManagedObjectContext*)context  {
    NSParameterAssert(chain);
    
    [self stopSyncForChain:chain];
    [[[DSChainsManager sharedInstance] chainManagerForChain:chain].peerManager removeTrustedPeerHost];
    [[[DSChainsManager sharedInstance] chainManagerForChain:chain].peerManager clearPeers];
    [context performBlockAndWait:^{
        DSChainEntity * chainEntity = [chain chainEntityInContext:context];
        [DSPeerEntity deletePeersForChainEntity:chainEntity];
        [context ds_save];
    }];
}

-(void)wipeBlockchainDataForChain:(DSChain*)chain inContext:(NSManagedObjectContext*)context {
    NSParameterAssert(chain);
    
    [self stopSyncForChain:chain];
    [context performBlockAndWait:^{
        DSChainEntity * chainEntity = [chain chainEntityInContext:context];
        chainEntity.syncBlockTimestamp = 0;
        chainEntity.syncBlockHash = nil;
        chainEntity.syncBlockHeight = 0;
        chainEntity.syncLocators = nil;
        
        [DSMerkleBlockEntity deleteBlocksOnChainEntity:chainEntity];
        [DSAddressEntity deleteAddressesOnChainEntity:chainEntity];
        [DSTransactionHashEntity deleteTransactionHashesOnChainEntity:chainEntity];
        [DSDerivationPathEntity deleteDerivationPathsOnChainEntity:chainEntity];
        [DSFriendRequestEntity deleteFriendRequestsOnChainEntity:chainEntity];
        [chain wipeBlockchainInfoInContext:context];
        [chain.chainManager restartChainSyncStartHeight];
        [chain.chainManager restartTerminalSyncStartHeight];
        chain.chainManager.syncPhase = DSChainSyncPhase_InitialTerminalBlocks;
        [DSBlockchainIdentityEntity deleteBlockchainIdentitiesOnChainEntity:chainEntity];
        [DSDashpayUserEntity deleteContactsOnChainEntity:chainEntity];// this must move after wipeBlockchainInfo where blockchain identities are removed
        [context ds_save];
        [chain reloadDerivationPaths];
        [chain.chainManager assingSyncWeights];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainChainSyncBlocksDidChangeNotification object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainTerminalBlocksDidChangeNotification object:nil];
        });
    }];
}

-(void)wipeBlockchainNonTerminalDataForChain:(DSChain*)chain inContext:(NSManagedObjectContext*)context {
    NSParameterAssert(chain);
    
    [self stopSyncForChain:chain];
    [context performBlockAndWait:^{
        DSChainEntity * chainEntity = [chain chainEntityInContext:context];
        chainEntity.syncBlockTimestamp = 0;
        chainEntity.syncBlockHash = nil;
        chainEntity.syncBlockHeight = 0;
        chainEntity.syncLocators = nil;
        [DSAddressEntity deleteAddressesOnChainEntity:chainEntity];
        [DSTransactionHashEntity deleteTransactionHashesOnChainEntity:chainEntity];
        [DSDerivationPathEntity deleteDerivationPathsOnChainEntity:chainEntity];
        [DSFriendRequestEntity deleteFriendRequestsOnChainEntity:chainEntity];
        [chain wipeBlockchainNonTerminalInfoInContext:context];
        [chain.chainManager restartChainSyncStartHeight];
        [DSBlockchainIdentityEntity deleteBlockchainIdentitiesOnChainEntity:chainEntity];
        [DSDashpayUserEntity deleteContactsOnChainEntity:chainEntity];// this must move after wipeBlockchainInfo where blockchain identities are removed
        [context ds_save];
        [chain reloadDerivationPaths];
        [chain.chainManager assingSyncWeights];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainChainSyncBlocksDidChangeNotification object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainTerminalBlocksDidChangeNotification object:nil];
        });
    }];
}

-(void)wipeMasternodeDataForChain:(DSChain*)chain inContext:(NSManagedObjectContext*)context {
    NSParameterAssert(chain);
    
    [self stopSyncForChain:chain];
    [context performBlockAndWait:^{
        DSChainEntity * chainEntity = [chain chainEntityInContext:context];
        [DSLocalMasternodeEntity deleteAllOnChainEntity:chainEntity];
        [DSSimplifiedMasternodeEntryEntity deleteAllOnChainEntity:chainEntity];
        [DSQuorumEntryEntity deleteAllOnChainEntity:chainEntity];
        [DSMasternodeListEntity deleteAllOnChainEntity:chainEntity];
        DSChainManager * chainManager = [[DSChainsManager sharedInstance] chainManagerForChain:chain];
        [chainManager.masternodeManager wipeMasternodeInfo];
        [context ds_save];
        [chain.chainManager assingSyncWeights];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@_%@",chain.uniqueID,LAST_SYNCED_MASTERNODE_LIST]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
        });
    }];
    
}

-(void)wipeSporkDataForChain:(DSChain*)chain inContext:(NSManagedObjectContext*)context {
    NSParameterAssert(chain);
    
    [self stopSyncForChain:chain];
    [context performBlockAndWait:^{
        DSChainEntity * chainEntity = [chain chainEntityInContext:context];
        [DSSporkEntity deleteSporksOnChainEntity:chainEntity];
        DSChainManager * chainManager = [[DSChainsManager sharedInstance] chainManagerForChain:chain];
        [chainManager.sporkManager wipeSporkInfo];
        [context ds_save];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSSporkListDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
        });
    }];
}

-(void)wipeGovernanceDataForChain:(DSChain*)chain inContext:(NSManagedObjectContext*)context {
    NSParameterAssert(chain);
    
    [self stopSyncForChain:chain];
    [context performBlockAndWait:^{
        DSChainManager * chainManager = [[DSChainsManager sharedInstance] chainManagerForChain:chain];
        [chainManager resetSyncCountInfo:DSSyncCountInfo_GovernanceObject inContext:context];
        [chainManager resetSyncCountInfo:DSSyncCountInfo_GovernanceObjectVote inContext:context];
        [chainManager.governanceSyncManager wipeGovernanceInfo];
        [context ds_save];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@_%@",chain.uniqueID,LAST_SYNCED_GOVERANCE_OBJECTS]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceObjectListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceVotesDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceObjectCountUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceVoteCountUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
        });
    }];
}

-(void)wipeWalletDataForChain:(DSChain*)chain forceReauthentication:(BOOL)forceReauthentication inContext:(NSManagedObjectContext*)context {
    NSParameterAssert(chain);
    [self wipeMasternodeDataForChain:chain inContext:context];
    [self wipeBlockchainDataForChain:chain inContext:context];
    if (!forceReauthentication && [[DSAuthenticationManager sharedInstance] didAuthenticate]) {
        [chain wipeWalletsAndDerivatives];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainStandaloneAddressesDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainWalletsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainStandaloneDerivationPathsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
        });
    } else {
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:@"Wipe wallets" usingBiometricAuthentication:NO alertIfLockout:NO completion:^(BOOL authenticatedOrSuccess, BOOL usedBiometrics, BOOL cancelled) {
            if (authenticatedOrSuccess) {
                [chain wipeWalletsAndDerivatives];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:DSChainStandaloneAddressesDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
                    [[NSNotificationCenter defaultCenter] postNotificationName:DSChainWalletsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
                    [[NSNotificationCenter defaultCenter] postNotificationName:DSChainStandaloneDerivationPathsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
                });
            }
        }];
    }
    
}

-(uint64_t)dbSize {
    NSString * storeURL = [[DSDataController storeURL] path];
    NSError * attributesError = nil;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:storeURL error:&attributesError];
    if (attributesError) {
        return 0;
    } else {
        NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
        long long fileSize = [fileSizeNumber longLongValue];
        return fileSize;
    }
}

- (void)scheduleBackgroundFetch {
    if (@available(iOS 13.0,*)) {
        BGAppRefreshTaskRequest *request = [[BGAppRefreshTaskRequest alloc] initWithIdentifier:BG_TASK_REFRESH_IDENTIFIER];
        // Fetch no earlier than 15 minutes from now
        request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:15.0 * 60.0];
        
        NSError *error = nil;
        [[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error];
        if (error) {
            DSLog(@"Error scheduling background refresh");
        }
    }
}

- (void)performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    DSChainManager *mainnetManager = [[DSChainsManager sharedInstance] mainnetManager];
    if (mainnetManager.chainSyncProgress >= 1.0) {
        DSLog(@"Background fetch: already synced");
        
        if (completionHandler) {
            completionHandler(UIBackgroundFetchResultNoData);
        }
        
        return;
    }
    
    self.backgroundFetchCompletion = completionHandler;
    
    if (@available(iOS 13.0, *)) {
        // NOP
        // The expirationHandler of BGTask will be called
    }
    else {
        // timeout after 25 seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self backgroundFetchTimedOut];
        });
    }
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    self.protectedDataNotificationObserver =
    [notificationCenter addObserverForName:UIApplicationProtectedDataDidBecomeAvailable
                                    object:nil
                                     queue:nil
                                usingBlock:^(NSNotification *note) {
        DSLog(@"Background fetch: protected data available");
        [[[DSChainsManager sharedInstance] mainnetManager] startSync];
    }];
    
    self.syncFinishedNotificationObserver =
    [notificationCenter addObserverForName:DSChainManagerSyncFinishedNotification object:nil
                                     queue:nil
                                usingBlock:^(NSNotification *note) {
        DSLog(@"Background fetch: sync finished");
        [self finishBackgroundFetchWithResult:UIBackgroundFetchResultNewData];
    }];
    
    self.syncFailedNotificationObserver =
    [notificationCenter addObserverForName:DSChainManagerSyncFailedNotification
                                    object:nil
                                     queue:nil
                                usingBlock:^(NSNotification *note) {
        DSLog(@"Background fetch: sync failed");
        [self finishBackgroundFetchWithResult:UIBackgroundFetchResultFailed];
    }];
    
    DSLog(@"Background fetch: starting");
    [mainnetManager startSync];
    
    // sync events to the server
    [[DSEventManager sharedEventManager] sync];
}

- (void)backgroundFetchTimedOut {
    const double syncProgress = [[DSChainsManager sharedInstance] mainnetManager].chainSyncProgress;
    DSLog(@"Background fetch timeout with progress: %f", syncProgress);
    
    const UIBackgroundFetchResult fetchResult = syncProgress > 0.1
        ? UIBackgroundFetchResultNewData
        : UIBackgroundFetchResultFailed;
    [self finishBackgroundFetchWithResult:fetchResult];
    
    // TODO: disconnect
}

- (void)finishBackgroundFetchWithResult:(UIBackgroundFetchResult)fetchResult {
    if (self.backgroundFetchCompletion) {
        self.backgroundFetchCompletion(fetchResult);
    }
    self.backgroundFetchCompletion = nil;
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    if (self.protectedDataNotificationObserver) {
        [notificationCenter removeObserver:self.protectedDataNotificationObserver];
    }
    if (self.syncFinishedNotificationObserver) {
        [notificationCenter removeObserver:self.syncFinishedNotificationObserver];
    }
    if (self.syncFailedNotificationObserver) {
        [notificationCenter removeObserver:self.syncFailedNotificationObserver];
    }
    
    self.protectedDataNotificationObserver = nil;
    self.syncFinishedNotificationObserver = nil;
    self.syncFailedNotificationObserver = nil;
}

@end

NS_ASSUME_NONNULL_END
