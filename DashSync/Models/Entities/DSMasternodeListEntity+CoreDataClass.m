//
//  DSMasternodeListEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 5/23/19.
//
//

#import "BigIntTypes.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSMasternodeList.h"
#import "DSMasternodeListEntity+CoreDataClass.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"

@implementation DSMasternodeListEntity

- (DSMasternodeList *)masternodeListWithSimplifiedMasternodeEntryPool:(NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *)simplifiedMasternodeEntries quorumEntryPool:(NSDictionary<NSNumber *, NSDictionary *> *)quorumEntries {
    return [self masternodeListWithSimplifiedMasternodeEntryPool:simplifiedMasternodeEntries quorumEntryPool:quorumEntries withBlockHeightLookup:nil];
}

- (DSMasternodeList *)masternodeListWithSimplifiedMasternodeEntryPool:(NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *)simplifiedMasternodeEntries quorumEntryPool:(NSDictionary<NSNumber *, NSDictionary *> *)quorumEntries withBlockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup {
    NSMutableArray *masternodeEntriesArray = [NSMutableArray array];
    for (DSSimplifiedMasternodeEntryEntity *masternodeEntity in self.masternodes) {
        DSSimplifiedMasternodeEntry *masternodeEntry = [simplifiedMasternodeEntries objectForKey:masternodeEntity.providerRegistrationTransactionHash];
        if (!masternodeEntry) {
            masternodeEntry = [masternodeEntity simplifiedMasternodeEntryWithBlockHeightLookup:blockHeightLookup];
        }
        [masternodeEntriesArray addObject:masternodeEntry];
    }
    NSMutableArray *quorumEntriesArray = [NSMutableArray array];
    for (DSQuorumEntryEntity *quorumEntity in self.quorums) {
        DSQuorumEntry *quorumEntry = [[quorumEntries objectForKey:@(quorumEntity.llmqType)] objectForKey:quorumEntity.quorumHashData];
        if (!quorumEntry) {
            quorumEntry = quorumEntity.quorumEntry;
        }
        [quorumEntriesArray addObject:quorumEntry];
    }
    return [DSMasternodeList masternodeListWithSimplifiedMasternodeEntries:masternodeEntriesArray quorumEntries:quorumEntriesArray atBlockHash:self.block.blockHash.UInt256 atBlockHeight:self.block.height withMasternodeMerkleRootHash:self.masternodeListMerkleRoot.UInt256 withQuorumMerkleRootHash:self.quorumListMerkleRoot.UInt256 onChain:self.block.chain.chain];
}

+ (void)deleteAllOnChainEntity:(DSChainEntity *)chainEntity {
    NSArray *masternodeLists = [self objectsInContext:chainEntity.managedObjectContext matching:@"(block.chain == %@)", chainEntity];
    for (DSMasternodeListEntity *masternodeList in masternodeLists) {
        [chainEntity.managedObjectContext deleteObject:masternodeList];
    }
}

@end
