//
//  DSChainManager+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 11/21/18.
//

#import "DSChainManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSChainManager ()

@property (nonatomic, assign) NSTimeInterval lastChainRelayTime;

- (instancetype)initWithChain:(DSChain *)chain;
- (void)resetSyncCountInfo:(DSSyncCountInfo)masternodeSyncCountInfo inContext:(NSManagedObjectContext *)context;
- (void)resetChainSyncStartHeight;
- (void)restartChainSyncStartHeight;
- (void)resetTerminalSyncStartHeight;
- (void)restartTerminalSyncStartHeight;
- (void)relayedNewItem;
- (void)resetLastRelayedItemTime;
- (void)setCount:(uint32_t)count forSyncCountInfo:(DSSyncCountInfo)masternodeSyncCountInfo inContext:(NSManagedObjectContext *)context;

- (BOOL)shouldRequestMerkleBlocksForZoneBetweenHeight:(uint32_t)blockHeight andEndHeight:(uint32_t)endBlockHeight;
- (BOOL)shouldRequestMerkleBlocksForZoneAfterHeight:(uint32_t)blockHeight;

- (void)wipeMasternodeInfo;

@property (nonatomic, assign) DSChainSyncPhase syncPhase;

- (void)assignSyncWeights;

@end

NS_ASSUME_NONNULL_END
