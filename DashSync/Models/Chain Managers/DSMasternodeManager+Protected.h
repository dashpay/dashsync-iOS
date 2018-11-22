//
//  DSMasternodeManager+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 11/22/18.
//

#import "DSMasternodeManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeManager (Protected)

-(void)getMasternodeList;

-(void)peer:(DSPeer *)peer relayedMasternodeDiffMessage:(NSData*)masternodeDiffMessage;

@end

NS_ASSUME_NONNULL_END
