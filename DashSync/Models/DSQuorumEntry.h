//
//  DSQuorumEntry.h
//  DashSync
//
//  Created by Sam Westrich on 5/19/19.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

typedef NS_ENUM(uint16_t, DSLLMQType) {
    DSLLMQType_50_60 = 1, //every 24 blocks
    DSLLMQType_400_60 = 2, //288 blocks
    DSLLMQType_400_85 = 3, //576 blocks
    DSLLMQType_5_60 = 100 //24 blocks
};

@class DSQuorumEntryEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumEntry : NSObject

@property (nonatomic, assign) DSLLMQType llmqType;
@property (nonatomic, assign) UInt256 quorumHash;
@property (nonatomic, assign) UInt384 quorumPublicKey;
@property (nonatomic, readonly) DSQuorumEntryEntity * matchingQuorumEntryEntity;

@end

NS_ASSUME_NONNULL_END
