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

#import "DSCoinControl.h"

@implementation DSCoinControl

- (instancetype)initWithFFICoinControl:(dash_spv_coinjoin_models_coin_control_CoinControl *)coinControl
                             chainType:(DChainType *)chainType {
    if (!(self = [super init])) return nil;
    self.coinType = dash_spv_coinjoin_models_coin_control_CoinType_index(coinControl->coin_type);
    self.minDepth = coinControl->min_depth;
    self.maxDepth = coinControl->max_depth;
    self.avoidAddressReuse = coinControl->avoid_address_reuse;
    self.allowOtherInputs = coinControl->allow_other_inputs;
    
    if (coinControl->dest_change)
        self.destChange = [DSKeyManager NSStringFrom:DAddressWithScriptPubKeyData(coinControl->dest_change, chainType)];
    NSMutableOrderedSet *setSelected = [NSMutableOrderedSet orderedSetWithCapacity:coinControl->set_selected->count];
    std_collections_HashSet_dashcore_blockdata_transaction_outpoint_OutPoint *set_selected = coinControl->set_selected;
    for (int i = 0; i < coinControl->set_selected->count; i++) {
        dashcore_blockdata_transaction_outpoint_OutPoint *outpoint = coinControl->set_selected->values[i];
        [setSelected addObject:dsutxo_obj(((DSUTXO){u256_cast(dashcore_hash_types_Txid_inner(outpoint->txid)), outpoint->vout}))];
    }
//    dash_spv_coinjoin_models_coin_control_CoinControl_destroy(coinControl);

//    if (coinControl->set_selected && coinControl->set_selected_size > 0) {
//        self.setSelected = [[NSMutableOrderedSet alloc] init];
//        
//        for (size_t i = 0; i < coinControl->set_selected_size; i++) {
//            TxOutPoint *outpoint = coinControl->set_selected[i];
//
//            if (outpoint) {
//                UInt256 hash;
//                memcpy(hash.u8, outpoint->hash, 32);
//                NSValue *value = dsutxo_obj(((DSUTXO){hash, outpoint->index}));
//                [self.setSelected addObject:value];
//            }
//        }
//    } else {
//        self.setSelected = [[NSMutableOrderedSet alloc] init];
//    }
    
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _setSelected = [[NSMutableOrderedSet alloc] init];
        _coinType = dash_spv_coinjoin_models_coin_control_CoinType_AllCoins;
        _allowOtherInputs = NO;
        _requireAllInputs = NO;
        _allowWatchOnly = NO;
        _overrideFeeRate = NO;
        _avoidPartialSpends = NO;
        _avoidAddressReuse = NO;
        _minDepth = 0;
        _destChange = NULL;
    }
    return self;
}

- (BOOL)hasSelected {
    return self.setSelected.count > 0;
}

- (BOOL)isSelected:(DSUTXO)utxo {
    for (NSValue *selectedValue in self.setSelected) {
        DSUTXO selectedUTXO;
        [selectedValue getValue:&selectedUTXO];
        
        if (dsutxo_eq(utxo, selectedUTXO)) {
            return YES;
        }
    }
    
    return NO;
}

- (void)useCoinJoin:(BOOL)useCoinJoin {
    self.coinType = useCoinJoin ? dash_spv_coinjoin_models_coin_control_CoinType_OnlyFullyMixed : dash_spv_coinjoin_models_coin_control_CoinType_AllCoins;
}

- (BOOL)isUsingCoinJoin {
    return self.coinType == dash_spv_coinjoin_models_coin_control_CoinType_OnlyFullyMixed;
}

- (void)select:(DSUTXO)utxo {
    NSValue *utxoValue = [NSValue valueWithBytes:&utxo objCType:@encode(DSUTXO)];
    if (![self.setSelected containsObject:utxoValue]) {
        [self.setSelected addObject:utxoValue];
    }
}

@end
