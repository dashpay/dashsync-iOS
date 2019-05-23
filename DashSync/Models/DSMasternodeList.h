//
//  DSMasternodeList.h
//  DashSync
//
//  Created by Sam Westrich on 5/20/19.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DSSimplifiedMasternodeEntry,DSChain;

@interface DSMasternodeList : NSObject

@property (nonatomic,readonly) NSArray * simplifiedMasternodeEntries;
@property (nonatomic,readonly) UInt256 blockHash;
@property (nonatomic,readonly) uint32_t height;
@property (nonatomic,readonly) UInt256 merkleRoot;
@property (nonatomic,readonly) uint64_t masternodeCount;
@property (nonatomic,readonly) DSChain * chain;
@property (nonatomic,readonly) NSArray * reversedRegistrationTransactionHashes;
@property (nonatomic,readonly) NSMutableDictionary<NSData*,DSSimplifiedMasternodeEntry*> *simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash;

+(instancetype)masternodeListWithSimplifiedMasternodeEntries:(NSArray<DSSimplifiedMasternodeEntry*>*)simplifiedMasternodeEntries atBlockHash:(UInt256)blockHash onChain:(DSChain*)chain;

+(instancetype)masternodeListWithSimplifiedMasternodeEntriesDictionary:(NSDictionary<NSData*,DSSimplifiedMasternodeEntry*>*)simplifiedMasternodeEntries atBlockHash:(UInt256)blockHash onChain:(DSChain*)chain;

+(instancetype)masternodeListAtBlockHash:(UInt256)blockHash fromBaseMasternodeList:(DSMasternodeList* _Nullable)baseMasternodeList addedMasternodes:(NSDictionary*)addedMasternodes removedMasternodeHashes:(NSArray*)removedMasternodes modifiedMasternodes:(NSDictionary*)modifiedMasternodes onChain:(DSChain*)chain;

-(NSArray<DSSimplifiedMasternodeEntry*>*)masternodesForQuorumHash:(UInt256)quorumHash quorumCount:(NSUInteger)quorumCount;

@end

NS_ASSUME_NONNULL_END
