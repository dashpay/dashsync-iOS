//
//  DSGovernanceObjectVote.h
//  DashSync
//
//  Created by Sam Westrich on 6/12/18.
//

#import <Foundation/Foundation.h>

@class DSGovernanceObject,DSMasternodeBroadcast;

@interface DSGovernanceVote : NSObject

@property (nonatomic,strong) DSGovernanceObject * governanceObject;
@property (nonatomic,strong) DSMasternodeBroadcast * masternodeBroadcast;
@property (nonatomic,assign) uint32_t outcome;
@property (nonatomic,assign) uint32_t signal;
@property (nonatomic,readonly) NSData * signature;

@end
