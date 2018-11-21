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

- (void)resetSyncStartHeight;
- (void)restartSyncStartHeight;

@end

NS_ASSUME_NONNULL_END
