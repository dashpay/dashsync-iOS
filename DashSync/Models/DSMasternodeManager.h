//
//  DSMasternodeManager.h
//  DashSync
//
//  Created by Sam Westrich on 6/7/18.
//

#import <Foundation/Foundation.h>

@class DSPeer,DSChain,DSMasternodeBroadcast;

@interface DSMasternodeManager : NSObject

@property (nonatomic,readonly) DSChain * chain;

-(instancetype)initWithChain:(DSChain*)chain;

-(void)peer:(DSPeer * _Nullable)peer relayedMasternodeBroadcast:(DSMasternodeBroadcast * _Nonnull)masternodeBroadcast;

@end
