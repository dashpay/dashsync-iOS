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
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChain+Transaction.h"
#import "DSChain+Wallet.h"
#import "DSChainManager.h"
#import "DSTransactionManager.h"
#import "DSMasternodeManager.h"
#import "DSCoinJoinAcceptMessage.h"
#import "DSCoinJoinEntryMessage.h"
#import "DSCoinJoinSignedInputs.h"
#import "DSPeerManager.h"
#import "DSBlock.h"
#import "DSKeyManager.h"
#import "DSDerivationPath+Protected.h"

int32_t const DEFAULT_MIN_DEPTH = 0;
int32_t const DEFAULT_MAX_DEPTH = 9999999;
int32_t const MIN_BLOCKS_TO_WAIT = 1;

@interface DSCoinJoinManager ()

@property (nonatomic, strong) dispatch_queue_t processingQueue;
@property (nonatomic, strong) dispatch_source_t coinjoinTimer;
@property (atomic) int32_t cachedLastSuccessBlock;
@property (atomic) int32_t cachedBlockHeight; // Keep track of current block height
@property (atomic) double lastReportedProgress;
@property (atomic) BOOL hasReportedSuccess;
@property (atomic) BOOL hasReportedFailure;

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
    @synchronized(_managerChainDictionary) {
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
        _processingQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.coinjoin.%@", self.chain.uniqueID] UTF8String], DISPATCH_QUEUE_SERIAL);
        _cachedBlockHeight = 0;
        _cachedLastSuccessBlock = 0;
        _lastReportedProgress = 0;
        _options = [self createOptions];
        [self printUsedKeys];
    }
    return self;
}

- (void)initMasternodeGroup {
    _masternodeGroup = [[DSMasternodeGroup alloc] initWithManager:self];
}

- (DCoinJoinClientOptions *)createOptions {
    DCoinJoinClientOptions *options = dash_spv_coinjoin_models_coinjoin_client_options_CoinJoinClientOptions_ctor(true, DUFFS_OBJC / 8, 6, 1, COINJOIN_RANDOM_ROUNDS, DEFAULT_COINJOIN_DENOMS_GOAL, DEFAULT_COINJOIN_DENOMS_HARDCAP, false, self.chain.chainType, false);
    return options;
}

- (void)updateOptionsWithAmount:(uint64_t)amount {
    if (self.options->coinjoin_amount != amount) {
        self.options->coinjoin_amount = amount;
        
        if (self.wrapper.isRegistered) {
            [self.wrapper updateOptions:self.options];
        }
    }
}

- (void)updateOptionsWithEnabled:(BOOL)isEnabled {
    if (self.options->enable_coinjoin != isEnabled) {
        self.options->enable_coinjoin = isEnabled;
        
        if (self.wrapper.isRegistered) {
            [self.wrapper updateOptions:self.options];
        }
    }
}

- (void)updateOptionsWithSessions:(int32_t)sessions {
    if (self.options->coinjoin_sessions != sessions) {
        self.options->coinjoin_sessions = sessions;
        
        if (self.wrapper.isRegistered) {
            [self.wrapper updateOptions:self.options];
        }
    }
}

- (void)configureMixingWithAmount:(uint64_t)amount rounds:(int32_t)rounds sessions:(int32_t)sessions withMultisession:(BOOL)multisession denominationGoal:(int32_t)denomGoal denominationHardCap:(int32_t)denomHardCap {
    DSLog(@"[%@] CoinJoin: mixing configuration:  { rounds: %d, sessions: %d, amount: %llu, multisession: %s, denomGoal: %d, denomHardCap: %d }", self.chain.name, rounds, sessions, amount, multisession ? "YES" : "NO", denomGoal, denomHardCap);
    self.options->enable_coinjoin = true;
    self.options->coinjoin_amount = amount;
    self.options->coinjoin_rounds = rounds;
    self.options->coinjoin_sessions = sessions;
    self.options->coinjoin_multi_session = multisession;
    self.options->coinjoin_denoms_goal = denomGoal;
    self.options->coinjoin_denoms_hardcap = denomHardCap;
    
    if (self.wrapper.isRegistered) {
        [self.wrapper updateOptions:self.options];
    }
}

- (BOOL)isChainSynced {
    return self.chain.chainManager.syncPhase == DSChainSyncPhase_Synced;
}

- (void)startAsync {
    if (!self.masternodeGroup.isRunning) {
        [self.chain.chainManager.peerManager shouldSendDsq:true];
        [self.masternodeGroup startAsync];
    }
}

- (void)start {
    DSLog(@"[%@] CoinJoinManager starting", self.chain.name);
    [self cancelCoinjoinTimer];
    uint32_t interval = 1;
    uint32_t delay = 1;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleTransactionReceivedNotification)
                                                 name:DSTransactionManagerTransactionReceivedNotification
                                               object:nil];
    @synchronized (self) {
        self.cachedBlockHeight = self.chain.lastSyncBlock.height;
        self.options->enable_coinjoin = YES;
        
        if ([self.wrapper isRegistered]) {
            [self.wrapper updateOptions:self.options];
        } else {
            [self.wrapper registerCoinJoin:self.options];
        }
        
        self.coinjoinTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.processingQueue);
        if (self.coinjoinTimer) {
            dispatch_source_set_timer(self.coinjoinTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), interval * NSEC_PER_SEC, 1ull * NSEC_PER_SEC);
            dispatch_source_set_event_handler(self.coinjoinTimer, ^{
                [self doMaintenance];
            });
            dispatch_resume(self.coinjoinTimer);
        }
    }
}

- (void)doMaintenance {
    if ([self validMNCount] == 0) {
        return;
    }
    
    [self.wrapper doMaintenance];
}

- (BOOL)startMixing {
    self.isMixing = true;
    self.isShuttingDown = false;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSyncStateDidChangeNotification:)
                                                 name:DSChainManagerSyncStateDidChangeNotification
                                               object:nil];
    return [self.wrapper startMixing];
}

- (void)initiateShutdown {
    if (self.isMixing && !self.isShuttingDown) {
        DSLog(@"[%@] CoinJoinManager initiated shutdown", self.chain.name);
        self.isShuttingDown = true;
        [self updateOptionsWithSessions:0];
        [self.wrapper initiateShutdown];
        
        if (self.masternodeGroup != nil && self.masternodeGroup.isRunning) {
            [self.chain.chainManager.peerManager shouldSendDsq:false];
            [self.masternodeGroup stopAsync];
        }
    }
}

- (void)stop {
    if (self.isMixing) {
        DSLog(@"[%@] CoinJoinManager stopping", self.chain.name);
        self.isMixing = false;
        [self cancelCoinjoinTimer];
        self.cachedLastSuccessBlock = 0;
        [self updateOptionsWithEnabled:NO];
        [self.wrapper stopAndResetClientManager];
        [self stopAsync];
        self.isShuttingDown = false;
    }
}

- (void)stopAsync {
    if (self.masternodeGroup != nil && self.masternodeGroup.isRunning) {
        [self.chain.chainManager.peerManager shouldSendDsq:false];
        [self.masternodeGroup stopAsync];
        self.masternodeGroup = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc {
    if (_options != NULL) {
        dash_spv_coinjoin_models_coinjoin_client_options_CoinJoinClientOptions_destroy(_options);
    }
}

- (void)handleSyncStateDidChangeNotification:(NSNotification *)note {
    if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]] && self.chain.lastSyncBlock.height > self.cachedBlockHeight) {
        self.cachedBlockHeight = self.chain.lastSyncBlock.height;
        dispatch_async(self.processingQueue, ^{
            [self.wrapper notifyNewBestBlock:self.chain.lastSyncBlock];
        });
    }
}

- (void)handleTransactionReceivedNotification {
    DSWallet *wallet = self.chain.wallets.firstObject;
    DSTransaction *lastTransaction = wallet.accounts.firstObject.recentTransactions.firstObject;
    
    if ([self.wrapper isMixingFeeTx:lastTransaction.txHash]) {
#if DEBUG
        DSLogPrivate(@"[%@] CoinJoin tx: Mixing Fee: %@", self.chain.name, uint256_reverse_hex(lastTransaction.txHash));
#else
        DSLog(@"[%@] CoinJoin tx: Mixing Fee: %@", self.chain.name, @"<REDACTED>");
#endif
        [self onTransactionProcessed:lastTransaction.txHash type:dash_spv_coinjoin_models_coinjoin_tx_type_CoinJoinTransactionType_MixingFee_ctor()];
    } else if (DCoinJoinTransactionTypeIndex([self coinJoinTxTypeForTransaction:lastTransaction]) == dash_spv_coinjoin_models_coinjoin_tx_type_CoinJoinTransactionType_Mixing) {
#if DEBUG
        DSLogPrivate(@"[%@] CoinJoin tx: Mixing Transaction: %@", self.chain.name, uint256_reverse_hex(lastTransaction.txHash));
#else
        DSLog(@"[%@] CoinJoin tx: Mixing Transaction: %@", self.chain.name, @"<REDACTED>");
#endif
        [self.wrapper unlockOutputs:lastTransaction];
        [self onTransactionProcessed:lastTransaction.txHash type:dash_spv_coinjoin_models_coinjoin_tx_type_CoinJoinTransactionType_Mixing_ctor()];
    }
}

- (void)doAutomaticDenominatingWithDryRun:(BOOL)dryRun completion:(void (^)(BOOL success))completion {
    if (![self.wrapper isRegistered]) {
        [self.wrapper registerCoinJoin:self.options];
    }
    
    if (!dryRun && [self validMNCount] == 0) {
        completion(NO);
        return;
    }
    
    DSLog(@"[%@] CoinJoin: doAutomaticDenominatingWithDryRun: %@", self.chain.name, dryRun ? @"YES" : @"NO");
    
    dispatch_async(self.processingQueue, ^{
        BOOL result = [self.wrapper doAutomaticDenominatingWithDryRun:dryRun];
        
        if (!dryRun) {
            if (result) {
                if (!self.hasReportedSuccess) {
                    DSLog(@"[%@] CoinJoin: Mixing started successfully", self.chain.name);
                    self.hasReportedSuccess = YES;
                    self.hasReportedFailure = NO;
                }
            } else {
                if (!self.hasReportedFailure) {
                    DSLog(@"[%@] CoinJoin: Mixing start failed, will retry", self.chain.name);
                    self.hasReportedFailure = YES;
                    self.hasReportedSuccess = NO;
                }
            }
        }
        
        completion(result);
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
    [self.wrapper setStopOnNothingToDo:stop];
}

- (void)refreshUnusedKeys {
    [self.wrapper refreshUnusedKeys];
}

- (void)processMessageFrom:(DSPeer *)peer message:(NSData *)message type:(NSString *)type {
    if (!self.isMixing) {
        return;
    }
    
    dispatch_async(self.processingQueue, ^{
        if ([type isEqualToString:MSG_COINJOIN_QUEUE]) {
            if (!self.isShuttingDown) {
                [self.wrapper processDSQueueFrom:peer message:message];
            }
        } else {
            [self.wrapper processMessageFrom:peer message:message type:type];
        }
    });
}

- (BOOL)isMineInput:(UInt256)txHash index:(uint32_t)index {
    DSTransaction *tx = [self.chain transactionForHash:txHash];
    DSAccount *account = [self.chain firstAccountThatCanContainTransaction:tx];
    
    if (index < tx.outputs.count) {
        DSTransactionOutput *output = tx.outputs[index];
        
        if ([account containsAddress:output.address]) {
            return YES;
        }
    }
    
    return NO;
}

- (NSArray<DSCompactTallyItem *> *)selectCoinsGroupedByAddresses:(WalletEx *)walletEx
                                                 skipDenominated:(BOOL)skipDenominated
                                                    anonymizable:(BOOL)anonymizable
                                                 skipUnconfirmed:(BOOL)skipUnconfirmed
                                           maxOupointsPerAddress:(int32_t)maxOupointsPerAddress {
    @synchronized(self) {
        // Note: cache is checked in dash-shared-core.
        uint64_t smallestDenom = dash_spv_coinjoin_coinjoin_CoinJoin_get_smallest_denomination();
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
            
            DSAccount *account = self.chain.wallets.firstObject.accounts.firstObject;
            if (!account.coinJoinDerivationPath.addressesLoaded) {
                DSLog(@"[%@] CoinJoin selectCoinsGroupedByAddresses: CJDerivationPath addresses NOT loaded", self.chain.name);
            }
            
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
                
                if (![account containsAddress:output.address]) {
                    continue;
                }
                
                DSCompactTallyItem *tallyItem = mapTally[txDest];
                
                if (maxOupointsPerAddress != -1 && tallyItem != nil && tallyItem.inputCoins.count >= maxOupointsPerAddress) {
                    continue;
                }
                
                if ([account isSpent:dsutxo_obj(((DSUTXO){outpoint.hash, i}))]) {
                    continue;
                }
                
                if (dash_spv_coinjoin_wallet_ex_WalletEx_is_locked_coin(walletEx, DOutPointCtorU(outpoint.hash, i))) {
                    continue;
                }
                
                if (skipDenominated && dash_spv_coinjoin_coinjoin_CoinJoin_is_denominated_amount(output.amount)) {
                    continue;
                }
                
                if (anonymizable) {
                    // ignore collaterals
                    if (dash_spv_coinjoin_coinjoin_CoinJoin_is_collateral_amount(output.amount)) {
                        continue;
                    }
                    
                    // ignore outputs that are 10 times smaller then the smallest denomination
                    // otherwise they will just lead to higher fee / lower priority
                    if (output.amount <= smallestDenom/10) {
                        continue;
                    }
                    
                    // ignore mixed
                    
                    if (dash_spv_coinjoin_wallet_ex_WalletEx_check_if_is_fully_mixed(walletEx, DOutPointCtorU(outpoint.hash, i))) {
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
        NSMutableArray<DSCompactTallyItem *> *vecTallyRet = [NSMutableArray array];
        
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

- (NSArray<DSInputCoin *> *)availableCoins:(WalletEx *)walletEx
                                  onlySafe:(BOOL)onlySafe
                               coinControl:(DSCoinControl *_Nullable)coinControl
                             minimumAmount:(uint64_t)minimumAmount
                             maximumAmount:(uint64_t)maximumAmount
                          minimumSumAmount:(uint64_t)minimumSumAmount
                              maximumCount:(uint64_t)maximumCount {
    NSMutableArray<DSInputCoin *> *vCoins = [NSMutableArray array];
    
    @synchronized(self) {
        DCoinType coinType = coinControl != nil ? coinControl.coinType : dash_spv_coinjoin_models_coin_control_CoinType_AllCoins;
        
        uint64_t total = 0;
        // Either the WALLET_FLAG_AVOID_REUSE flag is not set (in which case we always allow), or we default to avoiding, and only in the case where a coin control object is provided, and has the avoid address reuse flag set to false, do we allow already used addresses
        BOOL allowUsedAddresses = /* !IsWalletFlagSet(WALLET_FLAG_AVOID_REUSE) || */ (coinControl != nil && !coinControl.avoidAddressReuse);
        int32_t minDepth = coinControl != nil ? coinControl.minDepth : DEFAULT_MIN_DEPTH;
        int32_t maxDepth = coinControl != nil ? coinControl.maxDepth : DEFAULT_MAX_DEPTH;
        NSSet<DSTransaction *> *spendables = [self getSpendableTXs];
        
        for (DSTransaction *coin in spendables) {
            UInt256 wtxid = coin.txHash;
            DSAccount *account = self.chain.wallets.firstObject.accounts.firstObject;
            if (!account.coinJoinDerivationPath.addressesLoaded) {
                DSLog(@"[%@] CoinJoin availableCoins: CJDerivationPath addresses NOT loaded", self.chain.name);
            }
            
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
                
                if (coinType == dash_spv_coinjoin_models_coin_control_CoinType_OnlyFullyMixed) {
                    
                    if (!dash_spv_coinjoin_coinjoin_CoinJoin_is_denominated_amount(value)) {
                        continue;
                    }
                    
                    DOutPoint *outpoint = DOutPointCtorU(wtxid, i);
                    found = dash_spv_coinjoin_wallet_ex_WalletEx_check_if_is_fully_mixed(walletEx, outpoint);
                } else if (coinType == dash_spv_coinjoin_models_coin_control_CoinType_OnlyReadyToMix) {
                    if (!dash_spv_coinjoin_coinjoin_CoinJoin_is_denominated_amount(value)) {
                        continue;
                    }
                    DOutPoint *outpoint = DOutPointCtorU(wtxid, i);
                    found = !dash_spv_coinjoin_wallet_ex_WalletEx_check_if_is_fully_mixed(walletEx, outpoint);
                } else if (coinType == dash_spv_coinjoin_models_coin_control_CoinType_OnlyNonDenominated) {
                    if (dash_spv_coinjoin_coinjoin_CoinJoin_is_collateral_amount(value)) {
                        continue; // do not use collateral amounts
                    }
                    found = !dash_spv_coinjoin_coinjoin_CoinJoin_is_denominated_amount(value);
                } else if (coinType == dash_spv_coinjoin_models_coin_control_CoinType_OnlyMasternodeCollateral) {
                    found = value == 1000 * DUFFS_OBJC;
                } else if (coinType == dash_spv_coinjoin_models_coin_control_CoinType_OnlyCoinJoinCollateral) {
                    found = dash_spv_coinjoin_coinjoin_CoinJoin_is_collateral_amount(value);
                } else {
                    found = YES;
                }
                
                if (!found) {
                    continue;
                }
                
                if (value < minimumAmount || value > maximumAmount) {
                    continue;
                }
                
                DSUTXO utxo = ((DSUTXO){wtxid, i});
                
                if (coinControl != nil && coinControl.hasSelected && !coinControl.allowOtherInputs && ![coinControl isSelected:utxo]) {
                    continue;
                }
                if (dash_spv_coinjoin_wallet_ex_WalletEx_is_locked_coin(walletEx, DOutPointCtorU(wtxid, i)) &&
                    coinType != dash_spv_coinjoin_models_coin_control_CoinType_OnlyMasternodeCollateral) {
                    continue;
                }
                
                if ([account isSpent:dsutxo_obj(utxo)]) {
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
                if (minimumSumAmount != MAX_MONEY_OBJC) {
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

- (double)getMixingProgress {
    if (![self.wrapper isRegistered]) {
        [self.wrapper registerCoinJoin:self.options];
    }
    
    double requiredRounds = self.options->coinjoin_rounds + 0.875; // 1 x 50% + 1 x 50%^2 + 1 x 50%^3
    __block int totalInputs = 0;
    __block int totalRounds = 0;
    
    NSDictionary<NSNumber *, NSArray<NSValue *> *> *outputs = [self getOutputs];
    uint64_t collateralAmount = [self.wrapper getCollateralAmount];
    NSArray<NSNumber *> *denominations = [self.wrapper getStandardDenominations];
    
    [outputs enumerateKeysAndObjectsUsingBlock:^(NSNumber *denom, NSArray<NSValue *> *outputs, BOOL *stop) {
        [outputs enumerateObjectsUsingBlock:^(NSValue *output, NSUInteger idx, BOOL *stop) {
            DSUTXO outpoint;
            [output getValue:&outpoint];
            
            if (denom.intValue >= 0) {
                int rounds = [self.wrapper getRealOutpointCoinJoinRounds:outpoint];
                
                if (rounds >= 0) {
                    totalInputs += 1;
                    totalRounds += rounds;
                }
            } else if (denom.intValue == -2) {
                DSTransaction *tx = [self.chain transactionForHash:outpoint.hash];
                DSTransactionOutput *output = tx.outputs[outpoint.n];
                
                __block int unmixedInputs = 0;
                __block int64_t outputValue = output.amount - collateralAmount;
                
                [denominations enumerateObjectsUsingBlock:^(NSNumber *coin, NSUInteger idx, BOOL *stop) {
                    while (outputValue - coin.longLongValue > 0) {
                        unmixedInputs++;
                        outputValue -= coin.longLongValue;
                    }
                }];
                
                totalInputs += unmixedInputs;
            }
        }];
    }];
    
    double progress = totalInputs != 0 ? (double)totalRounds / (requiredRounds * totalInputs) : 0.0;
    
    if (self.lastReportedProgress != progress) {
        _lastReportedProgress = progress;
        DSLog(@"[%@] CoinJoin: getMixingProgress: %f = %d / (%f * %d)", self.chain.name, progress, totalRounds, requiredRounds, totalInputs);
    }
    
    return fmax(0.0, fmin(progress, 1.0));
}

- (NSDictionary<NSNumber *, NSArray<NSValue *> *> *)getOutputs {
    NSMutableDictionary<NSNumber *, NSMutableArray<NSValue *> *> *outputs = [NSMutableDictionary dictionary];
    
    for (NSNumber *amount in [self.wrapper getStandardDenominations]) {
        outputs[@([self.wrapper amountToDenomination:amount.unsignedLongLongValue])] = [NSMutableArray array];
    }
    
    outputs[@(-2)] = [NSMutableArray array];
    outputs[@(0)] = [NSMutableArray array];
    DSAccount *account = self.chain.wallets.firstObject.accounts.firstObject;
    NSArray *utxos = account.unspentOutputs;
    DSUTXO outpoint;
    
    for (NSValue *value in utxos) {
        [value getValue:&outpoint];
        
        DSTransaction *tx = [self.chain transactionForHash:outpoint.hash];
        DSTransactionOutput *output = tx.outputs[outpoint.n];
        NSString *address = [DSKeyManager addressWithScriptPubKey:output.outScript forChain:self.chain];
        
        if ([account containsCoinJoinAddress:address]) {
            int denom = [self.wrapper amountToDenomination:output.amount];
            NSMutableArray<NSValue *> *listDenoms = outputs[@(denom)];
            [listDenoms addObject:value];
        } else {
            // non-denominated and non-collateral coins
            [outputs[@(-2)] addObject:value];
        }
    }
    
    return outputs;
}

+ (BOOL)isDenominatedAmount:(uint64_t)amount {
    return dash_spv_coinjoin_coinjoin_CoinJoin_is_denominated_amount(amount);
}

- (BOOL)isCoinJoinOutput:(DSTransactionOutput *)output utxo:(DSUTXO)utxo {
    if (![self.wrapper isDenominatedAmount:output.amount]) {
        return false;
    }
    
    if (![self.wrapper isFullyMixed:utxo]) {
        return false;
    }
    
    return [self.chain.wallets.firstObject.accounts.firstObject.coinJoinDerivationPath containsAddress:output.address];
}

- (DSCoinJoinBalance *)getBalance {
    if (![self.wrapper isRegistered]) {
        [self.wrapper registerCoinJoin:self.options];
    }
    
    DSAccount *account = self.chain.wallets.firstObject.accounts.firstObject;
    uint64_t anonymizedBalance = 0;
    uint64_t denominatedBalance = 0;
    DSUTXO outpoint;
    NSArray *utxos = account.unspentOutputs;
    
    for (NSValue *value in utxos) {
        [value getValue:&outpoint];
        DSTransaction *tx = [account transactionForHash:outpoint.hash];
        DSTransactionOutput *output = tx.outputs[outpoint.n];
            
        if ([self isCoinJoinOutput:output utxo:outpoint]) {
            anonymizedBalance += output.amount;
        }
        
        if ([self.wrapper isDenominatedAmount:output.amount]) {
            denominatedBalance += output.amount;
        }
    }

    // TODO(DashJ): support more balance types?
    DSCoinJoinBalance *balance =
        [DSCoinJoinBalance balanceWithMyTrusted:self.chain.balance
                             denominatedTrusted:denominatedBalance
                                     anonymized:anonymizedBalance
                                     myImmature:0
                             myUntrustedPending:0
                    denominatedUntrustedPending:0
                               watchOnlyTrusted:0
                      watchOnlyUntrustedPending:0
                              watchOnlyImmature:0];
    
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
    } else {
        address = account.coinJoinReceiveAddress;
    }
    
    return address;
}

- (NSArray *)getIssuedReceiveAddresses {
    DSAccount *account = self.chain.wallets.firstObject.accounts.firstObject;
    return account.allCoinJoinReceiveAddresses;
}

- (NSArray *)getUsedReceiveAddresses {
    DSAccount *account = self.chain.wallets.firstObject.accounts.firstObject;
    return account.usedCoinJoinReceiveAddresses;
}

- (BOOL)commitTransactionForAmounts:(NSArray *)amounts outputs:(NSArray *)outputs coinControl:(DSCoinControl *)coinControl onPublished:(void (^)(UInt256 txId, NSError * _Nullable error))onPublished {
    DSAccount *account = self.chain.wallets.firstObject.accounts.firstObject;
    DSTransaction *transaction = [account transactionForAmounts:amounts toOutputScripts:outputs withFee:YES coinControl:coinControl];
    
    if (!transaction) {
        return NO;
    }
    
    BOOL signedTransaction = [account signTransaction:transaction];
    
    if (!signedTransaction || !transaction.isSigned) {
        DSLog(@"[%@] CoinJoin error: not signed", self.chain.name);
        return NO;
    } else {
        [self.chain.chainManager.transactionManager publishTransaction:transaction completion:^(NSError *error) {
            NSString *txDescription = @"<REDACTED>";
            #if DEBUG
            txDescription = transaction.description;
            #endif
            
            if (error) {
                DSLog(@"[%@] CoinJoin publish error: %@ for tx: %@", self.chain.name, error.description, txDescription);
            } else {
                DSLog(@"[%@] CoinJoin publish success: %@", self.chain.name, txDescription);
            }
            
            dispatch_async(self.processingQueue, ^{
                onPublished(transaction.txHash, error);
            });
        }];
    }
    
    return YES;
}

- (DMasternodeEntry *)masternodeEntryByHash:(UInt256)hash {
    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_current_masternode_list_masternode_with_pro_reg_tx_hash(self.chain.sharedProcessorObj, dashcore_hash_types_ProTxHash_ctor(u256_ctor_u(uint256_reverse(hash))));
}

- (uintptr_t)validMNCount {
    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_valid_masternodes_count(self.chain.sharedProcessorObj);
}

- (DMasternodeList *)mnList {
    return self.chain.chainManager.masternodeManager.currentMasternodeList;
}

- (BOOL)isMasternodeOrDisconnectRequested:(UInt128)ip port:(uint16_t)port {
    return [self.masternodeGroup isMasternodeOrDisconnectRequested:ip port:port];
}

- (BOOL)disconnectMasternode:(UInt128)ip port:(uint16_t)port {
    return [self.masternodeGroup disconnectMasternode:ip port:port];
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
            DSLog(@"[%@] CoinJoin: unknown message type: %@", self.chain.name, messageType);
            return NO;
        }

        return YES;
    }];
}

- (BOOL)addPendingMasternode:(UInt256)proTxHash clientSessionId:(UInt256)sessionId {
    return [self.masternodeGroup addPendingMasternode:proTxHash clientSessionId:sessionId];
}

- (void)updateSuccessBlock {
    self.cachedLastSuccessBlock = self.cachedBlockHeight;
}

- (BOOL)isWaitingForNewBlock {
    if (!self.isChainSynced) {
        return true;
    }
    
    if (self.options->coinjoin_multi_session == true) {
        return false;
    }
    
    return self.cachedBlockHeight - self.cachedLastSuccessBlock < MIN_BLOCKS_TO_WAIT;
}

- (DCoinJoinTransactionType *)coinJoinTxTypeForTransaction:(DSTransaction *)transaction {
    return [DSCoinJoinWrapper coinJoinTxTypeForTransaction:transaction];
}

- (void)calculateAnonymizableBalanceWithSkipDenominated:(BOOL)skipDenominated skipUnconfirmed:(BOOL)skipUnconfirmed completion:(void (^)(uint64_t balance))completion {
    dispatch_async(self.processingQueue, ^{
        uint64_t balance = [self.wrapper getAnonymizableBalance:skipDenominated skipUnconfirmed:skipUnconfirmed];
        completion(balance);
    });
}

- (void)minimumAnonymizableBalanceWithCompletion:(void (^)(uint64_t balance))completion {
    dispatch_async(self.processingQueue, ^{
        uint64_t valueMin = [self.wrapper getSmallestDenomination];
        BOOL hasCollateralInputs = [self.wrapper hasCollateralInputs:YES];
        
        if (hasCollateralInputs) {
            valueMin += [self.wrapper getMaxCollateralAmount];
        }
        
        completion(valueMin);
    });
}

- (uint64_t)getSmallestDenomination {
    return [self.wrapper getSmallestDenomination];
}

- (DSCoinControl *)selectCoinJoinUTXOs {
    DSCoinControl *coinControl = [[DSCoinControl alloc] init];
    [coinControl useCoinJoin:YES];
    NSArray *utxos = self.chain.wallets.firstObject.unspentOutputs;
    
    for (NSValue *value in utxos) {
        DSUTXO utxo;
        [value getValue:&utxo];
        
        DSTransaction *tx = [self.chain transactionForHash:utxo.hash];
        if (!tx) continue;
        
        DSTransactionOutput *output = tx.outputs[utxo.n];
        if (!output) continue;
        
        if ([self isCoinJoinOutput:output utxo:utxo] && ![self.wrapper isLockedCoin:utxo]) {
            [coinControl select:utxo];
        }
    }
    
    return coinControl;
}

- (void)printUsedKeys {
    dispatch_async(self.processingQueue, ^{
        NSArray *issuedAddresses = [self getIssuedReceiveAddresses];
        NSArray *usedAddresses = [self getUsedReceiveAddresses];
        double percent = (double)usedAddresses.count * 100.0 / (double)issuedAddresses.count;
        DSLog(@"[%@] CoinJoin init. Used addresses count %lu out of %lu (%.2f %%)", self.chain.name, (unsigned long)usedAddresses.count, (unsigned long)issuedAddresses.count, percent);
    });
}

// Events

- (void)onSessionStarted:(int32_t)baseId
         clientSessionId:(UInt256)clientId
            denomination:(uint32_t)denom
               poolState:(DPoolState)state
             poolMessage:(DPoolMessage)message
              poolStatus:(DPoolStatus)status
               ipAddress:(UInt128)address
                isJoined:(BOOL)joined {
    DSLog(@"[%@] CoinJoin: onSessionStarted: baseId: %d, clientId: %@, denom: %d, state: %d, message: %d, address: %@, isJoined: %s", self.chain.name, baseId, [uint256_hex(clientId) substringToIndex:7], denom, state, message, [self.masternodeGroup hostFor:address], joined ? "yes" : "no");
    [self.managerDelegate sessionStartedWithId:baseId
                               clientSessionId:clientId
                                  denomination:denom
                                     poolState:state
                                   poolMessage:message
                                    poolStatus:status
                                     ipAddress:address
                                      isJoined:joined];
}

- (void)onSessionComplete:(int32_t)baseId
          clientSessionId:(UInt256)clientId
             denomination:(uint32_t)denom
                poolState:(DPoolState)state
              poolMessage:(DPoolMessage)message
               poolStatus:(DPoolStatus)status
                ipAddress:(UInt128)address
                 isJoined:(BOOL)joined {
    DSLog(@"[%@] CoinJoin: onSessionComplete: baseId: %d, clientId: %@, denom: %d, state: %d, status: %d, message: %d, address: %@, isJoined: %s", self.chain.name, baseId, [uint256_hex(clientId) substringToIndex:7], denom, state, status, message, [self.masternodeGroup hostFor:address], joined ? "yes" : "no");
    [self.managerDelegate sessionCompleteWithId:baseId
                                clientSessionId:clientId
                                   denomination:denom
                                      poolState:state
                                    poolMessage:message
                                     poolStatus:status
                                      ipAddress:address
                                       isJoined:joined];
}

- (void)onMixingStarted:(nonnull NSArray *)statuses {
    DSLog(@"[%@] CoinJoin: onMixingStarted, statuses: %@", self.chain.name, statuses.count > 0 ? [NSString stringWithFormat:@"%@", statuses] : @"empty");
    [self.managerDelegate mixingStarted];
}

- (void)onMixingComplete:(nonnull NSArray *)statuses isInterrupted:(BOOL)isInterrupted {
    if (self.isShuttingDown) {
        [self stop];
    }
    
    DPoolStatus *returnStatus = NULL;
    BOOL isError = YES;
    
    for (NSNumber *statusNumber in statuses) {
        DPoolStatus *status = DPoolStatusFromIndex(statusNumber.intValue);
        if (![self isError:status]) {
            returnStatus = status;
            isError = NO;
            break;
        }
        
        if (!dash_spv_coinjoin_messages_pool_status_PoolStatus_is_err_not_enough_funds(status)) {
            returnStatus = status;
        }
    }

    [self.managerDelegate mixingComplete:isError errorStatus:returnStatus isInterrupted:isInterrupted];
}

- (void)onTransactionProcessed:(UInt256)txId type:(DCoinJoinTransactionType *)type {
#if DEBUG
    DSLog(@"[%@] CoinJoin: onTransactionProcessed: %@, type: %d", self.chain.name, uint256_reverse_hex(txId), DCoinJoinTransactionTypeIndex(type));
#else
    DSLog(@"[%@] CoinJoin: onTransactionProcessed: %@, type: %d", self.chain.name, @"<REDACTED>", type);
#endif
    [self.managerDelegate transactionProcessedWithId:txId type:type];
}

- (BOOL)isError:(DPoolStatus *)status {
    return (DPoolStatusValue(status) & 0x2000) != 0;
}

@end
