//
//  DSMasternodeManager.h
//  DashSync
//
//  Created by Sam Westrich on 6/7/18.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(uint32_t, DSMasternodeSyncCountInfo) {
    DSMasternodeSyncCountInfo_List = 2,
    DSMasternodeSyncCountInfo_MNW = 3,
    DSMasternodeSyncCountInfo_GovernanceObject = 10,
    DSMasternodeSyncCountInfo_GovernanceObjectVote = 11,
};

@class DSPeer,DSChain,DSMasternodeBroadcast,DSMasternodePing;

@interface DSMasternodeManager : NSObject

@property (nonatomic,readonly) DSChain * chain;

-(instancetype)initWithChain:(DSChain*)chain;

-(void)peer:(DSPeer * _Nullable)peer relayedMasternodeBroadcast:(DSMasternodeBroadcast * _Nonnull)masternodeBroadcast;

-(void)peer:(DSPeer * _Nullable)peer relayedMasternodePing:(DSMasternodePing*  _Nonnull)masternodePing;

// Masternodes
-(uint32_t)countForMasternodeSyncCountInfo:(DSMasternodeSyncCountInfo)masternodeSyncCountInfo;
-(void)setCount:(uint32_t)count forMasternodeSyncCountInfo:(DSMasternodeSyncCountInfo)masternodeSyncCountInfo;

@end
