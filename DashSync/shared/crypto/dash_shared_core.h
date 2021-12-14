#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Maximum size, in bytes, of a vector we are allowed to decode
 */
#define MAX_VEC_SIZE 4000000

#define MN_ENTRY_PAYLOAD_LENGTH 151

#define QUORUM_DEFAULT_VERSION 1

#define QUORUM_INDEXED_VERSION 2

enum LLMQType {
  Llmqtype50_60 = 1,
  Llmqtype400_60 = 2,
  Llmqtype400_85 = 3,
  Llmqtype100_67 = 4,
  Llmqtype60_80 = 5,
  Llmqtype5_60 = 100,
  Llmqtype10_60 = 101,
};
typedef uint8_t LLMQType;

/**
 * A script Opcode
 */
typedef struct All All;

typedef struct MasternodeEntryHash {
  uint8_t block_hash[32];
  uint32_t block_height;
  uint8_t hash[32];
} MasternodeEntryHash;

typedef struct OperatorPublicKey {
  uint8_t block_hash[32];
  uint32_t block_height;
  uint8_t key[48];
} OperatorPublicKey;

typedef struct Validity {
  uint8_t block_hash[32];
  uint32_t block_height;
  bool is_valid;
} Validity;

typedef struct MasternodeEntry {
  uint8_t (*confirmed_hash)[32];
  uint8_t (*confirmed_hash_hashed_with_provider_registration_transaction_hash)[32];
  bool is_valid;
  uint8_t (*key_id_voting)[20];
  uint32_t known_confirmed_at_height;
  uint8_t (*masternode_entry_hash)[32];
  uint8_t (*operator_public_key)[48];
  struct MasternodeEntryHash *previous_masternode_entry_hashes;
  uintptr_t previous_masternode_entry_hashes_count;
  struct OperatorPublicKey *previous_operator_public_keys;
  uintptr_t previous_operator_public_keys_count;
  struct Validity *previous_validity;
  uintptr_t previous_validity_count;
  uint8_t (*provider_registration_transaction_hash)[32];
  uint8_t (*ip_address)[16];
  uint16_t port;
  uint32_t update_height;
} MasternodeEntry;

typedef struct QuorumEntry {
  uint8_t (*all_commitment_aggregated_signature)[96];
  uint8_t (*commitment_hash)[32];
  uintptr_t length;
  LLMQType llmq_type;
  uint8_t (*quorum_entry_hash)[32];
  uint8_t (*quorum_hash)[32];
  uint32_t quorum_index;
  uint8_t (*quorum_public_key)[48];
  uint8_t (*quorum_threshold_signature)[96];
  uint8_t (*quorum_verification_vector_hash)[32];
  bool saved;
  uint8_t *signers_bitset;
  uintptr_t signers_bitset_length;
  uint64_t signers_count;
  uint8_t *valid_members_bitset;
  uintptr_t valid_members_bitset_length;
  uint64_t valid_members_count;
  bool verified;
  uint16_t version;
} QuorumEntry;

typedef struct LLMQMap {
  uint8_t llmq_type;
  struct QuorumEntry **values;
  uintptr_t count;
} LLMQMap;

/**
 * This types reflected for FFI
 */
typedef struct MasternodeList {
  uint8_t (*block_hash)[32];
  uint32_t known_height;
  uint8_t (*masternode_merkle_root)[32];
  uint8_t (*quorum_merkle_root)[32];
  struct MasternodeEntry **masternodes;
  uintptr_t masternodes_count;
  struct LLMQMap **quorum_type_maps;
  uintptr_t quorum_type_maps_count;
} MasternodeList;

typedef struct MndiffResult {
  bool has_found_coinbase;
  bool has_valid_coinbase;
  bool has_valid_mn_list_root;
  bool has_valid_quorum_list_root;
  bool has_valid_quorums;
  struct MasternodeList *masternode_list;
  struct MasternodeEntry **added_masternodes;
  uintptr_t added_masternodes_count;
  struct MasternodeEntry **modified_masternodes;
  uintptr_t modified_masternodes_count;
  struct LLMQMap **added_quorum_type_maps;
  uintptr_t added_quorum_type_maps_count;
  uint8_t (**needed_masternode_lists)[32];
  uintptr_t needed_masternode_lists_count;
} MndiffResult;

typedef const struct MasternodeList *(*MasternodeListLookup)(uint8_t (*block_hash)[32], const void *context);

typedef void (*MasternodeListDestroy)(const struct MasternodeList*);

typedef void (*AddInsightBlockingLookup)(uint8_t (*block_hash)[32], const void *context);

typedef bool (*ShouldProcessQuorumTypeCallback)(uint8_t quorum_type, const void *context);

typedef struct QuorumValidationData {
  uint8_t (**items)[48];
  uintptr_t count;
  uint8_t (*commitment_hash)[32];
  uint8_t (*all_commitment_aggregated_signature)[96];
  uint8_t (*quorum_threshold_signature)[96];
  uint8_t (*quorum_public_key)[48];
} QuorumValidationData;

typedef bool (*ValidateQuorumCallback)(struct QuorumValidationData *data, const void *context);

typedef uint32_t (*BlockHeightLookup)(uint8_t (*block_hash)[32], const void *context);

typedef struct Element {
  uintptr_t key_length;
  uint8_t *key;
  bool exists;
  uintptr_t value_length;
  uint8_t *value;
} Element;

typedef struct ExecuteProofResult {
  bool valid;
  uint8_t (*hash)[32];
  uintptr_t element_count;
  struct Element **elements;
} ExecuteProofResult;

typedef struct Query {
  uintptr_t key_length;
  uint8_t *key;
  uintptr_t key_end_length;
  uint8_t *key_end;
} Query;

typedef struct Keys {
  uintptr_t element_count;
  struct Query **elements;
} Keys;

































































































































































































































































































































































































































































































































struct MndiffResult *mndiff_process(const uint8_t *message_arr,
                                    uintptr_t message_length,
                                    const struct MasternodeList *base_masternode_list,
                                    MasternodeListLookup masternode_list_lookup,
                                    MasternodeListDestroy masternode_list_destroy,
                                    const uint8_t *merkle_root,
                                    bool use_insight_as_backup,
                                    AddInsightBlockingLookup add_insight_lookup,
                                    ShouldProcessQuorumTypeCallback should_process_quorum_of_type,
                                    ValidateQuorumCallback validate_quorum_callback,
                                    BlockHeightLookup block_height_lookup,
                                    const void *context);

void mndiff_block_hash_destroy(uint8_t (*block_hash)[32]);

void mndiff_quorum_validation_data_destroy(struct QuorumValidationData *data);

void mndiff_destroy(struct MndiffResult *result);

struct ExecuteProofResult *execute_proof_c(const uint8_t *c_array, uintptr_t length);

struct ExecuteProofResult *execute_proof_query_keys_c(const uint8_t *c_array,
                                                      uintptr_t length,
                                                      const struct Keys *query_keys);

void destroy_proof_c(struct ExecuteProofResult *proof_result);
