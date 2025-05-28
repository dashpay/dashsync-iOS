//  
//  Created by Andrei Ashikhmin
//  Copyright © 2024 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "BigIntTypes.h"
#import "DSChain+Transaction.h"
#import "DSAssetLockTransaction.h"
#import "DSAssetUnlockTransaction.h"
#import "DSCoinbaseTransaction.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSTransaction+FFI.h"
#import "DSTransactionInput+FFI.h"
#import "DSTransactionOutput+FFI.h"
#import "DSQuorumCommitmentTransaction.h"
#import "NSData+Dash.h"
#import "DSKeyManager.h"

@implementation DSTransaction (FFI)

+ (nonnull instancetype)ffi_from:(nonnull DTransaction *)transaction onChain:(nonnull DSChain *)chain {
    NSMutableArray *hashes = [NSMutableArray array];
    NSMutableArray *indexes = [NSMutableArray array];
    NSMutableArray *scripts = [NSMutableArray array];
    NSMutableArray *inputSequences = [NSMutableArray array];
    NSMutableArray *addresses = [NSMutableArray array];
    NSMutableArray *amounts = [NSMutableArray array];

    for (uintptr_t i = 0; i < transaction->input->count; i++) {
        DTxIn *txin = transaction->input->values[i];
        uint32_t index = txin->previous_output->vout;
        u256 *hash = dashcore_hash_types_Txid_inner(txin->previous_output->txid);
        // TODO: check if it's reversed
        UInt256 hashValue = u256_cast(hash);
        Vec_u8 *script_sig = txin->script_sig->_0;
        NSData *script = NSDataFromPtr(script_sig);
        if (!script.length) {
            DSTransaction *inputTx = [chain transactionForHash:hashValue];
            DSLog(@"[DSTransaction] ffi_from: %@ == %@ (%@)", uint256_hex(hashValue), inputTx, [chain transactionForHash:uint256_reverse(hashValue)]);
            if (inputTx)
                script = inputTx.outputs[index].outScript;
        }
        [hashes addObject:uint256_obj(hashValue)];
        [indexes addObject:@(index)];
        [scripts addObject:script];
        [inputSequences addObject:@(txin->sequence)];
    }
    for (uintptr_t i = 0; i < transaction->output->count; i++) {
        DTxOut *output = transaction->output->values[i];
        NSData *scriptPubKey = NSDataFromPtr(output->script_pubkey->_0);
        NSString *address = [DSKeyManager addressWithScriptPubKey:scriptPubKey forChain:chain];
        NSNumber *amount = @(output->value);
        
        [addresses addObject:address ?: [NSNull null]]; // Use NSNull turned into OP_RETURN script later
        [amounts addObject:amount];
    }

    DSTransaction *tx;
    switch (transaction->special_transaction_payload->tag) {
        case dashcore_blockdata_transaction_special_transaction_TransactionPayload_AssetLockPayloadType: {
            dashcore_blockdata_transaction_special_transaction_asset_lock_AssetLockPayload *payload = transaction->special_transaction_payload->asset_lock_payload_type;
            NSMutableArray<DSTransactionOutput *> *creditOutputs = [NSMutableArray arrayWithCapacity:payload->credit_outputs->count];
            for (int i = 0; i < payload->credit_outputs->count; i++) {
                DTxOut *output = payload->credit_outputs->values[i];
                NSData *script = NSDataFromPtr(output->script_pubkey->_0);
                [creditOutputs addObject:[DSTransactionOutput transactionOutputWithAmount:output->value outScript:script onChain:chain]];
            }
            
            tx = [[DSAssetLockTransaction alloc] initWithInputHashes:hashes
                                                        inputIndexes:indexes
                                                        inputScripts:scripts
                                                      inputSequences:inputSequences
                                                     outputAddresses:addresses
                                                       outputAmounts:amounts
                                                       creditOutputs:creditOutputs
                                                      payloadVersion:payload->version
                                                             onChain:chain];
        }
        default: {
            // TODO: implement other transactions types
            tx = [[DSTransaction alloc] initWithInputHashes:hashes
                                               inputIndexes:indexes
                                               inputScripts:scripts
                                             inputSequences:inputSequences
                                            outputAddresses:addresses
                                              outputAmounts:amounts
                                                    onChain:chain];

        };
    }

    
    tx.version = transaction->version;
    
    return tx;
}

- (DTransactionPayload *_Nullable)ffi_payload {
    DTransactionPayload *payload = NULL;
    if ([self isMemberOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction *tx = (DSProviderRegistrationTransaction *)self;
        
        DOutPoint *collateral_outpoint = DOutPointFromUTXO(tx.collateralOutpoint);
        SocketAddr *service_address = DSocketAddrFrom(u128_ctor_u(tx.ipAddress), tx.port);
        DPubkeyHash *owner_key_hash = DPubkeyHashCtor(u160_ctor_u(tx.ownerKeyHash));
        DBLSPublicKey *operator_public_key = DBLSPublicKeyCtor(u384_ctor_u(tx.operatorKey));
        DPubkeyHash *voting_key_hash = DPubkeyHashCtor(u160_ctor_u(tx.votingKeyHash));
        DScriptBuf *script_payout = DScriptBufCtor(bytes_ctor(tx.scriptPayout));
        DInputsHash *inputs_hash = DInputsHashCtor(u256_ctor_u(tx.inputsHash));
        Vec_u8 *signature = bytes_ctor(tx.payloadSignature);
        DPubkeyHash *platform_node_id = DPubkeyHashCtor(u160_ctor_u(tx.platformNodeID));
        uint16_t *platform_p2p_port = tx.platformP2PPort ? u16_ctor(tx.platformP2PPort) : NULL;
        uint16_t *platform_http_port = tx.platformHTTPPort ? u16_ctor(tx.platformHTTPPort) : NULL;
        DProviderMasternodeType *masternode_type = tx.providerType == DProviderMasternodeTypeHighPerformance ? DProviderMasternodeTypeHighPerformanceCtor() : DProviderMasternodeTypeRegularCtor();
        uint16_t version = tx.providerRegistrationTransactionVersion;
        uint16_t masternode_mode = tx.providerMode;
        uint16_t operator_reward = tx.operatorReward;
        payload = DTransactionPayloadProviderRegistrationCtor(DProviderRegistrationPayloadCtor(version, masternode_type, masternode_mode, collateral_outpoint, service_address, owner_key_hash, operator_public_key, voting_key_hash, operator_reward, script_payout, inputs_hash, signature, platform_node_id, platform_p2p_port, platform_http_port));
        
    } else if ([self isMemberOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction *tx = (DSProviderUpdateServiceTransaction *)self;
        uint16_t version = tx.providerUpdateServiceTransactionVersion;
        DTxid *pro_tx_hash = DTxidCtor(u256_ctor_u(tx.providerRegistrationTransactionHash));
        uint8_t (*ip_address)[16] = malloc(sizeof(uint8_t) * 16);
        memcpy(ip_address, tx.ipAddress.u8, sizeof(sizeof(uint8_t) * 16));
        uint16_t port = tx.port;
        DScriptBuf *script_payout = DScriptBufCtor(bytes_ctor(tx.scriptPayout));
        DInputsHash *inputs_hash = DInputsHashCtor(u256_ctor_u(tx.inputsHash));
        DBLSSignature *payload_sig = DBLSSignatureCtor(u768_ctor(tx.payloadSignature));
        payload = DTransactionPayloadProviderUpdateServiceCtor(DProviderUpdateServicePayloadCtor(version, pro_tx_hash, ip_address, port, script_payout, inputs_hash, payload_sig));
    } else if ([self isMemberOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction *tx = (DSProviderUpdateRegistrarTransaction *)self;
        uint16_t version = tx.providerUpdateRegistrarTransactionVersion;
        DTxid *pro_tx_hash = DTxidCtor(u256_ctor_u(tx.providerRegistrationTransactionHash));
        uint16_t provider_mode = tx.providerMode;
        DBLSPublicKey *operator_public_key = DBLSPublicKeyCtor(u384_ctor_u(tx.operatorKey));
        DPubkeyHash *voting_key_hash = DPubkeyHashCtor(u160_ctor_u(tx.votingKeyHash));
        DScriptBuf *script_payout = DScriptBufCtor(bytes_ctor(tx.scriptPayout));
        DInputsHash *inputs_hash = DInputsHashCtor(u256_ctor_u(tx.inputsHash));
        Vec_u8 *payload_sig = bytes_ctor(tx.payloadSignature);
        payload = DTransactionPayloadProviderUpdateRegistrarCtor(DProviderUpdateRegistrarPayloadCtor(version, pro_tx_hash, provider_mode, operator_public_key, voting_key_hash, script_payout, inputs_hash, payload_sig));
    } else if ([self isMemberOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        DSProviderUpdateRevocationTransaction *tx = (DSProviderUpdateRevocationTransaction *)self;
        uint16_t version = tx.providerUpdateRevocationTransactionVersion;
        DTxid *pro_tx_hash = DTxidCtor(u256_ctor_u(tx.providerRegistrationTransactionHash));
        uint16_t reason = tx.reason;
        DInputsHash *inputs_hash = DInputsHashCtor(u256_ctor_u(tx.inputsHash));
        DBLSSignature *payload_sig = DBLSSignatureCtor(u768_ctor(tx.payloadSignature));
        payload = DTransactionPayloadProviderUpdateRevocationCtor(DProviderUpdateRevocationPayloadCtor(version, pro_tx_hash, reason, inputs_hash, payload_sig));
    } else if ([self isMemberOfClass:[DSCoinbaseTransaction class]]) {
        DSCoinbaseTransaction *tx = (DSCoinbaseTransaction *)self;
        uint16_t version = tx.coinbaseTransactionVersion;
        uint32_t height = tx.height;
        DMerkleRootMasternodeList *merkle_root_masternode_list = DMerkleRootMasternodeListCtor(u256_ctor_u(tx.merkleRootMNList));
        DMerkleRootQuorums *merkle_root_quorums = DMerkleRootQuorumsCtor(u256_ctor_u(tx.merkleRootLLMQList));
        uint32_t *best_cl_height = tx.bestCLHeightDiff ? u32_ctor((uint32_t) tx.bestCLHeightDiff) : NULL;
        DBLSSignature *best_cl_signature = uint768_is_zero(tx.bestCLSignature) ? NULL : DBLSSignatureCtor(u768_ctor_u(tx.bestCLSignature));
        uint64_t *asset_locked_amount = tx.creditPoolBalance ? u64_ctor(tx.creditPoolBalance) : NULL;
        payload = DTransactionPayloadCoinbaseCtor(DCoinbasePayloadCtor(version, height, merkle_root_masternode_list, merkle_root_quorums, best_cl_height, best_cl_signature, asset_locked_amount));
    } else if ([self isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
        DSQuorumCommitmentTransaction *tx = (DSQuorumCommitmentTransaction *)self;
        uint16_t version = tx.quorumCommitmentTransactionVersion;
        uint32_t height = tx.blockHeight;
        uint16_t qf_commit_version = tx.qfCommitVersion;
        DLLMQType *llmq_type = dashcore_sml_llmq_type_LLMQType_from_u16(tx.llmqType);
        DQuorumHash *quorum_hash = DQuorumHashCtor(u256_ctor_u(tx.quorumHash));
        // TODO: ?????
        int16_t *quorum_index = NULL;
        uintptr_t signers_count = tx.signersCount;
        BOOL *signers_values = malloc(sizeof(BOOL) * signers_count);
        for (uint32_t i = 0; i < signers_count; i++) {
            signers_values[i] = [tx.signersBitset bitIsTrueAtLEIndex:i];
        }
        Vec_bool *signers = Vec_bool_ctor(signers_count, signers_values);
        uintptr_t valid_members_count = tx.validMembersCount;
        BOOL *valid_members_values = malloc(sizeof(BOOL) * valid_members_count);
        for (uint32_t i = 0; i < valid_members_count; i++) {
            valid_members_values[i] = [tx.validMembersBitset bitIsTrueAtLEIndex:i];
        }
        Vec_bool *valid_members = Vec_bool_ctor(valid_members_count, valid_members_values);
        DBLSPublicKey *quorum_public_key = DBLSPublicKeyCtor(u384_ctor_u(tx.quorumPublicKey));
        DQuorumVVecHash *quorum_vvec_hash = DQuorumVVecHashCtor(u256_ctor_u(tx.quorumVerificationVectorHash));
        DBLSSignature *threshold_sig = DBLSSignatureCtor(u768_ctor_u(tx.quorumThresholdSignature));
        DBLSSignature *all_commitment_aggregated_signature = DBLSSignatureCtor(u768_ctor_u(tx.allCommitmentAggregatedSignature));
        DQuorumEntry *quorum_entry = DQuorumEntryCtor(qf_commit_version, llmq_type, quorum_hash, quorum_index, signers, valid_members, quorum_public_key, quorum_vvec_hash, threshold_sig, all_commitment_aggregated_signature);
        payload = DTransactionPayloadQuorumCommitmentCtor(DQuorumCommitmentPayloadCtor(version, height, quorum_entry));
    } else if ([self isMemberOfClass:[DSAssetLockTransaction class]]) {
        DSAssetLockTransaction *tx = (DSAssetLockTransaction *)self;
        NSArray<DSTransactionOutput *> *creditOutputs = tx.creditOutputs;
        uintptr_t credit_outputs_count = creditOutputs.count;
        DTxOut **credit_output_values = malloc(credit_outputs_count * sizeof(DTxOut *));
        for (uintptr_t i = 0; i < credit_outputs_count; i++) {
            credit_output_values[i] = [creditOutputs[i] ffi_malloc];
        }
        DTxOutputs *credit_outputs = DTxOutputsCtor(credit_outputs_count, credit_output_values);
        DAssetLockPayload *asset_lock_payload = DAssetLockPayloadCtor(tx.specialTransactionVersion, credit_outputs);
        payload = DTransactionPayloadAssetLockCtor(asset_lock_payload);
    } else if ([self isMemberOfClass:[DSAssetUnlockTransaction class]]) {
        DSAssetUnlockTransaction *tx = (DSAssetUnlockTransaction *)self;
        DAssetUnlockBasePayload *base = DAssetUnlockBasePayloadCtor(tx.specialTransactionVersion, tx.index, tx.fee);
        DAssetUnlockRequestInfo *request_info = DAssetUnlockRequestInfoCtor(tx.requestedHeight, DQuorumHashCtor(u256_ctor_u(tx.quorumHash)));
        DBLSSignature *quorum_sig = DBLSSignatureCtor(u768_ctor_u(tx.quorumSignature));
        payload = DTransactionPayloadAssetUnlockCtor(DAssetUnlockPayloadCtor(base, request_info, quorum_sig));
    }
    return payload;
}

- (DTransaction *)ffi_malloc:(DChainType *)chainType {
    NSArray<DSTransactionInput *> *tx_inputs = self.inputs;
    uintptr_t inputsCount = tx_inputs.count;
    DTxIn **input_values = malloc(inputsCount * sizeof(DTxIn *));
    for (uintptr_t i = 0; i < inputsCount; i++) {
        input_values[i] = [tx_inputs[i] ffi_malloc];
    }
    
    NSArray<DSTransactionOutput *> *tx_outputs = self.outputs;
    uintptr_t outputsCount = tx_outputs.count;
    DTxOut **output_values = malloc(outputsCount * sizeof(DTxOut *));
    for (uintptr_t i = 0; i < outputsCount; i++) {
        output_values[i] = [tx_outputs[i] ffi_malloc];
    }
    
    DTransactionPayload *payload = [self ffi_payload];
    DTxInputs *inputs = DTxInputsCtor(inputsCount, input_values);
    DTxOutputs *outputs = DTxOutputsCtor(outputsCount, output_values);
    DTransaction *transaction = DTransactionCtor(self.version, self.lockTime, inputs, outputs, payload);
    return transaction;
}

+ (void)ffi_free:(DTransaction *)tx {
    if (!tx) return;
    DTransactionDtor(tx);
}



@end

