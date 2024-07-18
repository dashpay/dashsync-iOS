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

#import "DSCoinJoinManager.h"
#import "DSTransaction.h"
#import "DSTransactionOutput.h"
#import "DSAccount.h"
#import "DSCoinControl.h"
#import "DSWallet.h"
#import "BigIntTypes.h"
#import "NSString+Bitcoin.h"
#import "DSChainManager.h"
#import "DSTransactionManager.h"
#import "DSMasternodeManager.h"
#import "DSCoinJoinAcceptMessage.h"
#import "DSCoinJoinEntryMessage.h"
#import "DSCoinJoinSignedInputs.h"
#import "DSPeerManager.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSChain+Protected.h"

int32_t const DEFAULT_MIN_DEPTH = 0;
int32_t const DEFAULT_MAX_DEPTH = 9999999;

@interface DSCoinJoinManager ()

@property (nonatomic, strong) dispatch_group_t processingGroup;
@property (nonatomic, strong) dispatch_queue_t processingQueue;
@property (nonatomic, strong) dispatch_source_t coinjoinTimer;

@end

@implementation DSCoinJoinManager

static NSMutableDictionary *_managerChainDictionary = nil;
static dispatch_once_t managerChainToken = 0;

+ (instancetype)sharedInstanceForChain:(DSChain *)chain {
    NSParameterAssert(chain);

    dispatch_once(&managerChainToken, ^{
        _managerChainDictionary = [NSMutableDictionary dictionary];
    });
    DSCoinJoinManager *managerForChain = nil;
    @synchronized(self) {
        if (![_managerChainDictionary objectForKey:chain.uniqueID]) {
            managerForChain = [[DSCoinJoinManager alloc] initWithChain:chain];
            _managerChainDictionary[chain.uniqueID] = managerForChain;
        } else {
            managerForChain = [_managerChainDictionary objectForKey:chain.uniqueID];
        }
    }
    return managerForChain;
}

- (instancetype)initWithChain:(DSChain *)chain {
    self = [super init];
    if (self) {
        _chain = chain;
        _wrapper = [[DSCoinJoinWrapper alloc] initWithManagers:self chainManager:chain.chainManager];
        _masternodeGroup = [[DSMasternodeGroup alloc] initWithManager:self];
        _processingGroup = dispatch_group_create();
        _processingQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.coinjoin.%@", self.chain.uniqueID] UTF8String], DISPATCH_QUEUE_SERIAL);
    }
    return self;
}


- (void)startAsync {
    if (!self.masternodeGroup.isRunning) {
        self.blocksObserver =
            [[NSNotificationCenter defaultCenter] addObserverForName:DSChainNewChainTipBlockNotification
                                                              object:nil
                                                               queue:nil
                                                          usingBlock:^(NSNotification *note) {
                                                              if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                  [self.wrapper notifyNewBestBlock:self.chain.lastSyncBlock];
                                                              }
                                                          }];
        
        DSLog(@"[OBJ-C] CoinJoin: broadcasting senddsq(true) to all peers");
        [self.chain.chainManager.peerManager shouldSendDsq:true];
        [self.masternodeGroup startAsync];
    }
}

- (void)start {
    DSLog(@"[OBJ-C] CoinJoinManager starting...");
    [self cancelCoinjoinTimer];
    uint32_t interval = 1;
    uint32_t delay = 1;
    
    @synchronized (self) {
        [self.wrapper registerCoinJoin];
        self.coinjoinTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.processingQueue);
        if (self.coinjoinTimer) {
            dispatch_source_set_timer(self.coinjoinTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), interval * NSEC_PER_SEC, 1ull * NSEC_PER_SEC);
            dispatch_source_set_event_handler(self.coinjoinTimer, ^{
                DSLog(@"[OBJ-C] CoinJoin: trigger doMaintenance");
                [self.wrapper doMaintenance];
            });
            dispatch_resume(self.coinjoinTimer);
        }
    }
}

- (BOOL)startMixing {
    @synchronized (self.wrapper) {
        return [self.wrapper startMixing];
    }
}

- (void)stopAsync {
     if (self.masternodeGroup != nil && self.masternodeGroup.isRunning) {
         DSLog(@"[OBJ-C] CoinJoin: call stop");
         [self.chain.chainManager.peerManager shouldSendDsq:false];
         [self.masternodeGroup stopAsync];
         self.masternodeGroup = nil;
         [self cancelCoinjoinTimer];
         [[NSNotificationCenter defaultCenter] removeObserver:self.blocksObserver];
    }
}

- (void)doAutomaticDenominating {
    dispatch_async(self.processingQueue, ^{
        dispatch_group_enter(self.processingGroup);
        
        @synchronized (self.wrapper) {
            [self.wrapper doAutomaticDenominating];
        }
        
        dispatch_group_leave(self.processingGroup);
    });
}

- (void)cancelCoinjoinTimer {
    @synchronized (self) {
        if (self.coinjoinTimer) {
            dispatch_source_cancel(self.coinjoinTimer);
            self.coinjoinTimer = nil;
        }
    }
}

- (void)setStopOnNothingToDo:(BOOL)stop {
    @synchronized (self.wrapper) {
        [self.wrapper setStopOnNothingToDo:stop];
    }
}

- (void)processMessageFrom:(DSPeer *)peer message:(NSData *)message type:(NSString *)type {
    dispatch_async(self.processingQueue, ^{
        dispatch_group_enter(self.processingGroup);
        
        if ([type isEqualToString:MSG_COINJOIN_QUEUE]) {
            [self.wrapper processDSQueueFrom:peer message:message];
        } else {
            [self.wrapper processMessageFrom:peer message:message type:type];
        }
        
        dispatch_group_leave(self.processingGroup);
    });
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
        NSArray *utxos = self.chain.wallets.firstObject.unspentOutputs;
        for (NSValue *value in utxos) {
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

- (NSArray<DSInputCoin *> *)availableCoins:(WalletEx *)walletEx onlySafe:(BOOL)onlySafe coinControl:(DSCoinControl *_Nullable)coinControl minimumAmount:(uint64_t)minimumAmount maximumAmount:(uint64_t)maximumAmount minimumSumAmount:(uint64_t)minimumSumAmount maximumCount:(uint64_t)maximumCount {
    NSMutableArray<DSInputCoin *> *vCoins = [NSMutableArray array];
    
    @synchronized(self) {
        CoinType coinType = coinControl != nil ? coinControl.coinType : CoinType_AllCoins;

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
                uint64_t value = output.amount;
                BOOL found = NO;
                
                if (coinType == CoinType_OnlyFullyMixed) {
                    if (!is_denominated_amount(value)) {
                        continue;
                    }
                    
                    found = is_fully_mixed(walletEx, (uint8_t (*)[32])(wtxid.u8), (uint32_t)i);
                } else if (coinType == CoinType_OnlyReadyToMix) {
                    if (!is_denominated_amount(value)) {
                        continue;
                    }
                    
                    found = !is_fully_mixed(walletEx, (uint8_t (*)[32])(wtxid.u8), (uint32_t)i);
                } else if (coinType == CoinType_OnlyNonDenominated) {
                    if (is_collateral_amount(value)) {
                        continue; // do not use collateral amounts
                    }
                    
                    found = !is_denominated_amount(value);
                } else if (coinType == CoinType_OnlyMasternodeCollateral) {
                    found = value == 1000 * DUFFS;
                } else if (coinType == CoinType_OnlyCoinJoinCollateral) {
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
                
                if (is_locked_coin(walletEx, (uint8_t (*)[32])(wtxid.u8), (uint32_t)i) && coinType != CoinType_OnlyMasternodeCollateral) {
                    continue;
                }
                
                if ([account isSpent:outputValue]) {
                    continue;
                }
                
                if (output.address == nil || ![account containsAddress:output.address]) {
                    continue;
                }
                
                if (!allowUsedAddresses && [account transactionAddressAlreadySeenInOutputs:output.address]) {
                    continue;
                }
                
                [vCoins addObject:[[DSInputCoin alloc] initWithTx:coin index:i]];
                
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

- (BOOL)isCoinJoinOutput:(DSTransactionOutput *)output utxo:(DSUTXO)utxo {
    if (!is_denominated_amount(output.amount)) {
        return false;
    }
    
    if (!is_fully_mixed(_wrapper.walletEx, (uint8_t (*)[32])(utxo.hash.u8), (uint32_t)utxo.n)) {
        return false;
    }
    
    return [self.chain.wallets.firstObject.accounts.firstObject.coinJoinDerivationPath containsAddress:output.address];
}

- (Balance *)getBalance {
    NSMutableSet<NSData *> *setWalletTxesCounted = [[NSMutableSet alloc] init];
    uint64_t anonymizedBalance = 0;
    uint64_t denominatedBalance = 0;
    
    DSUTXO outpoint;
    NSArray *utxos = self.chain.wallets.firstObject.unspentOutputs;
    for (NSValue *value in utxos) {
        [value getValue:&outpoint];
        
        if ([setWalletTxesCounted containsObject:uint256_data(outpoint.hash)]) {
            continue;
        }
        
        [setWalletTxesCounted addObject:uint256_data(outpoint.hash)];
        DSTransaction *tx = [self.chain transactionForHash:outpoint.hash];
        
        for (int32_t i = 0; i < tx.outputs.count; i++) {
            DSTransactionOutput *output = tx.outputs[i];
            
            if ([self isCoinJoinOutput:output utxo:outpoint]) {
                anonymizedBalance += output.amount;
            }
            
            if (is_denominated_amount(output.amount)) {
                denominatedBalance += output.amount;
            }
        }
    }
    
    DSLog(@"[OBJ-C] CoinJoin: denominatedBalance: %llu", denominatedBalance);
    
    Balance *balance = malloc(sizeof(Balance));
    balance->my_trusted = self.chain.chainManager.chain.balance;
    balance->denominated_trusted = denominatedBalance;
    balance->anonymized = anonymizedBalance;
    
    balance->my_immature = 0;
    balance->my_untrusted_pending = 0;
    balance->denominated_untrusted_pending = 0;
    balance->watch_only_trusted = 0;
    balance->watch_only_untrusted_pending = 0;
    balance->watch_only_immature = 0;
    
    return balance;
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

- (NSString *)freshAddress:(BOOL)internal {
    NSString *address;
    DSAccount *account = self.chain.wallets.firstObject.accounts.firstObject;
    
    if (internal) {
        address = account.coinJoinChangeAddress;
        DSLog(@"[OBJ-C] CoinJoin: freshChangeAddress, address: %@", address);
    } else {
        address = account.coinJoinReceiveAddress;
        DSLog(@"[OBJ-C] CoinJoin: freshReceiveAddress, address: %@", address);
    }
    
    return address;
}

- (BOOL)commitTransactionForAmounts:(NSArray *)amounts outputs:(NSArray *)outputs onPublished:(void (^)(NSError * _Nullable error))onPublished {
    DSAccount *account = self.chain.wallets.firstObject.accounts.firstObject;
    DSTransaction *transaction = [account transactionForAmounts:amounts toOutputScripts:outputs withFee:YES];
    
    if (!transaction) {
        return NO;
    }
    
    BOOL signedTransaction = [account signTransaction:transaction];
    
    if (!signedTransaction || !transaction.isSigned) {
        DSLog(@"[OBJ-C] CoinJoin error: not signed");
        return NO;
    } else {
        [self.chain.chainManager.transactionManager publishTransaction:transaction completion:^(NSError *error) {
            if (error) {
                DSLog(@"[OBJ-C] CoinJoin publish error: %@", error.description);
                onPublished(error);
            } else {
                DSLog(@"[OBJ-C] CoinJoin publish success: %@", transaction.description);
                onPublished(nil);
            }
        }];
    }
    
    return YES;
}

- (DSSimplifiedMasternodeEntry *)masternodeEntryByHash:(UInt256)hash {
    return [self.chain.chainManager.masternodeManager.currentMasternodeList masternodeForRegistrationHash:uint256_reverse(hash)];
}

- (uint64_t)validMNCount {
    return self.chain.chainManager.masternodeManager.currentMasternodeList.validMasternodeCount;
}

- (DSMasternodeList *)mnList {
    return self.chain.chainManager.masternodeManager.currentMasternodeList;
}

- (BOOL)isMasternodeOrDisconnectRequested:(UInt128)ip port:(uint16_t)port {
    return [_masternodeGroup isMasternodeOrDisconnectRequested:ip port:port];
}

- (BOOL)disconnectMasternode:(UInt128)ip port:(uint16_t)port {
    return [_masternodeGroup disconnectMasternode:ip port:port];
}

- (BOOL)sendMessageOfType:(NSString *)messageType message:(NSData *)message withPeerIP:(UInt128)address port:(uint16_t)port warn:(BOOL)warn {
    return [self.masternodeGroup forPeer:address port:port warn:warn withPredicate:^BOOL(DSPeer * _Nonnull peer) {
        if ([messageType isEqualToString:DSCoinJoinAcceptMessage.type]) {
            DSCoinJoinAcceptMessage *request = [DSCoinJoinAcceptMessage requestWithData:message];
            [peer sendRequest:request];
        } else if ([messageType isEqualToString:DSCoinJoinEntryMessage.type]) {
            DSCoinJoinEntryMessage *request = [DSCoinJoinEntryMessage requestWithData:message];
            [peer sendRequest:request];
        } else if ([messageType isEqualToString:DSCoinJoinSignedInputs.type]) {
            DSCoinJoinSignedInputs *request = [DSCoinJoinSignedInputs requestWithData:message];
            [peer sendRequest:request];
        } else {
            DSLog(@"[OBJ-C] CoinJoin: unknown message type: %@", messageType);
            return NO;
        }

        return YES;
    }];
}

- (BOOL)isWaitingForNewBlock {
    return [self.wrapper isWaitingForNewBlock];
}

- (BOOL)isMixing {
    return [self.wrapper isMixing];
}

- (BOOL)addPendingMasternode:(UInt256)proTxHash clientSessionId:(UInt256)sessionId {
    return [_masternodeGroup addPendingMasternode:proTxHash clientSessionId:sessionId];
}

- (SocketAddress *)mixingMasternodeAddressFor:(UInt256)clientSessionId {
    return [_wrapper mixingMasternodeAddressFor:clientSessionId];
}

@end
