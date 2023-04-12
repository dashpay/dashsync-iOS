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
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"

@implementation DSMasternodeListEntity

- (DSMasternodeList *)masternodeListWithSimplifiedMasternodeEntryPool:(NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *)simplifiedMasternodeEntries quorumEntryPool:(NSDictionary<NSNumber *, NSDictionary *> *)quorumEntries {
    return [self masternodeListWithSimplifiedMasternodeEntryPool:simplifiedMasternodeEntries quorumEntryPool:quorumEntries withBlockHeightLookup:nil];
}

- (DSMasternodeList *)masternodeListWithSimplifiedMasternodeEntryPool:(NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *)simplifiedMasternodeEntries quorumEntryPool:(NSDictionary<NSNumber *, NSDictionary *> *)quorumEntries withBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    
    /// TODO: it's a BS to collect this stuff into arrays and then to recollect it into dictionaries in the next step...
    NSMutableArray *masternodeEntriesArray = [NSMutableArray array];
    
    for (DSSimplifiedMasternodeEntryEntity *masternodeEntity in self.masternodes) {
        DSSimplifiedMasternodeEntry *masternodeEntry = [simplifiedMasternodeEntries objectForKey:masternodeEntity.providerRegistrationTransactionHash];
        if (!masternodeEntry) {
            masternodeEntry = [masternodeEntity simplifiedMasternodeEntryWithBlockHeightLookup:blockHeightLookup];
        }
        if ([masternodeEntity.providerRegistrationTransactionHash.reverse.hexString isEqual:@"1bde434d4f68064d3108a09443ea45b4a6c6ac1f537a533efc36878cef2eb10f"]) {
            NoTimeLog(@"yeaahh: %@", masternodeEntity.debugDescription);
        } else if ([masternodeEntity.providerRegistrationTransactionHash.hexString isEqual:@"1bde434d4f68064d3108a09443ea45b4a6c6ac1f537a533efc36878cef2eb10f"]) {
            NoTimeLog(@"yeaahh %@", masternodeEntity.debugDescription);
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
        DSLog(@"MasternodeListEntity.deleteAllOnChainEntity: %@", masternodeList);
        [chainEntity.managedObjectContext deleteObject:masternodeList];
    }
}

@end
