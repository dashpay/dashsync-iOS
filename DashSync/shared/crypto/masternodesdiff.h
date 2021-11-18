#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Maximum size, in bytes, of a vector we are allowed to decode
 */
#define MAX_VEC_SIZE 4000000

#define MN_ENTRY_PAYLOAD_LENGTH 151

/**
 * Version of the protocol as appearing in network message headers
 * This constant is used to signal to other peers which features you support.
 * Increasing it implies that your software also supports every feature prior to this version.
 * Doing so without support may lead to you incorrectly banning other peers or other peers banning you.
 * These are the features required for each version:
 * 70016 - Support receiving `wtxidrelay` message between `version` and `verack` message
 * 70015 - Support receiving invalid compact blocks from a peer without banning them
 * 70014 - Support compact block messages `sendcmpct`, `cmpctblock`, `getblocktxn` and `blocktxn`
 * 70013 - Support `feefilter` message
 * 70012 - Support `sendheaders` message and announce new blocks via headers rather than inv
 * 70011 - Support NODE_BLOOM service flag and don't support bloom filter messages if it is not set
 * 70002 - Support `reject` message
 * 70001 - Support bloom filter messages `filterload`, `filterclear` `filteradd`, `merkleblock` and FILTERED_BLOCK inventory type
 * 60002 - Support `mempool` message
 * 60001 - Support `pong` message and nonce in `ping` message
 */
#define PROTOCOL_VERSION 70001

typedef enum LLMQType {
  Llmqtype5060 = 1,
  Llmqtype40060 = 2,
  Llmqtype40085 = 3,
  Llmqtype10067 = 4,
  Llmqtype560 = 100,
  Llmqtype1060 = 101,
} LLMQType;

/**
 * A script Opcode
 */
typedef struct All All;

typedef struct Option_____BTreeMap_UInt256__MasternodeEntry Option_____BTreeMap_UInt256__MasternodeEntry;

typedef struct Option_____HashMap_LLMQType__HashMap_UInt256__QuorumEntry Option_____HashMap_LLMQType__HashMap_UInt256__QuorumEntry;

typedef struct Option_____HashSet_UInt256 Option_____HashSet_UInt256;

typedef struct Option_____MasternodeList Option_____MasternodeList;

typedef struct BaseMasternodeList {
  struct Option_____MasternodeList _0;
} BaseMasternodeList;

typedef struct Result {
  bool found_coinbase;
  bool valid_coinbase;
  bool root_mn_list_valid;
  bool root_quorum_list_valid;
  bool valid_quorums;
  struct BaseMasternodeList masternode_list;
  struct Option_____BTreeMap_UInt256__MasternodeEntry added_masternodes;
  struct Option_____BTreeMap_UInt256__MasternodeEntry modified_masternodes;
  struct Option_____HashMap_LLMQType__HashMap_UInt256__QuorumEntry added_quorums;
  struct Option_____HashSet_UInt256 needed_masternode_lists;
} Result;

typedef struct BaseMasternodeList (*MasternodeListLookup)(const uint8_t *block_hash);

typedef bool (*AddInsightBlockingLookup)(const uint8_t *block_hash);

typedef bool (*ShouldProcessQuorumTypeCallback)(enum LLMQType quorum_type);

typedef bool (*ValidateQuorumCallback)(uint8_t (**items)[48], uintptr_t count, const uint8_t *commitment_hash, const uint8_t *all_commitment_aggregated_signature, const uint8_t *quorum_threshold_signature, const uint8_t *quorum_public_key);

typedef uint32_t (*BlockHeightLookup)(const uint8_t *block_hash);

struct Result *process_diff(const uint8_t *c_array,
                            uintptr_t length,
                            struct BaseMasternodeList base_masternode_list,
                            MasternodeListLookup masternode_list_lookup,
                            const uint8_t *merkle_root,
                            AddInsightBlockingLookup use_insight_lookup,
                            ShouldProcessQuorumTypeCallback should_process_quorum_of_type,
                            ValidateQuorumCallback validate_quorum_callback,
                            BlockHeightLookup block_height_lookup);
