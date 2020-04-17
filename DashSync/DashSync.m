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
    
    [[[DSChainsManager sharedInstance] chainManagerForChain:chain].peerManager connect];
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
    
    [[[DSChainsManager sharedInstance] chainManagerForChain:chain].peerManager disconnect];
}

-(void)wipePeerDataForChain:(DSChain*)chain {
    NSParameterAssert(chain);
    
    [self stopSyncForChain:chain];
    [[[DSChainsManager sharedInstance] chainManagerForChain:chain].peerManager removeTrustedPeerHost];
    [[[DSChainsManager sharedInstance] chainManagerForChain:chain].peerManager clearPeers];
    NSManagedObjectContext * context = [NSManagedObject context];
    [context performBlockAndWait:^{
        DSChainEntity * chainEntity = chain.chainEntity;
        [DSPeerEntity deletePeersForChain:chainEntity];
        [DSPeerEntity saveContext];
        }];
}

-(void)wipeBlockchainDataForChain:(DSChain*)chain {
    NSParameterAssert(chain);
    
    [self stopSyncForChain:chain];
    NSManagedObjectContext * context = [NSManagedObject context];
    [context performBlockAndWait:^{
        DSChainEntity * chainEntity = chain.chainEntity;
        [DSMerkleBlockEntity deleteBlocksOnChain:chainEntity];
        [DSAddressEntity deleteAddressesOnChain:chainEntity];
        [DSTransactionHashEntity deleteTransactionHashesOnChain:chainEntity];
        [DSDerivationPathEntity deleteDerivationPathsOnChain:chainEntity];
        [DSFriendRequestEntity deleteFriendRequestsOnChain:chainEntity];
        [chain wipeBlockchainInfo];
        [DSDashpayUserEntity deleteContactsOnChain:chainEntity];// this must move after wipeBlockchainInfo where blockchain identities are removed
        [DSTransactionEntity saveContext];
        [chain reloadDerivationPaths];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlocksDidChangeNotification object:nil];
        });
    }];
}

-(void)wipeMasternodeDataForChain:(DSChain*)chain {
    NSParameterAssert(chain);
    
    [self stopSyncForChain:chain];
    NSManagedObjectContext * context = [NSManagedObject context];
    [context performBlockAndWait:^{
        [DSChainEntity setContext:context];
        [DSSimplifiedMasternodeEntryEntity setContext:context];
        [DSLocalMasternodeEntity setContext:context];
        [DSQuorumEntryEntity setContext:context];
        DSChainEntity * chainEntity = chain.chainEntity;
        [DSLocalMasternodeEntity deleteAllOnChain:chainEntity];
        [DSSimplifiedMasternodeEntryEntity deleteAllOnChain:chainEntity];
        [DSQuorumEntryEntity deleteAllOnChain:chainEntity];
        [DSMasternodeListEntity deleteAllOnChain:chainEntity];
        DSChainManager * chainManager = [[DSChainsManager sharedInstance] chainManagerForChain:chain];
        [chainManager.masternodeManager wipeMasternodeInfo];
        [DSSimplifiedMasternodeEntryEntity saveContext];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@_%@",chain.uniqueID,LAST_SYNCED_MASTERNODE_LIST]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
        });
    }];
    
}

-(void)wipeSporkDataForChain:(DSChain*)chain {
    NSParameterAssert(chain);
    
    [self stopSyncForChain:chain];
    NSManagedObjectContext * context = [NSManagedObject context];
    [context performBlockAndWait:^{
        DSChainEntity * chainEntity = chain.chainEntity;
        [DSSporkEntity deleteSporksOnChain:chainEntity];
        DSChainManager * chainManager = [[DSChainsManager sharedInstance] chainManagerForChain:chain];
        [chainManager.sporkManager wipeSporkInfo];
        [DSSporkEntity saveContext];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSSporkListDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
        });
    }];
}

-(void)wipeGovernanceDataForChain:(DSChain*)chain {
    NSParameterAssert(chain);
    
    [self stopSyncForChain:chain];
    NSManagedObjectContext * context = [NSManagedObject context];
    [context performBlockAndWait:^{
        DSChainEntity * chainEntity = chain.chainEntity;
        [DSGovernanceObjectHashEntity deleteHashesOnChain:chainEntity];
        [DSGovernanceVoteHashEntity deleteHashesOnChain:chainEntity];
        DSChainManager * chainManager = [[DSChainsManager sharedInstance] chainManagerForChain:chain];
        [chainManager resetSyncCountInfo:DSSyncCountInfo_GovernanceObject];
        [chainManager resetSyncCountInfo:DSSyncCountInfo_GovernanceObjectVote];
        [chainManager.governanceSyncManager wipeGovernanceInfo];
        [DSGovernanceObjectHashEntity saveContext];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@_%@",chain.uniqueID,LAST_SYNCED_GOVERANCE_OBJECTS]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceObjectListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceVotesDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceObjectCountUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceVoteCountUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:chain}];
        });
    }];
}

-(void)wipeWalletDataForChain:(DSChain*)chain forceReauthentication:(BOOL)forceReauthentication {
    NSParameterAssert(chain);
    [self wipeMasternodeDataForChain:chain];
    [self wipeBlockchainDataForChain:chain];
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
    NSString * storeURL = [[NSManagedObject storeURL] path];
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
            NSLog(@"Error scheduling background refresh");
        }
    }
}

- (void)performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    DSChainManager *mainnetManager = [[DSChainsManager sharedInstance] mainnetManager];
    if (mainnetManager.syncProgress >= 1.0) {
        DSDLog(@"Background fetch: already synced");
        
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
        DSDLog(@"Background fetch: protected data available");
        [[[DSChainsManager sharedInstance] mainnetManager].peerManager connect];
    }];
    
    self.syncFinishedNotificationObserver =
    [notificationCenter addObserverForName:DSTransactionManagerSyncFinishedNotification object:nil
                                     queue:nil
                                usingBlock:^(NSNotification *note) {
        DSDLog(@"Background fetch: sync finished");
        [self finishBackgroundFetchWithResult:UIBackgroundFetchResultNewData];
    }];
    
    self.syncFailedNotificationObserver =
    [notificationCenter addObserverForName:DSTransactionManagerSyncFailedNotification
                                    object:nil
                                     queue:nil
                                usingBlock:^(NSNotification *note) {
        DSDLog(@"Background fetch: sync failed");
        [self finishBackgroundFetchWithResult:UIBackgroundFetchResultFailed];
    }];
    
    DSDLog(@"Background fetch: starting");
    [mainnetManager.peerManager connect];
    
    // sync events to the server
    [[DSEventManager sharedEventManager] sync];
}

- (void)backgroundFetchTimedOut {
    const double syncProgress = [[DSChainsManager sharedInstance] mainnetManager].syncProgress;
    DSDLog(@"Background fetch timeout with progress: %f", syncProgress);
    
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
