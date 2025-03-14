//  
//  Created by Vladimir Pirogov
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

#import "DSBlock.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChain+Identity.h"
#import "DSChain+Wallet.h"
#import "DSChainLock.h"
#import "DSChainManager+Protected.h"
#import "DSDashSharedCore.h"
#import "DSIdentity+Protected.h"
#import "DSKeyManager.h"
#import "DSMasternodeListService.h"
#import "DSMasternodeListDiffService.h"
#import "DSQuorumRotationService.h"
#import "DSMasternodeManager+Protected.h"
#import "NSArray+Dash.h"

@class DSPeer;

#define AS_OBJC(context) ((__bridge DSDashSharedCore *)(context))
#define AS_RUST(context) ((__bridge void *)(context))

#define GetDataContract Fn_ARGS_std_os_raw_c_void_platform_value_types_identifier_Identifier_RTRN_Result_ok_Option_std_sync_Arc_dpp_data_contract_DataContract_err_drive_proof_verifier_error_ContextProviderError

#define SignerCallback Fn_ARGS_std_os_raw_c_void_dpp_identity_identity_public_key_IdentityPublicKey_Vec_u8_RTRN_Result_ok_platform_value_types_binary_data_BinaryData_err_dpp_errors_protocol_error_ProtocolError
#define GetPlatformActivationHeight Fn_ARGS_std_os_raw_c_void_RTRN_Result_ok_dpp_prelude_CoreBlockHeight_err_drive_proof_verifier_error_ContextProviderError

#define CanSign Fn_ARGS_std_os_raw_c_void_dpp_identity_identity_public_key_IdentityPublicKey_RTRN_bool

#define GetBlockHeightByHash Fn_ARGS_std_os_raw_c_void_Arr_u8_32_RTRN_u32
#define GetBlockHashByHeight Fn_ARGS_std_os_raw_c_void_u32_RTRN_Option_u8_32

#define MerkleBlockByBlockHash Fn_ARGS_std_os_raw_c_void_Arr_u8_32_RTRN_Result_ok_dash_spv_masternode_processor_common_block_MBlock_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError
#define LastMerkleBlockByBlockHashForPeer Fn_ARGS_std_os_raw_c_void_Arr_u8_32_std_os_raw_c_void_RTRN_Result_ok_dash_spv_masternode_processor_common_block_MBlock_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError


#define AddInsight Fn_ARGS_std_os_raw_c_void_Arr_u8_32_RTRN_

#define HasPersistInRetrieval Fn_ARGS_std_os_raw_c_void_Arr_u8_32_RTRN_bool
#define GetBlockHeightOrLastTerminal Fn_ARGS_std_os_raw_c_void_u32_RTRN_Result_ok_dash_spv_masternode_processor_common_block_Block_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError

#define FnMaybeCLSignature Fn_ARGS_std_os_raw_c_void_Arr_u8_32_RTRN_Result_ok_dashcore_bls_sig_utils_BLSSignature_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError
#define DMaybeCLSignature Result_ok_dashcore_bls_sig_utils_BLSSignature_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError
#define DMaybeCLSignatureCtor(ok, err) Result_ok_dashcore_bls_sig_utils_BLSSignature_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError_ctor(ok, err)
#define LoadMasternodeList Fn_ARGS_std_os_raw_c_void_Arr_u8_32_RTRN_Result_ok_dashcore_sml_masternode_list_MasternodeList_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError
#define SaveMasternodeList Fn_ARGS_std_os_raw_c_void_Arr_u8_32_std_collections_Map_keys_u8_arr_32_values_dashcore_sml_masternode_list_entry_qualified_masternode_list_entry_QualifiedMasternodeListEntry_RTRN_Result_ok_bool_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError
#define LoadLLMQSnapshot Fn_ARGS_std_os_raw_c_void_Arr_u8_32_RTRN_Result_ok_dashcore_network_message_qrinfo_QuorumSnapshot_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError
#define SaveLLMQSnapshot Fn_ARGS_std_os_raw_c_void_Arr_u8_32_dashcore_network_message_qrinfo_QuorumSnapshot_RTRN_Result_ok_bool_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError

#define UpdateMasternodesAddressUsage Fn_ARGS_std_os_raw_c_void_Vec_dashcore_sml_masternode_list_entry_qualified_masternode_list_entry_QualifiedMasternodeListEntry_RTRN_


@interface DSDashSharedCore ()

@property (nonatomic) DSChain *chain;
@property (nonatomic, assign) DashSPVCore *core;
@property (nonatomic, strong) NSMutableDictionary *devnetSharedCoreDictionary;
@property (atomic, assign) uint32_t masternodeListCurrentlyBeingSavedCount;

@end

@implementation DSDashSharedCore

+ (instancetype)sharedCore {
    static DSDashSharedCore *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (DSDashSharedCore *)mainnetSharedCore {
    static id _core = nil;
    static dispatch_once_t mainnetToken = 0;
    dispatch_once(&mainnetToken, ^{
        DSChain *mainnet = [DSChain mainnet];
        _core = [[DSDashSharedCore alloc] initOnChain:mainnet];
        mainnet.shareCore = _core;
    });
    return _core;
}

- (DSDashSharedCore *)testnetSharedCore {
    static id core = nil;
    static dispatch_once_t testnetToken = 0;

    dispatch_once(&testnetToken, ^{
        DSChain *testnet = [DSChain testnet];
        core = [[DSDashSharedCore alloc] initOnChain:testnet];
        testnet.shareCore = core;
    });
    return core;
}

- (instancetype)devnetSharedCore:(DSChain *)chain {
    static dispatch_once_t devnetToken = 0;
    dispatch_once(&devnetToken, ^{
        self.devnetSharedCoreDictionary = [NSMutableDictionary dictionary];
    });
    NSValue *genesisValue = uint256_obj(chain.genesisHash);
    DSDashSharedCore *core = nil;
    @synchronized(self) {
        if (![self.devnetSharedCoreDictionary objectForKey:genesisValue]) {
            core = [[DSDashSharedCore alloc] initOnChain:chain];
            chain.shareCore = core;
        } else {
            core = [self.devnetSharedCoreDictionary objectForKey:genesisValue];
        }
    }
    return core;
}
- (DArcProcessor *)processor {
    return dash_spv_apple_bindings_DashSPVCore_processor(self.core);
}

- (DArcPlatformSDK *)platform {
    return dash_spv_apple_bindings_DashSPVCore_platform(self.core);
}
- (Runtime *)runtime {
    return dash_spv_apple_bindings_DashSPVCore_runtime(self.core);
}

- (DArcIdentitiesManager *)identitiesManager {
    return dash_spv_platform_PlatformSDK_identity_manager(self.platform->obj);
}
- (DArcContractsManager *)contractsManager {
    return dash_spv_platform_PlatformSDK_contract_manager(self.platform->obj);
}
- (DArcDocumentsManager *)documentsManager {
    return dash_spv_platform_PlatformSDK_doc_manager(self.platform->obj);
}
- (DArcContactRequestManager *)contactRequests {
    return dash_spv_platform_PlatformSDK_contact_requests(self.platform->obj);
}
- (DSaltedDomainHashesManager *)saltedDomainHashes {
    return dash_spv_platform_PlatformSDK_salted_domain_hashes(self.platform->obj);
}

- (DUsernamesManager *)usernames {
    return dash_spv_platform_PlatformSDK_usernames(self.platform->obj);
}

- (instancetype)initOnChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;
    self.chain = chain;
    _masternodeListCurrentlyBeingSavedCount = 0;

    const void *context = AS_RUST(self);

    GetDataContract get_data_contract = {
        .caller = &get_data_contract_caller,
        .destructor = &get_data_contract_dtor
    };
    SignerCallback callback_signer = {
        .caller = &callback_signer_caller,
        .destructor = &callback_signer_dtor
    };
    GetPlatformActivationHeight get_platform_activation_height = {
        .caller = &get_platform_activation_height_caller,
        .destructor = &get_platform_activation_height_dtor
    };
    CanSign callback_can_sign = {
        .caller = &callback_can_sign_caller,
        .destructor = &callback_can_sign_dtor
    };
    
    GetBlockHeightByHash get_block_height_by_hash = {
        .caller = &get_block_height_by_hash_caller,
        .destructor = &get_block_height_by_hash_dtor
    };
    
    GetBlockHashByHeight get_block_hash_by_height = {
        .caller = &get_block_hash_by_height_caller,
        .destructor = &get_block_hash_by_height_dtor
    };
//    MerkleBlockByBlockHash block_by_block_hash = {
//        .caller = &block_by_block_hash_caller,
//        .destructor = &block_by_block_hash_dtor
//    };
//    LastMerkleBlockByBlockHashForPeer last_block_for_block_hash = {
//        .caller = &last_block_by_block_hash_caller,
//        .destructor = &last_block_by_block_hash_dtor
//    };
//    
//    GetBlockHeightOrLastTerminal get_block_by_height_or_last_terminal = {
//        .caller = &get_block_by_height_or_last_terminal_caller,
//        .destructor = &get_block_by_height_or_last_terminal_dtor
//    };
    
    UpdateMasternodesAddressUsage update_address_usage_of_masternodes = {
        .caller = &update_address_usage_of_masternodes_caller
    };

    Fn_ARGS_std_os_raw_c_void_bool_std_os_raw_c_void_RTRN_ issue_with_masternode_list_from_peer = {
        .caller = &issue_with_masternode_list_from_peer_caller
    };
    FnMaybeCLSignature get_cl_signature_by_block_hash = {
        .caller = &get_cl_signature_by_block_hash_caller,
        .destructor = &get_cl_signature_by_block_hash_dtor
    };
    
//    Fn_ARGS_std_os_raw_c_void_bool_RTRN_ dequeue_masternode_list = {
//        .caller = &dequeue_masternode_list_caller,
//    };
    Fn_ARGS_std_os_raw_c_void_dash_spv_masternode_processor_models_sync_state_CacheState_RTRN_ notify_sync_state = {
        .caller = &notify_sync_state_caller,
    };
//    Fn_ARGS_std_os_raw_c_void_RTRN_u32 get_tip_height = {
//        .caller = &get_tip_height_caller,
//        .destructor = &get_tip_height_dtor
//    };
    
    NSArray<NSString *> *addresses = @[@"127.0.0.1"];
    switch (chain.chainType->tag) {
        case dash_spv_crypto_network_chain_type_ChainType_MainNet:
            addresses = @[
                @"149.28.241.190", @"216.238.75.46", @"134.255.182.186", @"66.245.196.52", @"178.157.91.186", @"157.66.81.162", @"213.199.34.250", @"157.90.238.161", @"5.182.33.231", @"185.198.234.68", @"37.60.236.212", @"207.244.247.40", @"45.32.70.131", @"158.220.122.76", @"52.33.9.172", @"185.158.107.124", @"185.198.234.17", @"93.190.140.101", @"194.163.153.225", @"194.146.13.7", @"93.190.140.112", @"75.119.132.2", @"65.108.74.95", @"44.240.99.214", @"5.75.133.148", @"192.248.178.237", @"95.179.159.65", @"139.84.232.129", @"37.60.243.119", @"194.195.87.34", @"46.254.241.7", @"45.77.77.195", @"65.108.246.145", @"64.176.10.71", @"158.247.247.241", @"37.60.244.220", @"2.58.82.231", @"139.180.143.115", @"185.198.234.54", @"213.199.44.112", @"37.27.67.154", @"134.255.182.185", @"86.107.168.28", @"139.84.137.143", @"173.212.239.124", @"157.10.199.77", @"5.189.186.78", @"139.84.170.10", @"173.249.53.139", @"37.60.236.151", @"37.27.67.159", @"104.200.24.196", @"37.60.236.225", @"172.104.90.249", @"57.128.212.163", @"37.60.236.249", @"158.220.122.74", @"185.198.234.25", @"148.113.201.221", @"134.255.183.250", @"185.192.96.70", @"134.255.183.248", @"52.36.102.91", @"134.255.183.247", @"49.13.28.255", @"168.119.102.10", @"86.107.168.44", @"49.13.237.193", @"37.27.83.17", @"134.255.182.187", @"142.132.165.149", @"193.203.15.209", @"38.242.198.100", @"192.175.127.198", @"37.27.67.163", @"79.137.71.84", @"198.7.115.43", @"70.34.206.123", @"163.172.20.205", @"65.108.74.78", @"108.61.165.170", @"157.10.199.79", @"31.220.88.116", @"185.166.217.154", @"37.27.67.164", @"31.220.85.180", @"161.97.170.251", @"157.10.199.82", @"91.107.226.241", @"167.88.169.16", @"216.238.99.9", @"62.169.17.112", @"52.10.213.198", @"149.28.201.164", @"198.7.115.38", @"37.60.236.161", @"49.13.193.251", @"46.254.241.9", @"65.108.74.75", @"192.99.44.64", @"95.179.241.182", @"95.216.146.18", @"185.194.216.84", @"31.220.84.93", @"185.197.250.227", @"149.28.247.165", @"86.107.168.29", @"213.199.34.251", @"108.160.135.149", @"185.198.234.12", @"87.228.24.64", @"45.32.52.10", @"91.107.204.136", @"64.176.35.235", @"167.179.90.255", @"157.66.81.130", @"157.10.199.125", @"46.254.241.8", @"49.12.102.105", @"134.255.182.189", @"81.17.101.141", @"65.108.74.79", @"64.23.134.67", @"54.69.95.118", @"158.220.122.13", @"49.13.154.121", @"75.119.149.9", @"93.190.140.111", @"93.190.140.114", @"195.201.238.55", @"135.181.110.216", @"45.76.141.74", @"65.21.145.147", @"50.116.28.103", @"188.245.90.255", @"130.162.233.186", @"65.109.65.126", @"188.208.196.183", @"178.157.91.184", @"37.60.236.201", @"95.179.139.125", @"213.199.34.248", @"178.157.91.178", @"213.199.35.18", @"213.199.35.6", @"37.60.243.59", @"37.27.67.156", @"37.60.236.247", @"159.69.204.162", @"46.254.241.11", @"173.199.71.83", @"185.215.166.126", @"91.234.35.132", @"157.66.81.218", @"213.199.35.15", @"114.132.172.215", @"93.190.140.162", @"65.108.74.109"
            ];

            break;
        case dash_spv_crypto_network_chain_type_ChainType_TestNet:
            addresses = @[@"35.165.50.126", @"52.42.202.128", @"52.12.176.90", @"44.233.44.95", @"35.167.145.149", @"52.34.144.50", @"44.240.98.102"];
            break;
        case dash_spv_crypto_network_chain_type_ChainType_DevNet:
            break;
            
        default:
            break;
    }
    Vec_ *address_list = [NSArray ffi_to_vec:addresses];

    self.core = dash_spv_apple_bindings_DashSPVCore_with_callbacks(chain.chainType, address_list, get_data_contract, get_platform_activation_height, callback_signer, callback_can_sign, get_block_height_by_hash, get_block_hash_by_height, get_cl_signature_by_block_hash, update_address_usage_of_masternodes, issue_with_masternode_list_from_peer, notify_sync_state, context);
    return self;
}



- (void)dealloc {
    if (_core != NULL) {
        dash_spv_apple_bindings_DashSPVCore_destroy(_core);
        _core = NULL;
    }
}


- (BOOL)hasMasternodeListCurrentlyBeingSaved {
    return !!self.masternodeListCurrentlyBeingSavedCount;
}
- (DSBlock *)lastBlockForBlockHash:(UInt256)blockHash fromPeer:(DSPeer *)peer {
    DSBlock *lastBlock = nil;
    if ([self.chain heightForBlockHash:blockHash]) {
        lastBlock = [[peer.chain terminalBlocks] objectForKey:uint256_obj(blockHash)];
        if (!lastBlock && [peer.chain allowInsightBlocksForVerification]) {
            NSData *blockHashData = uint256_data(blockHash);
            lastBlock = [[peer.chain insightVerifiedBlocksByHashDictionary] objectForKey:blockHashData];
            if (!lastBlock && peer.chain.isTestnet) {
                //We can trust insight if on testnet
                [self.chain blockUntilGetInsightForBlockHash:blockHash];
                lastBlock = [[peer.chain insightVerifiedBlocksByHashDictionary] objectForKey:blockHashData];
            }
        }
    } else {
        lastBlock = (DSBlock *) [peer.chain recentTerminalBlockForBlockHash:blockHash];
    }
    return lastBlock;
}

MaybeDataContract *get_data_contract_caller(const void *context, DIdentifier *identitifier) {
    return NULL;
}
void get_data_contract_dtor(MaybeDataContract *result) {}

MaybeSignedData *callback_signer_caller(const void *context, DIdentityPublicKey *identity_public_key, BYTES *data) {
    DSDashSharedCore *core = AS_OBJC(context);
    DBinaryData *ok = NULL;
    dpp_errors_protocol_error_ProtocolError *error = NULL;
    NSData *dataToSign = NSDataFromPtr(data);
    DSLog(@"[SDK] callback_signer: identity_public_key: %p, data: %@", identity_public_key, dataToSign.hexString);
    DMaybeOpaqueKey *maybe_key = [core.chain identityPrivateKeyForIdentityPublicKey:identity_public_key];
    if (!maybe_key || maybe_key->error) {
        error = dpp_errors_protocol_error_ProtocolError_Generic_ctor(DSLocalizedChar(@"Can't find a signer for identity public key: %p", nil, identity_public_key));
    } else {
        ok = DBinaryDataCtor(dash_spv_crypto_keys_key_OpaqueKey_hash_and_sign(maybe_key->ok, data));
    }
    DMaybeOpaqueKeyDtor(maybe_key);
    dpp_identity_identity_public_key_IdentityPublicKey_destroy(identity_public_key);
    bytes_dtor(data);
    return Result_ok_platform_value_types_binary_data_BinaryData_err_dpp_errors_protocol_error_ProtocolError_ctor(ok, error);

}
void callback_signer_dtor(MaybeSignedData *result) {}

MaybePlatformActivationHeight *get_platform_activation_height_caller(const void *context) {
    return NULL;
}
void get_platform_activation_height_dtor(MaybePlatformActivationHeight *result) {}

bool callback_can_sign_caller(const void *context, DIdentityPublicKey *identity_public_key) {
    // TODO: impl
    return TRUE;
}
void callback_can_sign_dtor(bool result) {}

uint32_t get_block_height_by_hash_caller(const void *context, u256 *block_hash) {
    DSDashSharedCore *core = AS_OBJC(context);
    UInt256 blockHash = u256_cast(block_hash);
//    UInt256 revBlockHash = uint256_reverse(blockHash);
    uint32_t height = [core.chain heightForBlockHash:blockHash];
//    uint32_t rev_height = [core.chain heightForBlockHash:revBlockHash];
    
    if (height == UINT32_MAX && core.chain.allowInsightBlocksForVerification) {
        [core.chain blockUntilGetInsightForBlockHash:blockHash];
        height = [[core.chain insightVerifiedBlocksByHashDictionary] objectForKey:NSDataFromPtr(block_hash)].height;
    }
    u256_dtor(block_hash);
    DSLog(@"[SDK] get_block_height_by_hash_caller: %@ = %u", uint256_hex(blockHash), height);
    return height;
}
void get_block_height_by_hash_dtor(uint32_t result) {}

u256 *get_block_hash_by_height_caller(const void *context, uint32_t block_height) {
    DSDashSharedCore *core = AS_OBJC(context);
    DSBlock *block = NULL;
    @synchronized (context) {
        block = (DSBlock *) [core.chain blockAtHeight:block_height];
        if (!block && core.chain.allowInsightBlocksForVerification)
            block = [core.chain blockUntilGetInsightForBlockHeight:block_height];
    }
    //    DSLog(@"[SDK] get_block_hash_by_height_caller: %u = %@", block_height, uint256_hex(block.blockHash));
    UInt256 blockHash = block ? block.blockHash : UINT256_ZERO;
    return u256_ctor_u(blockHash);
}

void get_block_hash_by_height_dtor(u256 *result) {}

//DMaybeMBlock *block_by_block_hash_caller(const void *context, u256 *block_hash) {
//    DSDashSharedCore *core = AS_OBJC(context);
//    UInt256 blockHash = u256_cast(block_hash);
//    DMBlock *ok = NULL;
//    DCoreProviderError *err = NULL;
//    @synchronized (context) {
//        DSBlock *block = (DSBlock *) [core.chain blockForBlockHash:blockHash];
//        DSLog(@"[SDK] block_by_hash_caller: %@ [%d] merkle_root: %@", uint256_hex(blockHash), block.height, uint256_hex(block.merkleRoot));
//        if (block) {
//            ok = DMBlockCtor(block.height, u256_ctor_u(block.blockHash), u256_ctor_u(block.merkleRoot));
//        } else {
//            err = DCoreProviderErrorNullResultCtor(DChar(@""));
//        }
//    }
//    u256_dtor(block_hash);
//    return DMaybeMBlockCtor(ok, err);
//}
//void block_by_block_hash_dtor(DMaybeMBlock *result) {}
//
//DMaybeMBlock *last_block_by_block_hash_caller(const void *context, u256 *block_hash, const void *peer_context) {
//    DSDashSharedCore *core = AS_OBJC(context);
//    DSPeer *peer = ((__bridge DSPeer *)(peer_context));
//    UInt256 blockHash = u256_cast(block_hash);
//    u256_dtor(block_hash);
//    DMBlock *ok = NULL;
//    DCoreProviderError *err = NULL;
//    @synchronized (context) {
//        DSBlock *lastBlock = [core lastBlockForBlockHash:blockHash fromPeer:peer];
//        //DSLog(@"[SDK] last_block_by_hash_caller: %@ = %@", uint256_hex(blockHash), lastBlock);
//        if (lastBlock) {
//            ok = DMBlockCtor(lastBlock.height, u256_ctor_u(lastBlock.blockHash), u256_ctor_u(lastBlock.merkleRoot));
//        } else {
//            err = DCoreProviderErrorNullResultCtor(DSLocalizedChar(@"No last block for block hash %@ from peer %@", nil, uint256_hex(blockHash), peer.description));
//        }
//    }
//    return DMaybeMBlockCtor(ok, err);
//}
//void last_block_by_block_hash_dtor(DMaybeMBlock *result) {}
//
//uint32_t get_tip_height_caller(const void *context) {
//    DSDashSharedCore *core = AS_OBJC(context);
//    @synchronized (context) {
//        return [core.chain chainTipHeight];
//    }
//}
//void get_tip_height_dtor(uint32_t result) {}


//DMaybeBlock *get_block_by_height_or_last_terminal_caller(const void *context, uint32_t block_height) {
//    DSDashSharedCore *core = AS_OBJC(context);
//    DSBlock *b = (DSBlock *) [core.chain blockAtHeightOrLastTerminal:block_height];
//    DBlock *ok = b ? DBlockCtor(b.height, u256_ctor_u(b.blockHash)) : NULL;
//    DCoreProviderError *err = b ? NULL : DCoreProviderErrorNullResultCtor(DSLocalizedChar(@"Unknown block for block height %u", nil, block_height));
//    return DMaybeBlockCtor(ok, err);
//}
//void get_block_by_height_or_last_terminal_dtor(DMaybeBlock *result) {
//    DMaybeBlockDtor(result);
//}
DMaybeCLSignature *get_cl_signature_by_block_hash_caller(const void *context, u256 *block_hash) {
    DSDashSharedCore *core = AS_OBJC(context);
    UInt256 blockHash = uint256_reverse(u256_cast(block_hash));
    u256_dtor(block_hash);
    DSChainLock *chainLock = [core.chain.chainManager chainLockForBlockHash:blockHash];
    return chainLock ? DMaybeCLSignatureCtor(dashcore_ephemerealdata_chain_lock_ChainLock_get_signature(chainLock.lock), NULL) : DMaybeCLSignatureCtor(NULL, DCoreProviderErrorNullResultCtor(DSLocalizedChar(@"No clsig for block hash %@", nil, uint256_hex(blockHash))));
}
void get_cl_signature_by_block_hash_dtor(DMaybeCLSignature *result) {}


//DMaybeMasternodeList *load_masternode_list_from_db_caller(const void *context, u256 *block_hash) {
//    DSDashSharedCore *core = AS_OBJC(context);
//    NSData *blockHashData = [DSKeyManager NSDataFromArr_u8_32:block_hash];
//    DMasternodeList *list = [core.chain.masternodeManager.store loadMasternodeListAtBlockHash:blockHashData withBlockHeightLookup:^uint32_t(UInt256 blockHash) {
//        return [core.chain heightForBlockHash:blockHash];
//    }];
//    DSLog(@"load_masternode_list_from_db_caller (%@) %p", blockHashData.hexString, list);
//    return Result_ok_dashcore_sml_masternode_list_MasternodeList_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError_ctor(list, list ? NULL : DCoreProviderErrorNullResultCtor(DSLocalizedChar(@"No masternode list for block hash %@ in DB", nil, blockHashData.hexString)));
//}
//void load_masternode_list_from_db_dtor(DMaybeMasternodeList *result) {}

//MaybeBool *save_masternode_list_into_db_caller(const void *context, u256 *list_block_hash, DMasternodeEntryMap *modified_masternodes) {
//    DSDashSharedCore *core = AS_OBJC(context);
//    DSChain *chain = core.chain;
//    DSMasternodeManager *masternodeManager = chain.masternodeManager;
//    uintptr_t count = DStoredMasternodeListsCount(core.cache->obj);
//    uint32_t last_block_height = DLastMasternodeListBlockHeight(core.processor->obj);
//    DMasternodeList *masternode_list = DMasternodeListForBlockHash(core.processor->obj, list_block_hash);
//    uint32_t list_known_height = masternode_list->known_height;
//    [chain.chainManager notifyMasternodeSyncStateChange:last_block_height storedCount:count];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: chain}];
//        [[NSNotificationCenter defaultCenter] postNotificationName:DSQuorumListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: chain}];
//    });
//
//    dispatch_group_enter(core.chain.masternodeManager.store.savingGroup);
//    //We will want to create unknown blocks if they came from insight
//    BOOL createUnknownBlocks = chain.allowInsightBlocksForVerification;
//    core.masternodeListCurrentlyBeingSavedCount++;
//    //This will create a queue for masternodes to be saved without blocking the networking queue
//    DSLog(@"[%@] ••••••••••••••••••••••••••••• save_masternode_list_into_db %u --> •••••••••••••••••••••••••••••••••••••••••", chain.name, list_known_height);
////    DMasternodeListPrint(masternode_list->obj);
////    DSLog(@"•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••");
//
//    NSError *error = [DSMasternodeListStore saveMasternodeList:masternode_list
//                                    toChain:chain
//                    havingModifiedMasternodes:modified_masternodes
//                        createUnknownBlocks:createUnknownBlocks
//                                  inContext:chain.chainManagedObjectContext];
//    core.masternodeListCurrentlyBeingSavedCount--;
//    DMasternodeListDtor(masternode_list);
//    DMasternodeEntryMapDtor(modified_masternodes);
//    dispatch_group_leave(core.chain.masternodeManager.store.savingGroup);
//    BOOL success = !error;
//    DCoreProviderError *provider_err = NULL;
//    if (error) {
//        uintptr_t mn_list_count = DMnDiffQueueCount(core.cache->obj);
//        uintptr_t qr_info_count = DQrInfoQueueCount(core.cache->obj);
//        BOOL isEmptyQueue = !(mn_list_count + qr_info_count);
//        DSLog(@"[%@] Finished saving MNL with error: %@", chain.name, error.description);
//        if (!isEmptyQueue && masternodeManager.isSyncing) {
//            dispatch_async(chain.networkingQueue, ^{
//                [masternodeManager wipeMasternodeInfo];
//                [masternodeManager getRecentMasternodeList];
//            });
//        }
//        provider_err = DCoreProviderErrorNullResultCtor(DChar([error description]));
//    }
//    DSLog(@"[%@] ••••••••••••••••••••••••••••• save_masternode_list_into_db %u <-- •••••••••••••••••••••••••••••••••••••••••", chain.name, list_known_height);
////    DSLog(@"•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••");
////    DSLog(@"[%@] save_masternode_list_into_db <-- %d = %d", chain.name, list_known_height, success);
////    DSLog(@"•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••");
////    DMasternodeListPrint(masternode_list->obj);
////    DSLog(@"•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••");
//    
//    return Result_ok_bool_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError_ctor(&success, provider_err);
//}
//void save_masternode_list_into_db_destructor(MaybeBool *result) {}

//MaybeLLMQSnapshot *load_llmq_snapshot_from_db_caller(const void *context, u256 *block_hash) {
//    return NULL;
//}
//
//void load_llmq_snapshot_from_db_dtor(MaybeLLMQSnapshot *result) {}
//
//MaybeBool *save_llmq_snapshot_into_db_caller(const void *context, u256 *block_hash, DLLMQSnapshot *snapshot) {
//    DSDashSharedCore *core = AS_OBJC(context);
//    NSError *err = [core.chain.masternodeManager.store saveQuorumSnapshot:snapshot forBlockHash:block_hash];
//    BOOL success = !err;
//    DCoreProviderError *provider_err = err ? DCoreProviderErrorNullResultCtor(DChar(err.debugDescription)) : NULL;
//    u256_dtor(block_hash);
//    dash_spv_masternode_processor_models_snapshot_LLMQSnapshot_destroy(snapshot);
//    return Result_ok_bool_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError_ctor(&success, provider_err);
//}
//void save_llmq_snapshot_into_db_dtor(MaybeBool *result) {}

void update_address_usage_of_masternodes_caller(const void *context, DMasternodeEntryList *masternodes) {
    DSDashSharedCore *core = AS_OBJC(context);
    [core.chain updateAddressUsageOfSimplifiedMasternodeEntries:masternodes];
    DMasternodeEntryListDtor(masternodes);
}

//bool remove_request_in_retrieval_caller(const void *context, bool is_dip24, u256 *base_block_hash, u256 *block_hash) {
//    DSDashSharedCore *core = AS_OBJC(context);
//    DSMasternodeListService *service = is_dip24 ? core.chain.masternodeManager.quorumRotationService : core.chain.masternodeManager.masternodeListDiffService;
//    BOOL hasRemovedFromRetrieval = [service removeRequestInRetrievalForBaseBlockHash:u256_cast(base_block_hash) blockHash:u256_cast(block_hash)];
//    u256_dtor(base_block_hash);
//    u256_dtor(block_hash);
//    return hasRemovedFromRetrieval;
//}
//void remove_request_in_retrieval_dtor(bool result) {}

void issue_with_masternode_list_from_peer_caller(const void *context, bool is_dip24, const void *peer_context) {
    DSDashSharedCore *core = AS_OBJC(context);
    DSPeer *peer = ((__bridge DSPeer *)(peer_context));
    [core.chain.masternodeManager issueWithMasternodeListFromPeer:peer];
}

void notify_sync_state_caller(const void *context, DMNSyncState *state) {
    DSDashSharedCore *core = AS_OBJC(context);
    DSMasternodeListSyncState *syncInfo = core.chain.chainManager.syncState.masternodeListSyncInfo;
    @synchronized (syncInfo) {
        [syncInfo updateWithSyncState:state];
        switch (state->tag) {
            case DMNSyncStateQueueChanged:
                DSLog(@"[%@] Masternode list queue updated: %lu/%lu", core.chain.name, state->queue_changed.count, state->queue_changed.max_amount);
                break;
            case DMNSyncStateStoreChanged:
                DSLog(@"[%@] Masternode list store updated: %lu/%u", core.chain.name, state->store_changed.count, state->store_changed.last_block_height);
                break;
            case DMNSyncStateStubCount:
                DSLog(@"[%@] Masternode list DB updated: %lu", core.chain.name, state->stub_count.count);
            default:
                break;
        }
        DMNSyncStateDtor(state);
//        /*dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_print_queue_description*/(core.chain.sharedCacheObj);
        [core.chain.chainManager notifySyncStateChanged];
    }
}
void dequeue_masternode_list_caller(const void *context, bool is_dip24) {
    DSDashSharedCore *core = AS_OBJC(context);
    DSLog(@"[%@] dequeue_masternode_list_caller: qr: %u", core.chain.name, is_dip24);
    if (is_dip24) {
        [core.chain.masternodeManager.quorumRotationService dequeueMasternodeListRequest];
    } else {
        [core.chain.masternodeManager.masternodeListDiffService dequeueMasternodeListRequest];
    }
}


@end
