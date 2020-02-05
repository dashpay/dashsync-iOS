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
- (void)resetSyncCountInfo:(DSSyncCountInfo)masternodeSyncCountInfo;
- (void)resetSyncStartHeight;
- (void)restartSyncStartHeight;
- (void)relayedNewItem;
- (void)resetLastRelayedItemTime;
- (void)setCount:(uint32_t)count forSyncCountInfo:(DSSyncCountInfo)masternodeSyncCountInfo;

@end

NS_ASSUME_NONNULL_END
