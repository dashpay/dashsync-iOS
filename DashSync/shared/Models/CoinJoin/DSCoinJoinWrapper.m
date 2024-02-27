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

#import "DSCoinJoinWrapper.h"
#import "DSTransaction.h"
#import "DSTransactionOutput.h"
#import "DSAccount.h"
#import "DSCoinControl.h"
#import "DSWallet.h"
#import "BigIntTypes.h"
#import "NSString+Bitcoin.h"
#import "DSChainManager.h"
#import "DSTransactionManager.h"

int32_t const DEFAULT_MIN_DEPTH = 0;
int32_t const DEFAULT_MAX_DEPTH = 9999999;

@implementation DSCoinJoinWrapper

- (instancetype)initWithChain:(DSChain *)chain {
    self = [super init];
    if (self) {
        _chain = chain;
    }
    return self;
}

- (BOOL)isMineInput:(UInt256)txHash index:(uint32_t)index {
    DSTransaction *tx = [self.chain transactionForHash:txHash];
    DSAccount *account = [self.chain firstAccountThatCanContainTransaction:tx];
    
    if (index < tx.outputs.count) {
        DSTransactionOutput *output = tx.outputs[index];
        
        if ([account containsAddress:output.address]) { // TODO: is it the same as isPubKeyMine?
            return YES;
        }
    }
    
    return NO;
}

- (NSArray<DSCompactTallyItem *> *)selectCoinsGroupedByAddresses:(WalletEx *)walletEx skipDenominated:(BOOL)skipDenominated anonymizable:(BOOL)anonymizable skipUnconfirmed:(BOOL)skipUnconfirmed maxOupointsPerAddress:(int32_t)maxOupointsPerAddress {
    
    @synchronized(self) {
        // Note: cache is checked in dash-shared-core.
        
        uint64_t smallestDenom = coinjoin_get_smallest_denomination();
        NSMutableDictionary<NSData*, DSCompactTallyItem*> *mapTally = [[NSMutableDictionary alloc] init];
        NSMutableSet<NSData *> *setWalletTxesCounted = [[NSMutableSet alloc] init];
        
        DSUTXO outpoint;
        for (NSValue *value in self.chain.wallets.firstObject.unspentOutputs) {
            [value getValue:&outpoint];
            
            if ([setWalletTxesCounted containsObject:uint256_data(outpoint.hash)]) {
                continue;
            }
            
            [setWalletTxesCounted addObject:uint256_data(outpoint.hash)];
            DSTransaction *wtx = [self.chain transactionForHash:outpoint.hash];
            
            if (wtx == nil) {
                continue;
            }
            
            if (wtx.isCoinbaseClassicTransaction && [wtx getBlocksToMaturity] > 0) {
                continue;
            }
            
            DSAccount *account = [self.chain firstAccountThatCanContainTransaction:wtx];
            BOOL isTrusted = wtx.instantSendReceived || [account transactionIsVerified:wtx];
            
            if (skipUnconfirmed && !isTrusted) {
                continue;
            }
            
            for (int32_t i = 0; i < wtx.outputs.count; i++) {
                DSTransactionOutput *output = wtx.outputs[i];
                NSData *txDest = output.outScript;
                NSString *address = [NSString bitcoinAddressWithScriptPubKey:txDest forChain:self.chain];
                
                if (address == nil) {
                    continue;
                }
                
                if (![account containsAddress:output.address]) { // TODO: is it the same as isPubKeyMine?
                    continue;
                }
                
                DSCompactTallyItem *tallyItem = mapTally[txDest];
                
                if (maxOupointsPerAddress != -1 && tallyItem != nil && tallyItem.inputCoins.count >= maxOupointsPerAddress) {
                    continue;
                }

                if (is_locked_coin(walletEx, (uint8_t (*)[32])(outpoint.hash.u8), (uint32_t)i)) {
                    continue;
                }
                
                if (skipDenominated && is_denominated_amount(output.amount)) {
                    continue;
                }
                
                if (anonymizable) {
                    // ignore collaterals
                    if (is_collateral_amount(output.amount)) {
                        continue;
                    }
                    
                    // ignore outputs that are 10 times smaller then the smallest denomination
                    // otherwise they will just lead to higher fee / lower priority
                    if (output.amount <= smallestDenom/10) {
                        continue;
                    }
                    
                    // ignore mixed
                    if (is_fully_mixed(walletEx, (uint8_t (*)[32])(outpoint.hash.u8), (uint32_t)i)) {
                        continue;
                    }
                }
                
                if (tallyItem == nil) {
                    tallyItem = [[DSCompactTallyItem alloc] init];
                    tallyItem.txDestination = txDest;
                    mapTally[txDest] = tallyItem;
                }
                
                tallyItem.amount += output.amount;
                DSInputCoin *coin = [[DSInputCoin alloc] initWithTx:wtx index:i];
                [tallyItem.inputCoins addObject:coin];
            }
        }

        // construct resulting vector
        // NOTE: vecTallyRet is "sorted" by txdest (i.e. address), just like mapTally
        NSMutableArray<DSCompactTallyItem *> *vecTallyRet = [[NSMutableArray alloc] init];
        
        for (DSCompactTallyItem *item in mapTally.allValues) {
            // TODO: (dashj) ignore this to get this dust back in
            if (anonymizable && item.amount < smallestDenom) {
                continue;
            }
            
            [vecTallyRet addObject:item];
        }

        // Note: cache is assigned in dash-shared-core
        
        return vecTallyRet;
    }
}

- (uint32_t)countInputsWithAmount:(uint64_t)inputAmount {
    uint32_t total = 0;
    
    @synchronized(self) {
        NSArray *unspent = self.chain.wallets.firstObject.unspentOutputs;
        
        DSUTXO outpoint;
        for (uint32_t i = 0; i < unspent.count; i++) {
            [unspent[i] getValue:&outpoint];
            DSTransaction *tx = [self.chain transactionForHash:outpoint.hash];
            
            if (tx == NULL) {
                continue;
            }
            
            if (tx.outputs[outpoint.n].amount != inputAmount) {
                continue;
            }
            
            if (tx.confirmations < 0) {
                continue;
            }
            
            total++;
        }
    }
    
    return total;
}


- (BOOL)hasCollateralInputs:(WalletEx *)walletEx onlyConfirmed:(BOOL)onlyConfirmed {
    DSCoinControl *coinControl = [[DSCoinControl alloc] init];
    coinControl.coinType = CoinTypeOnlyCoinJoinCollateral;
    coinControl.minDepth = 0;
    coinControl.maxDepth = 9999999;
    
    NSArray<DSTransactionOutput *> *vCoins = [self availableCoins:walletEx onlySafe:onlyConfirmed coinControl:coinControl minimumAmount:1 maximumAmount:MAX_MONEY minimumSumAmount:MAX_MONEY maximumCount:0];
    DSLog(@"[OBJ-C] CoinJoin: availableCoins returned %lu coins", (unsigned long)vCoins.count);
    
    return vCoins.count > 0;
}

- (NSArray<DSTransactionOutput *> *) availableCoins:(WalletEx *)walletEx onlySafe:(BOOL)onlySafe coinControl:(DSCoinControl *_Nullable)coinControl minimumAmount:(uint64_t)minimumAmount maximumAmount:(uint64_t)maximumAmount minimumSumAmount:(uint64_t)minimumSumAmount maximumCount:(uint64_t)maximumCount {
    NSMutableArray<DSTransactionOutput *> *vCoins = [NSMutableArray array];
    
    @synchronized(self) {
        CoinType coinType = coinControl != nil ? coinControl.coinType : CoinTypeAllCoins;

        uint64_t total = 0;
        // Either the WALLET_FLAG_AVOID_REUSE flag is not set (in which case we always allow), or we default to avoiding, and only in the case where a coin control object is provided, and has the avoid address reuse flag set to false, do we allow already used addresses
        BOOL allowUsedAddresses = /* !IsWalletFlagSet(WALLET_FLAG_AVOID_REUSE) || */ (coinControl != nil && !coinControl.avoidAddressReuse);
        int32_t minDepth = coinControl != nil ? coinControl.minDepth : DEFAULT_MIN_DEPTH;
        int32_t maxDepth = coinControl != nil ? coinControl.maxDepth : DEFAULT_MAX_DEPTH;
        
        for (DSTransaction *coin in [self getSpendableTXs]) {
            UInt256 wtxid = coin.txHash;
            DSAccount *account = [self.chain firstAccountThatCanContainTransaction:coin];
            
            if ([account transactionIsPending:coin]) {
                continue;
            }
            
            if (coin.isImmatureCoinBase) {
                continue;
            }
            
            BOOL safeTx = coin.instantSendReceived || [account transactionIsVerified:coin];
            
            if (onlySafe && !safeTx) {
                continue;
            }
            
            uint32_t depth = coin.confirmations;
            
            if (depth < minDepth || depth > maxDepth) {
                continue;
            }
            
            for (uint32_t i = 0; i < coin.outputs.count; i++) {
                DSTransactionOutput *output = coin.outputs[i];
                DSLog(@"[OBJ-C] CoinJoin: check output: %llu", output.amount);
                uint64_t value = output.amount;
                BOOL found = NO;
                
                if (coinType == CoinTypeOnlyFullyMixed) {
                    if (!is_denominated_amount(value)) {
                        continue;
                    }
                    
                    found = is_fully_mixed(walletEx, (uint8_t (*)[32])(wtxid.u8), (uint32_t)i);
                } else if (coinType == CoinTypeOnlyReadyToMix) {
                    if (!is_denominated_amount(value)) {
                        continue;
                    }
                    
                    found = !is_fully_mixed(walletEx, (uint8_t (*)[32])(wtxid.u8), (uint32_t)i);
                } else if (coinType == CoinTypeOnlyNonDenominated) {
                    if (is_collateral_amount(value)) {
                        continue; // do not use collateral amounts
                    }
                    
                    found = !is_denominated_amount(value);
                } else if (coinType == CoinTypeOnlyMasternodeCollateral) {
                    found = value == 1000 * DUFFS;
                } else if (coinType == CoinTypeOnlyCoinJoinCollateral) {
                    found = is_collateral_amount(value);
                } else {
                    found = YES;
                }
                
                if (!found) {
                    continue;
                }
                
                if (value < minimumAmount || value > maximumAmount) {
                    continue;
                }
                
                NSValue *outputValue = dsutxo_obj(((DSUTXO){wtxid, i}));
                
                if (coinControl != nil && coinControl.hasSelected && !coinControl.allowOtherInputs && ![coinControl isSelected:outputValue]) {
                    continue;
                }
                
                if (is_locked_coin(walletEx, (uint8_t (*)[32])(wtxid.u8), (uint32_t)i) && coinType != CoinTypeOnlyMasternodeCollateral) {
                    continue;
                }
                
                if ([account isSpent:outputValue]) {
                    continue;
                }
                
                if (![account containsAddress:output.address]) {
                    continue;
                }
                
                if (!allowUsedAddresses && [account transactionAddressAlreadySeenInOutputs:output.address]) {
                    continue;
                }
                
                [vCoins addObject:output];
                
                // Checks the sum amount of all UTXO's.
                if (minimumSumAmount != MAX_MONEY) {
                    total += value;
                    
                    if (total >= minimumSumAmount) {
                        return vCoins;
                    }
                }
                
                // Checks the maximum number of UTXO's.
                if (maximumCount > 0 && vCoins.count >= maximumCount) {
                    return vCoins;
                }
            }
        }
    }
    
    return vCoins;
}

- (NSSet<DSTransaction *> *)getSpendableTXs {
    NSMutableSet<DSTransaction *> *ret = [[NSMutableSet alloc] init];
    NSArray *unspent = self.chain.wallets.firstObject.unspentOutputs;
    
    DSUTXO outpoint;
    for (uint32_t i = 0; i < unspent.count; i++) {
        [unspent[i] getValue:&outpoint];
        DSTransaction *tx = [self.chain transactionForHash:outpoint.hash];
        
        if (tx) {
            [ret addObject:tx];
            
            // Skip entries until we encounter a new TX
            DSUTXO nextOutpoint;
            while (i + 1 < unspent.count) {
                [unspent[i + 1] getValue:&nextOutpoint];
                
                if (!uint256_eq(nextOutpoint.hash, outpoint.hash)) {
                    break;
                }
                i++;
            }
        }
    }
    
    return ret;
}

- (ByteArray)freshReceiveAddress {
    NSString *address = self.chain.wallets.firstObject.accounts.firstObject.coinJoinReceiveAddress;
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: freshReceiveAddress, address: %@", address);
    return script_pubkey_for_address([address UTF8String], self.chain.chainType);
}

- (BOOL)commitTransactionForAmounts:(NSArray *)amounts outputs:(NSArray *)outputs {
    DSAccount *account = self.chain.wallets.firstObject.accounts.firstObject;
    DSTransaction *transaction = [account transactionForAmounts:amounts toOutputScripts:outputs withFee:YES];
    
    [account signTransaction:transaction completion:^(BOOL signedTransaction, BOOL cancelled) {
                                  if (!signedTransaction) {
                                      DSLog(@"[OBJ-C] Error: not signed");
                                  } else {
                                      if (!transaction.isSigned) { // double check
                                          DSLog(@"[OBJ-C] Error: not signed in double check");
                                          return;
                                      }

                                      [self.chain.chainManager.transactionManager publishTransaction:transaction completion:^(NSError *error) {
                                          if (error) {
                                              DSLog(@"[OBJ-C] Publish error%@", error.description);
                                          } else {
                                              DSLog(@"[OBJ-C] Publish success");
                                          }
                                      }];
                                  }
                              }];
    
    
    return YES;
}

@end
