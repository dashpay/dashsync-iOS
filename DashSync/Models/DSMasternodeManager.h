//
//  DSMasternodeManager.h
//  DashSync
//
//  Created by Sam Westrich on 6/7/18.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString* _Nonnull const DSMasternodeListDidChangeNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSMasternodeListCountUpdateNotification;

@class DSPeer,DSChain,DSMasternodeBroadcast,DSMasternodePing;

@interface DSMasternodeManager : NSObject

@property (nonatomic,readonly) DSChain * chain;
@property (nonatomic,readonly) NSUInteger recentMasternodeBroadcastHashesCount;
@property (nonatomic,readonly) NSUInteger last3HoursStandaloneBroadcastHashesCount;
@property (nonatomic,readonly) NSUInteger masternodeBroadcastsCount;
@property (nonatomic,assign) NSUInteger totalMasternodeCount;

-(instancetype)initWithChain:(DSChain*)chain;

-(void)peer:(DSPeer * _Nullable)peer relayedMasternodeBroadcast:(DSMasternodeBroadcast * _Nonnull)masternodeBroadcast;

-(void)peer:(DSPeer * _Nullable)peer relayedMasternodePing:(DSMasternodePing*  _Nonnull)masternodePing;

-(void)peer:(DSPeer *)peer hasMasternodeBroadcastHashes:(NSSet*)masternodeBroadcastHashes;

-(void)requestMasternodeBroadcastsFromPeer:(DSPeer*)peer;

@end
