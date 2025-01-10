//
//  DSMasternodeListEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 5/23/19.
//
//

#import "DSChainEntity+CoreDataClass.h"
#import "DSMasternodeListEntity+CoreDataClass.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"


@implementation DSMasternodeListEntity

- (DArcMasternodeList *)masternodeListWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    DMasternodeEntry **masternodes = malloc(self.masternodes.count * sizeof(DMasternodeEntry *));
    DLLMQEntry **quorums = malloc(self.quorums.count * sizeof(DLLMQEntry *));
    uintptr_t masternodes_count = 0;
    for (DSSimplifiedMasternodeEntryEntity *masternodeEntity in self.masternodes) {
        DMasternodeEntry *entry = [masternodeEntity simplifiedMasternodeEntryWithBlockHeightLookup:blockHeightLookup];
        masternodes[masternodes_count] = entry;
        masternodes_count++;
    }
    uintptr_t quorums_count = 0;
    for (DSQuorumEntryEntity *quorumEntity in self.quorums) {
        uint16_t version = quorumEntity.version;
        int16_t llmq_type = quorumEntity.llmqType;
        int32_t llmq_index = quorumEntity.quorumIndex;
        BOOL verified = quorumEntity.verified;
        u256 *llmq_hash = u256_ctor(quorumEntity.quorumHashData);
        BYTES *signers = bytes_ctor(quorumEntity.signersBitset);
        int32_t signers_count = quorumEntity.signersCount;
        BYTES *valid_members = bytes_ctor(quorumEntity.validMembersBitset);
        int32_t valid_members_count = quorumEntity.validMembersCount;
        u384 *public_key = u384_ctor(quorumEntity.quorumPublicKeyData);
        u256 *verification_vector_hash = u256_ctor(quorumEntity.quorumVerificationVectorHashData);
        u768 *threshold_signature = u768_ctor(quorumEntity.quorumThresholdSignatureData);
        u768 *all_commitment_aggregated_signature = u768_ctor(quorumEntity.allCommitmentAggregatedSignatureData);
        // yes this is crazy but this is correct (legacy)
        u256 *entry_hash = u256_ctor(quorumEntity.commitmentHashData);
        DLLMQEntry *entry = dash_spv_crypto_llmq_entry_from_entity(version, llmq_type, llmq_hash, llmq_index, signers, signers_count, valid_members, valid_members_count, public_key, verification_vector_hash, threshold_signature, all_commitment_aggregated_signature, verified, entry_hash);
        quorums[quorums_count] = entry;
        quorums_count++;
    }
    uint32_t block_height = self.block.height;
    u256 *block_hash = u256_ctor(self.block.blockHash);
    u256 *mn_merkle_root = u256_ctor(self.masternodeListMerkleRoot);
    u256 *llmq_merkle_root = u256_ctor(self.quorumListMerkleRoot);
    DMasternodeEntryList *masternodes_vec = DMasternodeEntryListCtor(masternodes_count, masternodes);
    DLLMQEntryList *quorums_vec = DLLMQEntryListCtor(quorums_count, quorums);
//    DSLog(@"•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••");
    DMasternodeList *list = dash_spv_masternode_processor_models_masternode_list_from_entry_pool(block_hash, block_height, mn_merkle_root, llmq_merkle_root, masternodes_vec, quorums_vec);
//    DSLog(@"•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••");

    return std_sync_Arc_dash_spv_masternode_processor_models_masternode_list_MasternodeList_ctor(list);
}

+ (void)deleteAllOnChainEntity:(DSChainEntity *)chainEntity {
    NSArray *masternodeLists = [self objectsInContext:chainEntity.managedObjectContext matching:@"(block.chain == %@)", chainEntity];
    for (DSMasternodeListEntity *masternodeList in masternodeLists) {
        DSLog(@"MasternodeListEntity.deleteAllOnChainEntity: %@", masternodeList);
        [chainEntity.managedObjectContext deleteObject:masternodeList];
    }
}

@end
