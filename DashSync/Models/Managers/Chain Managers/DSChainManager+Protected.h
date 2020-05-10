//
//  DSChainManager+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 11/21/18.
//

#import "DSChainManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSChainManager ()

@property (nonatomic, readonly) NSTimeInterval lastChainRelayTime;

- (instancetype)initWithChain:(DSChain*)chain;
- (void)resetSyncCountInfo:(DSSyncCountInfo)masternodeSyncCountInfo inContext:(NSManagedObjectContext*)context;
- (void)resetSyncStartHeight;
- (void)restartSyncStartHeight;
- (void)relayedNewItem;
- (void)resetLastRelayedItemTime;
- (void)setCount:(uint32_t)count forSyncCountInfo:(DSSyncCountInfo)masternodeSyncCountInfo inContext:(NSManagedObjectContext*)context;

@end

NS_ASSUME_NONNULL_END
