//
//  DSChainManager+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 11/21/18.
//

#import "DSChain.h"
#import "DSChainManager.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(uint16_t, DSChainNotificationType) {
    DSChainNotificationType_Headers = 0,
    DSChainNotificationType_Blocks = 1,
    DSChainNotificationType_SyncState = 2,
};

@interface DSChainManager ()

@property (nonatomic, assign) NSTimeInterval lastChainRelayTime;
@property (nonatomic, assign) DSChainSyncPhase syncPhase;
@property (nonatomic, strong) dispatch_queue_t miningQueue;

- (void)resetChainSyncStartHeight;
- (void)restartChainSyncStartHeight;
- (void)resetTerminalSyncStartHeight;
- (void)restartTerminalSyncStartHeight;
- (instancetype)initWithChain:(DSChain *)chain;
- (void)resetSyncCountInfo:(DSSyncCountInfo)masternodeSyncCountInfo inContext:(NSManagedObjectContext *)context;
- (void)relayedNewItem;
- (void)setCount:(uint32_t)count forSyncCountInfo:(DSSyncCountInfo)masternodeSyncCountInfo inContext:(NSManagedObjectContext *)context;

- (void)wipeMasternodeInfo;

- (void)notify:(NSNotificationName)name userInfo:(NSDictionary *_Nullable)userInfo;
- (void)notifySyncStateChanged;
- (void)notifyMasternodeSyncStateChange:(uint32_t)lastBlockHeihgt storedCount:(uintptr_t)storedCount;


@end

NS_ASSUME_NONNULL_END
