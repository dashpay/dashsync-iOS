//
//  DSMasternodeManager.h
//  DashSync
//
//  Created by Sam Westrich on 5/29/18.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString* _Nonnull const DSMasternodeListChangedNotification;

typedef NS_ENUM(NSUInteger, DSMasternodeSyncCountInfo) {
    DSMasternodeSyncCountInfo_List = 2,
    DSMasternodeSyncCountInfo_MNW = 3,
    DSMasternodeSyncCountInfo_GovernanceObject = 10,
    DSMasternodeSyncCountInfo_GovernanceObjectVote = 11,
};

@interface DSMasternodeManager : NSObject

+(instancetype)sharedInstance;

-(uint32_t)countForMasternodeSyncCountInfo:(DSMasternodeSyncCountInfo)masternodeSyncCountInfo;
-(void)setCount:(uint32_t)count forMasternodeSyncCountInfo:(DSMasternodeSyncCountInfo)masternodeSyncCountInfo;

@end
