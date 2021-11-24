#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Maximum size, in bytes, of a vector we are allowed to decode
 */
#define MAX_VEC_SIZE 4000000

#define MN_ENTRY_PAYLOAD_LENGTH 151

enum LLMQType {
  Llmqtype5060 = 1,
  Llmqtype40060 = 2,
  Llmqtype40085 = 3,
  Llmqtype10067 = 4,
  Llmqtype560 = 100,
  Llmqtype1060 = 101,
};
typedef uint8_t LLMQType;

/**
 * A script Opcode
 */
typedef struct All All;

typedef uint32_t (*BlockHeightLookup)(uint8_t (*block_hash)[32], void *context);

typedef struct OperatorPublicKey {
  uint8_t (*block_hash)[32];
  uint32_t block_height;
  uint8_t (*key)[48];
} OperatorPublicKey;

typedef struct MasternodeEntryHash {
  uint8_t (*block_hash)[32];
  uint32_t block_height;
  uint8_t (*hash)[32];
} MasternodeEntryHash;

typedef struct Validity {
  uint8_t (*block_hash)[32];
  uint32_t block_height;
  bool is_valid;
} Validity;

typedef struct MasternodeEntry {
  uint8_t (*confirmed_hash)[32];
  uint8_t (*confirmed_hash_hashed_with_provider_registration_transaction_hash)[32];
  bool confirmed_hash_hashed_with_provider_registration_transaction_hash_exists;
  bool is_valid;
  uint8_t (*key_id_voting)[20];
  uint32_t known_confirmed_at_height;
  bool known_confirmed_at_height_exists;
  uint8_t (*masternode_entry_hash)[32];
  uint8_t (*operator_public_key)[48];
  struct OperatorPublicKey **previous_operator_public_keys;
  uintptr_t previous_operator_public_keys_count;
  struct MasternodeEntryHash **previous_masternode_entry_hashes;
  uintptr_t previous_masternode_entry_hashes_count;
  struct Validity **previous_validity;
  uintptr_t previous_validity_count;
  uint8_t (*provider_registration_transaction_hash)[32];
  uint8_t (*ip_address)[16];
  uint16_t port;
  uint32_t update_height;
} MasternodeEntry;

typedef struct QuorumEntry {
  uint8_t (*all_commitment_aggregated_signature)[96];
  uint8_t (*commitment_hash)[32];
  bool commitment_hash_exists;
  uintptr_t length;
  LLMQType llmq_type;
  uint8_t (*quorum_entry_hash)[32];
  uint8_t (*quorum_hash)[32];
  uint8_t (*quorum_public_key)[48];
  uint8_t (*quorum_threshold_signature)[96];
  uint8_t (*quorum_verification_vector_hash)[32];
  bool saved;
  const uint8_t *signers_bitset;
  uintptr_t signers_bitset_length;
  uint64_t signers_count;
  const uint8_t *valid_members_bitset;
  uintptr_t valid_members_bitset_length;
  uint64_t valid_members_count;
  bool verified;
  uint16_t version;
} QuorumEntry;

typedef struct LLMQMap {
  uint8_t (**keys)[32];
  struct QuorumEntry **values;
  uintptr_t count;
} LLMQMap;

typedef struct MasternodeList {
  uint8_t (*block_hash)[32];
  uint32_t known_height;
  uint8_t (*masternode_merkle_root)[32];
  bool masternode_merkle_root_exists;
  uint8_t (*quorum_merkle_root)[32];
  bool quorum_merkle_root_exists;
  uint8_t (**masternodes_keys)[32];
  struct MasternodeEntry **masternodes_values;
  uintptr_t masternodes_count;
  uint8_t **quorums_keys;
  struct LLMQMap **quorums_values;
  uintptr_t quorums_count;
} MasternodeList;

/**
 * This types reflected for FFI
 */
typedef struct MasternodeListExt {
  struct MasternodeList *list;
  bool exists;
} MasternodeListExt;

typedef struct MndiffResult {
  bool found_coinbase;
  bool valid_coinbase;
  bool root_mn_list_valid;
  bool root_quorum_list_valid;
  bool valid_quorums;
  struct MasternodeListExt *masternode_list;
  uint8_t (**added_masternodes_keys)[32];
  struct MasternodeEntry **added_masternodes_values;
  uintptr_t added_masternodes_count;
  uint8_t (**modified_masternodes_keys)[32];
  struct MasternodeEntry **modified_masternodes_values;
  uintptr_t modified_masternodes_count;
  uint8_t **added_quorums_keys;
  struct LLMQMap **added_quorums_values;
  uintptr_t added_quorums_count;
  uint8_t (**needed_masternode_lists)[32];
  uintptr_t needed_masternode_lists_count;
} MndiffResult;

typedef struct MasternodeListExt *(*MasternodeListLookup)(uint8_t (*block_hash)[32], void *context);

typedef void (*AddInsightBlockingLookup)(uint8_t (*block_hash)[32], void *context);

typedef bool (*ShouldProcessQuorumTypeCallback)(uint8_t quorum_type, void *context);

typedef struct QuorumValidationData {
  uint8_t (**items)[48];
  uintptr_t count;
  uint8_t (*commitment_hash)[32];
  uint8_t (*all_commitment_aggregated_signature)[96];
  uint8_t (*quorum_threshold_signature)[96];
  uint8_t (*quorum_public_key)[48];
} QuorumValidationData;

typedef bool (*ValidateQuorumCallback)(struct QuorumValidationData *data, void *context);

































































































































































































































































































































































































































































































































void test_bhl2(BlockHeightLookup callback, void *context);

struct MndiffResult *process_diff(const uint8_t *c_array,
                                  uintptr_t length,
                                  struct MasternodeListExt *base_masternode_list,
                                  MasternodeListLookup masternode_list_lookup,
                                  const uint8_t *merkle_root,
                                  bool use_insight_as_backup,
                                  AddInsightBlockingLookup add_insight_lookup,
                                  ShouldProcessQuorumTypeCallback should_process_quorum_of_type,
                                  ValidateQuorumCallback validate_quorum_callback,
                                  BlockHeightLookup block_height_lookup,
                                  void *context);
