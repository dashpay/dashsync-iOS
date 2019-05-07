//
//  DSWallet.m
//  DashSync
//
//  Created by Quantum Explorer on 05/11/18.
//  Copyright (c) 2018 Quantum Explorer <quantum@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSFundsDerivationPath.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSECDSAKey.h"
#import "DSChain.h"

#import "DSTransaction.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSBlockchainUserRegistrationTransaction.h"
#import "DSBlockchainUserResetTransaction.h"
#import "DSBlockchainUserTopupTransaction.h"
#import "DSBlockchainUserCloseTransaction.h"

#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSTxInputEntity+CoreDataClass.h"
#import "DSTxOutputEntity+CoreDataClass.h"

#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "DSPeerManager.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "DSPriceManager.h"
#import "DSGovernanceSyncManager.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSString+Dash.h"
#import "DSAuthenticationManager.h"
#import "DSInsightManager.h"
#import "DSKey+BIP38.h"
#import "NSDate+Utils.h"
#import "DSBIP39Mnemonic.h"
#import "DSCoinbaseTransaction.h"
#import "DSTransactionFactory.h"
#import "DSIncomingFundsDerivationPath.h"

#define LOG_BALANCE_UPDATE 0

#define AUTH_SWEEP_KEY @"AUTH_SWEEP_KEY"
#define AUTH_SWEEP_FEE @"AUTH_SWEEP_FEE"


@class DSFundsDerivationPath,DSIncomingFundsDerivationPath,DSAccount;

@interface DSAccount()

// BIP 43 derivation paths
@property (nonatomic, strong) NSMutableArray<DSDerivationPath *> * mFundDerivationPaths;
@property (nonatomic, strong) NSMutableDictionary<NSData*,DSIncomingFundsDerivationPath *> * mContactIncomingFundDerivationPathsDictionary;
@property (nonatomic, strong) NSMutableDictionary<NSData*,DSIncomingFundsDerivationPath *> * mContactOutgoingFundDerivationPathsDictionary;

@property (nonatomic, strong) NSArray *balanceHistory;

@property (nonatomic, strong) NSSet *spentOutputs, *invalidTx, *pendingTx;
@property (nonatomic, strong) NSMutableOrderedSet *transactions;

@property (nonatomic, strong) NSOrderedSet *utxos;
@property (nonatomic, strong) NSMutableDictionary *allTx;

@property (nonatomic, strong) NSManagedObjectContext * managedObjectContext;

// the total amount spent from the account (excluding change)
@property (nonatomic, readonly) uint64_t totalSent;

// the total amount received to the account (excluding change)
@property (nonatomic, readonly) uint64_t totalReceived;

@property (nonatomic, strong) DSFundsDerivationPath * bip44DerivationPath;

@property (nonatomic, strong) DSFundsDerivationPath * bip32DerivationPath;

@property (nonatomic, strong) DSDerivationPath * masterContactsDerivationPath;

@property (nonatomic, assign) BOOL isViewOnlyAccount;

@property (nonatomic, assign) UInt256 firstTransactionHash;


@end

@implementation DSAccount : NSObject

// MARK: - Initiation

+(DSAccount*)accountWithAccountNumber:(uint32_t)accountNumber withDerivationPaths:(NSArray<DSFundsDerivationPath *> *)derivationPaths inContext:(NSManagedObjectContext* _Nullable)context {
    return [[self alloc] initWithAccountNumber:accountNumber withDerivationPaths:derivationPaths inContext:context];
}

-(void)verifyAndAssignAddedDerivationPaths:(NSArray<DSDerivationPath *> *)derivationPaths {
    for (int i = 0;i<[derivationPaths count];i++) {
        DSDerivationPath * derivationPath = [derivationPaths objectAtIndex:i];
        if (derivationPath.reference == DSDerivationPathReference_BIP32) {
            if (self.bip32DerivationPath) {
                NSAssert(TRUE,@"There should only be one BIP 32 derivation path");
            }
            self.bip32DerivationPath = (DSFundsDerivationPath*)derivationPath;
        } else if (derivationPath.reference == DSDerivationPathReference_BIP44) {
            if (self.bip44DerivationPath) {
                NSAssert(TRUE,@"There should only be one BIP 44 derivation path");
            }
            self.bip44DerivationPath = (DSFundsDerivationPath*)derivationPath;
        } else if (derivationPath.reference == DSDerivationPathReference_ContactBasedFundsRoot) {
            if (self.masterContactsDerivationPath) {
                NSAssert(TRUE,@"There should only be one master contacts derivation path");
            }
            self.masterContactsDerivationPath = derivationPath;
        }
        for (int j = i + 1;j<[derivationPaths count];j++) {
            DSDerivationPath * derivationPath2 = [derivationPaths objectAtIndex:j];
            NSAssert(![derivationPath isDerivationPathEqual:derivationPath2],@"Derivation paths should all be different");
        }
        for (DSDerivationPath * derivationPath3 in self.mFundDerivationPaths) {
            NSAssert(![derivationPath isDerivationPathEqual:derivationPath3],@"Added derivation paths should be different from existing ones on account");
        }
        //to do redo this check
//        if ([self.mFundDerivationPaths count] || i != 0) {
//            NSAssert(([derivationPath indexAtPosition:[derivationPath length] - 1] & ~(BIP32_HARD)) == _accountNumber, @"all derivationPaths need to be on same account");
//        }
    }
}

-(instancetype)initWithAccountNumber:(uint32_t)accountNumber withDerivationPaths:(NSArray<DSFundsDerivationPath *> *)derivationPaths inContext:(NSManagedObjectContext*)context {
    NSParameterAssert(derivationPaths);
    
    if (! (self = [super init])) return nil;
    _accountNumber = accountNumber;
    [self verifyAndAssignAddedDerivationPaths:derivationPaths];
    self.mFundDerivationPaths = [NSMutableArray array];
    self.mContactIncomingFundDerivationPathsDictionary = [NSMutableDictionary dictionary];
    self.mContactOutgoingFundDerivationPathsDictionary = [NSMutableDictionary dictionary];
    for (DSDerivationPath * derivationPath in derivationPaths) {
        if ([derivationPath isKindOfClass:[DSFundsDerivationPath class]]) {
            [self.mFundDerivationPaths addObject:(DSFundsDerivationPath*)derivationPath];
        }
        derivationPath.account = self;
    }
    self.transactions = [NSMutableOrderedSet orderedSet];
    self.allTx = [NSMutableDictionary dictionary];
    self.managedObjectContext = context?context:[NSManagedObject context];
    self.isViewOnlyAccount = FALSE;
    return self;
}

-(instancetype)initAsViewOnlyWithAccountNumber:(uint32_t)accountNumber withDerivationPaths:(NSArray<DSFundsDerivationPath *> *)derivationPaths inContext:(NSManagedObjectContext*)context  {
    NSParameterAssert(derivationPaths);
    
    if (! (self = [self initWithAccountNumber:accountNumber withDerivationPaths:derivationPaths inContext:context])) return nil;
    self.isViewOnlyAccount = TRUE;
    
    return self;
}

-(void)setWallet:(DSWallet *)wallet {
    if (!_wallet) {
        _wallet = wallet;
        [self loadDerivationPaths];
        [self loadTransactions];
    }
}

-(void)loadTransactions {
    if (_wallet.isTransient) return;
    //NSDate *startTime = [NSDate date];
    [self.managedObjectContext performBlockAndWait:^{
        [DSTransactionEntity setContext:self.managedObjectContext];
        [DSAccountEntity setContext:self.managedObjectContext];
        [DSTxInputEntity setContext:self.managedObjectContext];
        [DSTxOutputEntity setContext:self.managedObjectContext];
        [DSDerivationPathEntity setContext:self.managedObjectContext];
        NSUInteger transactionCount = [DSTransactionEntity countObjectsMatching:@"transactionHash.chain == %@",self.wallet.chain.chainEntity];
        if (transactionCount > self.allTx.count) {
            // pre-fetch transaction inputs and outputs
            @autoreleasepool {
                NSFetchRequest * fetchRequest = [DSTxOutputEntity fetchRequest];
                
                //for some reason it is faster to search by the wallet unique id on the account, then it is by the account itself, this might change if there are more than 1 account;
                fetchRequest.predicate = [NSPredicate predicateWithFormat:@"account.walletUniqueID = %@ && account.index = %@" ,self.wallet.uniqueID,@(self.accountNumber)];
                [fetchRequest setRelationshipKeyPathsForPrefetching:@[@"transaction.inputs",@"transaction.outputs",@"transaction.transactionHash",@"spentInInput.transaction.inputs",@"spentInInput.transaction.outputs",@"spentInInput.transaction.transactionHash"]];
                
                NSError * fetchRequestError = nil;
                //NSDate *transactionOutputsStartTime = [NSDate date];
                NSArray * transactionOutputs = [self.managedObjectContext executeFetchRequest:fetchRequest error:&fetchRequestError];
                //DSDLog(@"TransactionOutputsStartTime: %f", -[transactionOutputsStartTime timeIntervalSinceNow]);
                for (DSTxOutputEntity *e in transactionOutputs) {
                    @autoreleasepool {
                        if (e.transaction.transactionHash) {
                            NSValue *hash = uint256_obj(e.transaction.transactionHash.txHash.UInt256);
                            if (self.allTx[hash] == nil) {
                                DSTransaction *transaction = [e.transaction transactionForChain:self.wallet.chain];
                                
                                if (transaction) {
                                    self.allTx[hash] = transaction;
                                    [self.transactions addObject:transaction];
                                }
                            }
                        }
                        
                        DSTxInputEntity * spentInInput = e.spentInInput;
                        
                        if (spentInInput) { //this has been spent, also add the transaction where it is being spent
                            if (spentInInput.transaction.transactionHash) {
                                NSValue *hash = uint256_obj(spentInInput.transaction.transactionHash.txHash.UInt256);
                                if (self.allTx[hash] == nil) {
                                    DSTransaction *transaction = [spentInInput.transaction transactionForChain:self.wallet.chain];
                                    
                                    if (!transaction) continue;
                                    self.allTx[hash] = transaction;
                                    [self.transactions addObject:transaction];
                                }
                            }
                        }
                    }
                }
            }
        }
    }];
    //DSDLog(@"Time: %f", -[startTime timeIntervalSinceNow]);
    [self sortTransactions];
    _balance = UINT64_MAX; // trigger balance changed notification even if balance is zero
    [self updateBalance];
}

- (void)loadDerivationPaths {
    if (!_wallet.isTransient) {
        for (DSFundsDerivationPath * derivationPath in self.fundDerivationPaths) {
            [derivationPath loadAddresses];
        }
    } else {
        for (DSFundsDerivationPath * derivationPath in self.fundDerivationPaths) {
            [derivationPath registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL internal:YES];
            [derivationPath registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL internal:NO];
        }
    }
    if (!self.isViewOnlyAccount) {
        if (self.bip44DerivationPath) {
            self.defaultDerivationPath = self.bip44DerivationPath;
        } else if (self.bip32DerivationPath) {
            self.defaultDerivationPath = self.bip32DerivationPath;
        } else if ([self.fundDerivationPaths objectAtIndex:0] && [[self.fundDerivationPaths objectAtIndex:0] isKindOfClass:[DSFundsDerivationPath class]]) {
            self.defaultDerivationPath = (DSFundsDerivationPath*)[self.fundDerivationPaths objectAtIndex:0];
        }
    }
}

// MARK: - Reinitiation

- (void)wipeBlockchainInfo {
    [self.mFundDerivationPaths removeObjectsInArray:[self.mContactIncomingFundDerivationPathsDictionary allValues]];
    [self.mContactIncomingFundDerivationPathsDictionary removeAllObjects];
    [self.mContactOutgoingFundDerivationPathsDictionary removeAllObjects];
    [self.transactions removeAllObjects];
    [self.allTx removeAllObjects];
    [self updateBalance];
}

// MARK: - Calculated Attributes

-(NSString*)uniqueID {
    return [NSString stringWithFormat:@"%@-0-%u",self.wallet.uniqueID,self.accountNumber]; //0 is for type 0
}

- (uint32_t)blockHeight
{
    static uint32_t height = 0;
    uint32_t h = self.wallet.chain.lastBlockHeight;
    
    if (h > height) height = h;
    return height;
}

// returns the first unused external address
- (NSString *)receiveAddress
{
    return self.defaultDerivationPath.receiveAddress;
}

// returns the first unused internal address
- (NSString *)changeAddress {
    return self.defaultDerivationPath.changeAddress;
}

// NSData objects containing serialized UTXOs
- (NSArray *)unspentOutputs
{
    return self.utxos.array;
}

// MARK: - Derivation Paths

-(void)removeDerivationPath:(DSDerivationPath*)derivationPath {
    NSParameterAssert(derivationPath);
    
    if ([self.mFundDerivationPaths containsObject:derivationPath]) {
        [self.mFundDerivationPaths removeObject:derivationPath];
    }
}

-(void)removeIncomingDerivationPathForFriendshipWithIdentifier:(NSData*)friendshipIdentifier {
    NSParameterAssert(friendshipIdentifier);
    DSIncomingFundsDerivationPath * derivationPath = [self.mContactIncomingFundDerivationPathsDictionary objectForKey:friendshipIdentifier];
    if (derivationPath) {
        [self removeDerivationPath:derivationPath];
    }
}

-(DSIncomingFundsDerivationPath*)derivationPathForFriendshipWithIdentifier:(NSData*)friendshipIdentifier {
    NSParameterAssert(friendshipIdentifier);
    DSIncomingFundsDerivationPath * derivationPath = [self.mContactIncomingFundDerivationPathsDictionary objectForKey:friendshipIdentifier];
    if (derivationPath) return derivationPath;
    return [self.mContactOutgoingFundDerivationPathsDictionary objectForKey:friendshipIdentifier];
}

-(void)addDerivationPath:(DSDerivationPath*)derivationPath {
    NSParameterAssert(derivationPath);
    
    if (!_isViewOnlyAccount) {
        [self verifyAndAssignAddedDerivationPaths:@[derivationPath]];
    }
    [self.mFundDerivationPaths addObject:derivationPath];
}

-(void)addIncomingDerivationPath:(DSIncomingFundsDerivationPath*)derivationPath forFriendshipIdentifier:(NSData*)friendshipIdentifier {
    NSParameterAssert(derivationPath);
    NSParameterAssert(friendshipIdentifier);
    derivationPath.account = self;
    [self addDerivationPath:derivationPath];
    [self.mContactIncomingFundDerivationPathsDictionary setObject:derivationPath forKey:friendshipIdentifier];
    [derivationPath loadAddresses];
    [self updateBalance];
}

-(void)addOutgoingDerivationPath:(DSIncomingFundsDerivationPath*)derivationPath forFriendshipIdentifier:(NSData*)friendshipIdentifier {
    NSParameterAssert(derivationPath);
    NSParameterAssert(friendshipIdentifier);
    derivationPath.account = self;
    [self.mContactOutgoingFundDerivationPathsDictionary setObject:derivationPath forKey:friendshipIdentifier];
    [derivationPath loadAddresses];
    [self updateBalance];
}

-(void)addDerivationPathsFromArray:(NSArray<DSDerivationPath *> *)derivationPaths {
    NSParameterAssert(derivationPaths);
    
    if (!_isViewOnlyAccount) {
        [self verifyAndAssignAddedDerivationPaths:derivationPaths];
    }
    [self.mFundDerivationPaths addObjectsFromArray:derivationPaths];
}

-(NSArray*)fundDerivationPaths {
    return [self.mFundDerivationPaths copy];
}

-(NSArray*)outgoingFundDerivationPaths {
    return [self.mContactOutgoingFundDerivationPathsDictionary allValues];
}

-(void)setDefaultDerivationPath:(DSFundsDerivationPath *)defaultDerivationPath {
    NSAssert([self.mFundDerivationPaths containsObject:defaultDerivationPath], @"The derivationPath is not in the account");
    _defaultDerivationPath = defaultDerivationPath;
}

-(DSDerivationPath*)derivationPathContainingAddress:(NSString *)address {
    for (DSDerivationPath * derivationPath in self.fundDerivationPaths) {
        if ([derivationPath containsAddress:address]) return derivationPath;
    }
    return nil;
}

// MARK: - Addresses from Combined Derivation Paths

-(NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit internal:(BOOL)internal {
    NSMutableArray * mArray = [NSMutableArray array];
    for (DSDerivationPath * derivationPath in self.fundDerivationPaths) {
        if ([derivationPath isKindOfClass:[DSFundsDerivationPath class]]) {
            [mArray addObjectsFromArray:[(DSFundsDerivationPath*)derivationPath registerAddressesWithGapLimit:gapLimit internal:internal]];
        } else if (!internal && [derivationPath isKindOfClass:[DSIncomingFundsDerivationPath class]]) {
            [mArray addObjectsFromArray:[(DSIncomingFundsDerivationPath*)derivationPath registerAddressesWithGapLimit:gapLimit]];
        }
        
    }
    return [mArray copy];
}

// all previously generated external addresses
-(NSArray *)externalAddresses {
    NSMutableSet * mSet = [NSMutableSet set];
    for (DSDerivationPath * derivationPath in self.fundDerivationPaths) {
        [mSet addObjectsFromArray:[(id)derivationPath allReceiveAddresses]];
    }
    return [mSet allObjects];
}

// all previously generated internal addresses
-(NSArray *)internalAddresses {
    NSMutableSet * mSet = [NSMutableSet set];
    for (DSDerivationPath * derivationPath in self.fundDerivationPaths) {
        if ([derivationPath isKindOfClass:[DSFundsDerivationPath class]]) {
            [mSet addObjectsFromArray:[(DSFundsDerivationPath*)derivationPath allChangeAddresses]];
        }
    }
    return [mSet allObjects];
}

-(NSSet *)allAddresses {
    NSMutableSet * mSet = [NSMutableSet set];
    for (DSFundsDerivationPath * derivationPath in self.fundDerivationPaths) {
        [mSet addObjectsFromArray:[[derivationPath allAddresses] allObjects]];
    }
    return [mSet copy];
}

-(NSSet *)usedAddresses {
    NSMutableSet * mSet = [NSMutableSet set];
    for (DSFundsDerivationPath * derivationPath in self.fundDerivationPaths) {
        [mSet addObjectsFromArray:[[derivationPath usedAddresses] allObjects]];
    }
    return [mSet copy];
}

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString *)address {
    NSParameterAssert(address);
    
    for (DSFundsDerivationPath * derivationPath in self.fundDerivationPaths) {
        if ([derivationPath containsAddress:address]) return TRUE;
    }
    return FALSE;
}

- (BOOL)baseDerivationPathsContainAddress:(NSString *)address {
    NSParameterAssert(address);
    
    for (DSFundsDerivationPath * derivationPath in self.fundDerivationPaths) {
        if ([derivationPath isKindOfClass:[DSFundsDerivationPath class]]) {
            if ([derivationPath containsAddress:address]) return TRUE;
        }
    }
    return FALSE;
}

- (DSIncomingFundsDerivationPath*)externalDerivationPathContainingAddress:(NSString *)address {
    NSParameterAssert(address);
    
    for (DSIncomingFundsDerivationPath * derivationPath in self.mContactOutgoingFundDerivationPathsDictionary.allValues) {
        if ([derivationPath containsAddress:address]) return derivationPath;
    }
    return FALSE;
}

// true if the address was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsed:(NSString *)address {
    NSParameterAssert(address);
    
    for (DSFundsDerivationPath * derivationPath in self.fundDerivationPaths) {
        if ([derivationPath addressIsUsed:address]) return TRUE;
    }
    return FALSE;
}

- (BOOL)transactionAddressAlreadySeenInOutputs:(NSString *)address {
    NSParameterAssert(address);
    
    for (DSTransaction * transaction in self.allTransactions) {
        if ([transaction.outputAddresses containsObject:address]) return TRUE;
    }
    return FALSE;
}

// MARK: - Balance

- (void)updateBalance
{
    
    uint64_t balance = 0, prevBalance = 0, totalSent = 0, totalReceived = 0;
    NSMutableOrderedSet *utxos = [NSMutableOrderedSet orderedSet];
    NSMutableSet *spentOutputs = [NSMutableSet set], *invalidTx = [NSMutableSet set], *pendingTx = [NSMutableSet set];
    NSMutableArray *balanceHistory = [NSMutableArray array];
    uint32_t now = [NSDate timeIntervalSince1970];
    
    for (DSFundsDerivationPath * derivationPath in self.fundDerivationPaths) {
        derivationPath.balance = 0;
    }
    
    for (DSTransaction *tx in [self.transactions reverseObjectEnumerator]) {
#if LOG_BALANCE_UPDATE
        DSDLog(@"updating balance after transaction %@",[NSData dataWithUInt256:tx.txHash].reverse.hexString);
#endif
        @autoreleasepool {
            NSMutableSet *spent = [NSMutableSet set];
            NSSet *inputs;
            uint32_t i = 0, n = 0;
            BOOL pending = NO;
            UInt256 h;
            
            for (NSValue *hash in tx.inputHashes) {
                n = [tx.inputIndexes[i++] unsignedIntValue];
                [hash getValue:&h];
                [spent addObject:dsutxo_obj(((DSUTXO) { h, n }))];
            }
            
            inputs = [NSSet setWithArray:tx.inputHashes];
            
            // check if any inputs are invalid or already spent
            if (tx.blockHeight == TX_UNCONFIRMED &&
                ([spent intersectsSet:spentOutputs] || [inputs intersectsSet:invalidTx])) {
                [invalidTx addObject:uint256_obj(tx.txHash)];
                [balanceHistory insertObject:@(balance) atIndex:0];
                continue;
            }
            
            [spentOutputs unionSet:spent]; // add inputs to spent output set
            n = 0;
            
            // check if any inputs are pending
            if (tx.blockHeight == TX_UNCONFIRMED) {
                if (tx.size > TX_MAX_SIZE) {
                    pending = YES; // check transaction size is under TX_MAX_SIZE
                }
                
                for (NSNumber *sequence in tx.inputSequences) {
                    if (sequence.unsignedIntValue < UINT32_MAX - 1) {
                        pending = YES; // check for replace-by-fee
                    }
                    if (sequence.unsignedIntValue < UINT32_MAX && tx.lockTime < TX_MAX_LOCK_HEIGHT &&
                        tx.lockTime > self.wallet.chain.bestBlockHeight + 1) {
                        pending = YES; // future lockTime
                    }
                    if (sequence.unsignedIntValue < UINT32_MAX && tx.lockTime >= TX_MAX_LOCK_HEIGHT &&
                        tx.lockTime > now) {
                        pending = YES; // future locktime
                    }
                }
                
                for (NSNumber *amount in tx.outputAmounts) { // check that no outputs are dust
                    if (amount.unsignedLongLongValue < TX_MIN_OUTPUT_AMOUNT) {
                        pending = YES;
                    }
                }
                
            }
            
            if ([self transactionOutputsAreLocked:tx]) pending = YES;
            
            if (pending || [inputs intersectsSet:pendingTx]) {
                [pendingTx addObject:uint256_obj(tx.txHash)];
                [balanceHistory insertObject:@(balance) atIndex:0];
                continue;
            }
            
            //TODO: don't add outputs below TX_MIN_OUTPUT_AMOUNT
            //TODO: don't add coin generation outputs < 100 blocks deep
            //NOTE: balance/UTXOs will then need to be recalculated when last block changes
            for (NSString *address in tx.outputAddresses) { // add outputs to UTXO set
                for (DSFundsDerivationPath * derivationPath in self.fundDerivationPaths) {
                    if ([derivationPath containsAddress:address]) {
                        derivationPath.balance += [tx.outputAmounts[n] unsignedLongLongValue];
                        [utxos addObject:dsutxo_obj(((DSUTXO) { tx.txHash, n }))];
                        balance += [tx.outputAmounts[n] unsignedLongLongValue];
                    }
                }
                
                n++;
            }
            
            // transaction ordering is not guaranteed, so check the entire UTXO set against the entire spent output set
            [spent setSet:utxos.set];
            [spent intersectSet:spentOutputs];
            
            for (NSValue *output in spent) { // remove any spent outputs from UTXO set
                DSTransaction *transaction;
                DSUTXO o;
                
                [output getValue:&o];
                transaction = self.allTx[uint256_obj(o.hash)];
                [utxos removeObject:output];
                balance -= [transaction.outputAmounts[o.n] unsignedLongLongValue];
                for (DSFundsDerivationPath * derivationPath in self.fundDerivationPaths) {
                    if ([derivationPath containsAddress:transaction.outputAddresses[o.n]]) {
                        derivationPath.balance -= [transaction.outputAmounts[o.n] unsignedLongLongValue];
                        break;
                    }
                }
            }
            
            if (prevBalance < balance) totalReceived += balance - prevBalance;
            if (balance < prevBalance) totalSent += prevBalance - balance;
            [balanceHistory insertObject:@(balance) atIndex:0];
            prevBalance = balance;
#if LOG_BALANCE_UPDATE
            DSDLog(@"===UTXOS===");
            for (NSValue * utxo in utxos) {
                DSUTXO o;
                [utxo getValue:&o];
                DSDLog(@"--%@ (%lu)",[NSData dataWithUInt256:o.hash].reverse.hexString,o.n);
            }
            DSDLog(@"===Spent Outputs===");
            for (NSValue * utxo in spentOutputs) {
                DSUTXO o;
                [utxo getValue:&o];
                DSDLog(@"--%@ (%lu)",[NSData dataWithUInt256:o.hash].reverse.hexString,o.n);
            }
#endif
        }
    }
    
    self.invalidTx = invalidTx;
    self.pendingTx = pendingTx;
    self.spentOutputs = spentOutputs;
    self.utxos = utxos;
    self.balanceHistory = balanceHistory;
    _totalSent = totalSent;
    _totalReceived = totalReceived;
    
    if (balance != _balance) {
        _balance = balance;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(postBalanceDidChangeNotification) object:nil];
            [self performSelector:@selector(postBalanceDidChangeNotification) withObject:nil afterDelay:0.1];
        });
    }
}

// historical wallet balance after the given transaction, or current balance if transaction is not registered in wallet
- (uint64_t)balanceAfterTransaction:(DSTransaction *)transaction
{
    NSParameterAssert(transaction);
    
    NSUInteger i = [self.transactions indexOfObject:transaction];
    
    return (i < self.balanceHistory.count) ? [self.balanceHistory[i] unsignedLongLongValue] : self.balance;
}


- (void)postBalanceDidChangeNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil];
}

// MARK: - Transactions

// MARK: = Helpers

// chain position of first tx output address that appears in chain
static NSUInteger transactionAddressIndex(DSTransaction *transaction, NSArray *addressChain) {
    for (NSString *address in transaction.outputAddresses) {
        NSUInteger i = [addressChain indexOfObject:address];
        
        if (i != NSNotFound) return i;
    }
    
    return NSNotFound;
}

// this sorts transactions by block height in descending order, and makes a best attempt at ordering transactions within
// each block, however correct transaction ordering cannot be relied upon for determining wallet balance or UTXO set
- (void)sortTransactions
{
    BOOL (^isAscending)(id, id);
    __block __weak BOOL (^_isAscending)(id, id) = isAscending = ^BOOL(DSTransaction *tx1, DSTransaction *tx2) {
        if (! tx1 || ! tx2) return NO;
        if (tx1.blockHeight > tx2.blockHeight) return YES;
        if (tx1.blockHeight < tx2.blockHeight) return NO;
        
        NSValue *hash1 = uint256_obj(tx1.txHash), *hash2 = uint256_obj(tx2.txHash);
        
        if ([tx1.inputHashes containsObject:hash2]) return YES;
        if ([tx2.inputHashes containsObject:hash1]) return NO;
        if ([self.invalidTx containsObject:hash1] && ! [self.invalidTx containsObject:hash2]) return YES;
        if ([self.pendingTx containsObject:hash1] && ! [self.pendingTx containsObject:hash2]) return YES;
        
        for (NSValue *hash in tx1.inputHashes) {
            if (_isAscending(self.allTx[hash], tx2)) return YES;
        }
        
        return NO;
    };
    
    [self.transactions sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(id tx1, id tx2) {
        if (isAscending(tx1, tx2)) return NSOrderedAscending;
        if (isAscending(tx2, tx1)) return NSOrderedDescending;
        
        NSUInteger i = transactionAddressIndex(tx1, self.internalAddresses);
        NSUInteger j = transactionAddressIndex(tx2, (i == NSNotFound) ? self.externalAddresses : self.internalAddresses);
        
        if (i == NSNotFound && j != NSNotFound) i = transactionAddressIndex(tx1, self.externalAddresses);
        if (i == NSNotFound || j == NSNotFound || i == j) return NSOrderedSame;
        return (i > j) ? NSOrderedAscending : NSOrderedDescending;
    }];
}

// MARK: = Retrieval

// MARK: == Classical Transaction Retrieval

// returns the transaction with the given hash if it's been registered in the wallet (might also return non-registered)
- (DSTransaction *)transactionForHash:(UInt256)txHash
{
    return self.allTx[uint256_obj(txHash)];
}

// last 100 transactions sorted by date, most recent first
- (NSArray *)recentTransactions
{
    return [self.transactions.array subarrayWithRange:NSMakeRange(0, (self.transactions.count > 100) ? 100 :
                                                                  self.transactions.count)];
}

// last 100 transactions sorted by date, most recent first
- (NSArray *)recentTransactionsWithInternalOutput
{
    NSMutableArray * recentTransactionArray = [NSMutableArray array];
    int i = 0;
    while (recentTransactionArray.count < 100 && i<self.transactions.count) {
        DSTransaction * transaction = [self.transactions objectAtIndex:i];
        if ([transaction hasNonDustOutputInWallet:self.wallet]) {
            [recentTransactionArray addObject:transaction];
        }
        i++;
    }
    return [NSArray arrayWithArray:recentTransactionArray];
}

// all wallet transactions sorted by date, most recent first
- (NSArray *)allTransactions
{
    return self.transactions.array;
}

// MARK: = Existence

// true if the given transaction is associated with the account (even if it hasn't been registered), false otherwise
- (BOOL)canContainTransaction:(DSTransaction *)transaction
{
    NSParameterAssert(transaction);
    
    if ([[NSSet setWithArray:transaction.outputAddresses] intersectsSet:self.allAddresses]) return YES;
    
    NSInteger i = 0;
    
    for (NSValue *txHash in transaction.inputHashes) {
        DSTransaction *tx = self.allTx[txHash];
        uint32_t n = [transaction.inputIndexes[i++] unsignedIntValue];
        
        if (n < tx.outputAddresses.count && [self containsAddress:tx.outputAddresses[n]]) return YES;
    }
    
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction * providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
        if ([self containsAddress:providerRegistrationTransaction.payoutAddress]) return YES;
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction * providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)transaction;
        if ([self containsAddress:providerUpdateServiceTransaction.payoutAddress]) return YES;
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction * providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)transaction;
        if ([self containsAddress:providerUpdateRegistrarTransaction.payoutAddress]) return YES;
    }
    
    return NO;
}

-(BOOL)checkIsFirstTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    
    for (DSDerivationPath * derivationPath in self.fundDerivationPaths) {
        if ([derivationPath type] & DSDerivationPathType_IsForFunds)  {
            NSString * firstAddress;
            if ([derivationPath isKindOfClass:[DSFundsDerivationPath class]]) {
                firstAddress = [(DSFundsDerivationPath*)derivationPath addressAtIndex:0 internal:NO];
            } else if ([derivationPath isKindOfClass:[DSIncomingFundsDerivationPath class]]) {
                firstAddress = [(DSIncomingFundsDerivationPath*)derivationPath addressAtIndex:0];
            }
            
            if ([transaction.outputAddresses containsObject:firstAddress]) {
                return TRUE;
            }
        }
    }
    return FALSE;
}

// MARK: = Creation

// returns an unsigned transaction that sends the specified amount from the wallet to the given address
- (DSTransaction *)transactionFor:(uint64_t)amount to:(NSString *)address withFee:(BOOL)fee
{
    NSParameterAssert(address);
    
    NSMutableData *script = [NSMutableData data];
    
    [script appendScriptPubKeyForAddress:address forChain:self.wallet.chain];
    
    return [self transactionForAmounts:@[@(amount)] toOutputScripts:@[script] withFee:fee];
}


// returns an unsigned transaction that sends the specified amounts from the wallet to the specified output scripts
- (DSTransaction *)transactionForAmounts:(NSArray *)amounts toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee {
    return [self transactionForAmounts:amounts toOutputScripts:scripts withFee:fee isInstant:FALSE toShapeshiftAddress:nil];
}

// returns an unsigned transaction that sends the specified amounts from the wallet to the specified output scripts
- (DSTransaction *)transactionForAmounts:(NSArray *)amounts toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee  isInstant:(BOOL)isInstant {
    return [self transactionForAmounts:amounts toOutputScripts:scripts withFee:fee isInstant:isInstant toShapeshiftAddress:nil];
}

- (DSTransaction *)transactionForAmounts:(NSArray *)amounts toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee isInstant:(BOOL)isInstant toShapeshiftAddress:(NSString*)shapeshiftAddress {
    NSParameterAssert(amounts);
    NSParameterAssert(scripts);
    DSTransaction *transaction = [[DSTransaction alloc] initOnChain:self.wallet.chain];
    return [self updateTransaction:transaction forAmounts:amounts toOutputScripts:scripts withFee:fee isInstant:isInstant toShapeshiftAddress:shapeshiftAddress shuffleOutputOrder:YES];
}

// MARK: == Proposal Transaction Creation

- (DSTransaction *)proposalCollateralTransactionWithData:(NSData*)data
{
    NSParameterAssert(data);
    
    NSMutableData *script = [NSMutableData data];
    
    [script appendProposalInfo:data];
    
    return [self transactionForAmounts:@[@(PROPOSAL_COST)] toOutputScripts:@[script] withFee:TRUE];
}

// MARK: = Update

// returns an unsigned transaction that sends the specified amounts from the wallet to the specified output scripts
- (DSTransaction *)updateTransaction:(DSTransaction*)transaction forAmounts:(NSArray *)amounts toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee isInstant:(BOOL)isInstant {
    return [self updateTransaction:transaction forAmounts:amounts toOutputScripts:scripts withFee:fee isInstant:isInstant toShapeshiftAddress:nil shuffleOutputOrder:YES];
}

// returns an unsigned transaction that sends the specified amounts from the wallet to the specified output scripts
- (DSTransaction *)updateTransaction:(DSTransaction*)transaction forAmounts:(NSArray *)amounts toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee isInstant:(BOOL)isInstant toShapeshiftAddress:(NSString*)shapeshiftAddress shuffleOutputOrder:(BOOL)shuffleOutputOrder
{
    NSParameterAssert(transaction);
    NSParameterAssert(amounts);
    NSParameterAssert(scripts);
    
    uint64_t amount = 0, balance = 0, feeAmount = 0, feeAmountWithoutChange = 0;
    DSTransaction *tx;
    NSUInteger i = 0, cpfpSize = 0;
    DSUTXO o;
    
    if (amounts.count != scripts.count /*|| amounts.count < 1*/) return nil; // sanity check
    
    for (NSData *script in scripts) {
        if (script.length == 0) return nil;
        [transaction addOutputScript:script amount:[amounts[i] unsignedLongLongValue]];
        amount += [amounts[i++] unsignedLongLongValue];
    }
    
    //TODO: use up all UTXOs for all used addresses to avoid leaving funds in addresses whose public key is revealed
    //TODO: avoid combining addresses in a single transaction when possible to reduce information leakage
    //TODO: use up UTXOs received from any of the output scripts that this transaction sends funds to, to mitigate an
    //      attacker double spending and requesting a refund
    for (NSValue *output in self.utxos) {
        [output getValue:&o];
        tx = self.allTx[uint256_obj(o.hash)];
        if ([self transactionOutputsAreLocked:tx]) continue;
        if (! tx) continue;
        //for example the tx block height is 25, can only send after the chain block height is 31 for previous confirmations needed of 6
        if (isInstant && (tx.blockHeight >= (self.blockHeight - self.wallet.chain.ixPreviousConfirmationsNeeded))) continue;
        
        if ([transaction isMemberOfClass:[DSProviderRegistrationTransaction class]]) {
            DSProviderRegistrationTransaction * providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
            if (dsutxo_eq(providerRegistrationTransaction.collateralOutpoint,o)) {
                continue; //don't spend the collateral
            }
            DSUTXO reversedCollateral = (DSUTXO) { .hash = uint256_reverse(providerRegistrationTransaction.collateralOutpoint.hash), providerRegistrationTransaction.collateralOutpoint.n };
            
            if (dsutxo_eq(reversedCollateral,o)) {
                continue; //don't spend the collateral
            }
        }
        [transaction addInputHash:tx.txHash index:o.n script:tx.outputScripts[o.n]];
        
        if (transaction.size + TX_OUTPUT_SIZE > TX_MAX_SIZE) { // transaction size-in-bytes too large
            NSUInteger txSize = 10 + self.utxos.count*148 + (scripts.count + 1)*TX_OUTPUT_SIZE;
            
            // check for sufficient total funds before building a smaller transaction
            if (self.balance < amount + [self.wallet.chain feeForTxSize:txSize + cpfpSize isInstant:isInstant inputCount:transaction.inputHashes.count]) {
                DSDLog(@"Insufficient funds. %llu is less than transaction amount:%llu", self.balance,
                       amount + [self.wallet.chain feeForTxSize:txSize + cpfpSize isInstant:isInstant inputCount:transaction.inputHashes.count]);
                return nil;
            }
            
            uint64_t lastAmount = [amounts.lastObject unsignedLongLongValue];
            NSArray *newAmounts = [amounts subarrayWithRange:NSMakeRange(0, amounts.count - 1)],
            *newScripts = [scripts subarrayWithRange:NSMakeRange(0, scripts.count - 1)];
            
            if (lastAmount > amount + feeAmount + self.wallet.chain.minOutputAmount - balance) { // reduce final output amount
                newAmounts = [newAmounts arrayByAddingObject:@(lastAmount - (amount + feeAmount - balance))];
                newScripts = [newScripts arrayByAddingObject:scripts.lastObject];
            }
            
            return [self transactionForAmounts:newAmounts toOutputScripts:newScripts withFee:fee];
        }
        
        balance += [tx.outputAmounts[o.n] unsignedLongLongValue];
        
        // add up size of unconfirmed, non-change inputs for child-pays-for-parent fee calculation
        // don't include parent tx with more than 10 inputs or 10 outputs
        if (tx.blockHeight == TX_UNCONFIRMED && tx.inputHashes.count <= 10 && tx.outputAmounts.count <= 10 &&
            [self amountSentByTransaction:tx] == 0) cpfpSize += tx.size;
        
        if (fee) {
            feeAmountWithoutChange = [self.wallet.chain feeForTxSize:transaction.size + cpfpSize isInstant:isInstant inputCount:transaction.inputHashes.count];
            if (balance == amount + feeAmountWithoutChange) {
                feeAmount = feeAmountWithoutChange;
                break;
            }
            feeAmount = [self.wallet.chain feeForTxSize:transaction.size + TX_OUTPUT_SIZE + cpfpSize isInstant:isInstant inputCount:transaction.inputHashes.count]; // assume we will add a change output
            //if (self.balance > amount) feeAmount += (self.balance - amount) % 100; // round off balance to 100 satoshi
        }
        
        if (balance == amount + feeAmount || balance >= amount + feeAmount + self.wallet.chain.minOutputAmount) break;
    }
    
    transaction.desiresInstantSendSending = isInstant;
    
    if (!feeAmount) {
        feeAmount = [self.wallet.chain feeForTxSize:transaction.size + TX_OUTPUT_SIZE + cpfpSize isInstant:isInstant inputCount:transaction.inputHashes.count]; // assume we will add a change output
    }
    
    if (balance < amount + feeAmount) { // insufficient funds
        DSDLog(@"Insufficient funds. %llu is less than transaction amount:%llu", balance, amount + feeAmount);
        return nil;
    }
    
    if (shapeshiftAddress) {
        [transaction addOutputShapeshiftAddress:shapeshiftAddress];
    }
    
    if (balance - (amount + feeAmount) >= self.wallet.chain.minOutputAmount) {
        [transaction addOutputAddress:self.changeAddress amount:balance - (amount + feeAmount)];
        if (shuffleOutputOrder) {
            [transaction shuffleOutputOrder];
        }
    }
    
    [transaction hasSetInputsAndOutputs];
    
    return transaction;
}

- (void)chainUpdatedBlockHeight:(int32_t)height {
    if ([self.pendingTx count]) {
        [self updateBalance];
    }
}

// set the block heights and timestamps for the given transactions, use a height of TX_UNCONFIRMED and timestamp of 0 to
// indicate a transaction and it's dependents should remain marked as unverified (not 0-conf safe)
- (NSArray *)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes
{
    NSMutableArray *hashes = [NSMutableArray array], *updated = [NSMutableArray array];
    BOOL needsUpdate = NO;
    NSTimeInterval walletCreationTime = [self.wallet walletCreationTime];
    for (NSValue *hash in txHashes) {
        DSTransaction *tx = self.allTx[hash];
        UInt256 h;
        
        if (! tx || (tx.blockHeight == height && tx.timestamp == timestamp)) continue;
        DSDLog(@"Setting tx %@ height to %d",tx,height);
        tx.blockHeight = height;
        tx.timestamp = timestamp;
        
        if ([self canContainTransaction:tx]) {
            [hash getValue:&h];
            [hashes addObject:[NSData dataWithBytes:&h length:sizeof(h)]];
            [updated addObject:hash];
            
            if ((walletCreationTime == BIP39_WALLET_UNKNOWN_CREATION_TIME || walletCreationTime == BIP39_CREATION_TIME) && uint256_eq(h, _firstTransactionHash)) {
                [self.wallet setGuessedWalletCreationTime:tx.timestamp - HOUR_TIME_INTERVAL - (DAY_TIME_INTERVAL/arc4random()%DAY_TIME_INTERVAL)];
            }
            if ([self.pendingTx containsObject:hash] || [self.invalidTx containsObject:hash]) needsUpdate = YES;
        }
        else if (height != TX_UNCONFIRMED) [self.allTx removeObjectForKey:hash]; // remove confirmed non-wallet tx
    }
    
    if (hashes.count > 0) {
        if (needsUpdate) {
            [self sortTransactions];
            [self updateBalance];
        }
        
        [self.managedObjectContext performBlockAndWait:^{
            @autoreleasepool {
                NSMutableSet *entities = [NSMutableSet set];
                
                for (DSTransactionHashEntity *e in [DSTransactionHashEntity objectsMatching:@"txHash in %@", hashes]) {
                    if (e.blockHeight != height || e.timestamp != timestamp) {
                        e.blockHeight = height;
                        e.timestamp = timestamp;
                        [entities addObject:e];
                    }
                }
                
                //                if (height != TX_UNCONFIRMED) {
                //                    // BUG: XXX saving the tx.blockHeight and the block it's contained in both need to happen together
                //                    // as an atomic db operation. If the tx.blockHeight is saved but the block isn't when the app exits,
                //                    // then a re-org that happens afterward can potentially result in an invalid tx showing as confirmed
                //
                //                    for (NSManagedObject *e in entities) {
                //                        [self.moc refreshObject:e mergeChanges:NO];
                //                    }
                //                }
                for (DSTransactionHashEntity *e in entities) {
                    DSDLog(@"blockHeight is %u for %@",e.blockHeight,e.txHash);
                }
                if (entities.count) {
                    NSError * error = nil;
                    [self.managedObjectContext save:&error];
                    if (error) {
                        DSDLog(@"Issue Saving DB when setting Block Height");
                    }
                }
            }
        }];
    }
    
    return updated;
}

// MARK: = Removal

// removes a transaction from the wallet along with any transactions that depend on its outputs
- (BOOL)removeTransactionWithHash:(UInt256)txHash
{
    DSTransaction *transaction = self.allTx[uint256_obj(txHash)];
    if (!transaction) return FALSE;
    return [self removeTransaction:transaction];
}

- (BOOL)removeTransaction:(DSTransaction*)baseTransaction {
    NSParameterAssert(baseTransaction);
    
    NSMutableSet *dependentTransactions = [NSMutableSet set];
    DSTransaction *transaction = self.allTx[uint256_obj(baseTransaction.txHash)];
    if (!transaction) return FALSE;
    UInt256 transactionHash = transaction.txHash;
    for (DSTransaction *possibleDependentTransaction in self.transactions) { // remove dependent transactions
        if (possibleDependentTransaction.blockHeight < transaction.blockHeight) break; //because transactions are sorted we can break
        
        if (!uint256_eq(transactionHash, possibleDependentTransaction.txHash) && [possibleDependentTransaction.inputHashes containsObject:uint256_obj(transactionHash)]) {
            //this transaction is dependent on one we want to remove
            [dependentTransactions addObject:possibleDependentTransaction];
        }
    }
    
    for (DSTransaction *transaction in dependentTransactions) {
        //remove all dependent transactions
        [self removeTransaction:transaction];
    }
    
    [self.allTx removeObjectForKey:uint256_obj(transactionHash)];
    [self.transactions removeObject:transaction];
    
    [self updateBalance];
    
    [self.managedObjectContext performBlock:^{ // remove transaction from core data
        [DSTransactionHashEntity deleteObjects:[DSTransactionHashEntity objectsMatching:@"txHash == %@",
                                                [NSData dataWithUInt256:transactionHash]]];
    }];
    return TRUE;
}

// MARK: = Signing

// sign any inputs in the given transaction that can be signed using private keys from the wallet
- (void)signTransaction:(DSTransaction *)transaction withPrompt:(NSString * _Nullable)authprompt completion:(TransactionValidityCompletionBlock)completion;
{
    NSParameterAssert(transaction);
    
    if (_isViewOnlyAccount) return;
    int64_t amount = [self amountSentByTransaction:transaction] - [self amountReceivedFromTransaction:transaction];
    
    NSMutableArray * usedDerivationPaths = [NSMutableArray array];
    for (DSFundsDerivationPath * derivationPath in self.fundDerivationPaths) {
        NSMutableOrderedSet *externalIndexes = [NSMutableOrderedSet orderedSet],
        *internalIndexes = [NSMutableOrderedSet orderedSet];
        for (NSString *addr in transaction.inputAddresses) {
            
            if (!(derivationPath.type == DSDerivationPathType_ClearFunds || derivationPath.type == DSDerivationPathType_AnonymousFunds)) continue;
            if ([derivationPath isKindOfClass:[DSFundsDerivationPath class]]) {
                NSInteger index = [derivationPath.allChangeAddresses indexOfObject:addr];
                if (index != NSNotFound) {
                    [internalIndexes addObject:@(index)];
                    continue;
                }
            }
            NSInteger index = [derivationPath.allReceiveAddresses indexOfObject:addr];
            if (index != NSNotFound) {
                [externalIndexes addObject:@(index)];
                continue;
            }
        }
        if ([externalIndexes count] || [internalIndexes count]) {
            [usedDerivationPaths addObject:@{@"derivationPath":derivationPath,@"externalIndexes":externalIndexes,@"internalIndexes":internalIndexes}];
        }
    }
    
    @autoreleasepool { // @autoreleasepool ensures sensitive data will be dealocated immediately
        self.wallet.seedRequestBlock(authprompt, (amount > 0) ? amount : 0,^void (NSData * _Nullable seed, BOOL cancelled) {
            if (! seed) {
                if (completion) completion(NO,YES);
            } else {
                NSMutableArray *privkeys = [NSMutableArray array];
                for (NSDictionary * dictionary in usedDerivationPaths) {
                    DSDerivationPath * derivationPath = dictionary[@"derivationPath"];
                    NSMutableOrderedSet *externalIndexes = dictionary[@"externalIndexes"],
                    *internalIndexes = dictionary[@"internalIndexes"];
                    if ([derivationPath isKindOfClass:[DSFundsDerivationPath class]]) {
                        DSFundsDerivationPath * fundsDerivationPath = (DSFundsDerivationPath *)derivationPath;
                        [privkeys addObjectsFromArray:[fundsDerivationPath privateKeys:externalIndexes.array internal:NO fromSeed:seed]];
                        [privkeys addObjectsFromArray:[fundsDerivationPath privateKeys:internalIndexes.array internal:YES fromSeed:seed]];
                    } else if ([derivationPath isKindOfClass:[DSIncomingFundsDerivationPath class]]) {
                        DSIncomingFundsDerivationPath * incomingFundsDerivationPath = (DSIncomingFundsDerivationPath *)derivationPath;
                        [privkeys addObjectsFromArray:[incomingFundsDerivationPath privateKeys:externalIndexes.array fromSeed:seed]];
                    } else {
                        NSAssert(FALSE, @"The derivation path must be a normal or incoming funds derivation path");
                    }
                   
                }
                
                BOOL signedSuccessfully = [transaction signWithPrivateKeys:privkeys];
                if (completion) completion(signedSuccessfully,NO);
            }
        });
    }
}

// sign any inputs in the given transaction that can be signed using private keys from the wallet
- (void)signTransactions:(NSArray<DSTransaction *>*)transactions withPrompt:(NSString *)authprompt completion:(TransactionValidityCompletionBlock)completion
{
    if (_isViewOnlyAccount) return;
    
    int64_t amount = 0;
    for (DSTransaction * transaction in transactions) {
        amount += [self amountSentByTransaction:transaction] - [self amountReceivedFromTransaction:transaction];
    }
    self.wallet.seedRequestBlock(authprompt, (amount > 0) ? amount : 0,^void (NSData * _Nullable seed, BOOL cancelled) {
        for (DSTransaction * transaction in transactions) {
            NSMutableArray * usedDerivationPaths = [NSMutableArray array];
            for (DSFundsDerivationPath * derivationPath in self.fundDerivationPaths) {
                NSMutableOrderedSet *externalIndexes = [NSMutableOrderedSet orderedSet],
                *internalIndexes = [NSMutableOrderedSet orderedSet];
                for (NSString *addr in transaction.inputAddresses) {
                    
                    if (!(derivationPath.type == DSDerivationPathType_ClearFunds || derivationPath.type == DSDerivationPathType_AnonymousFunds)) continue;
                    NSInteger index = [derivationPath.allChangeAddresses indexOfObject:addr];
                    if (index != NSNotFound) {
                        [internalIndexes addObject:@(index)];
                        continue;
                    }
                    index = [derivationPath.allReceiveAddresses indexOfObject:addr];
                    if (index != NSNotFound) {
                        [externalIndexes addObject:@(index)];
                        continue;
                    }
                }
                [usedDerivationPaths addObject:@{@"derivationPath":derivationPath,@"externalIndexes":externalIndexes,@"internalIndexes":internalIndexes}];
            }
            
            @autoreleasepool { // @autoreleasepool ensures sensitive data will be dealocated immediately
                
                if (! seed) {
                    if (completion) completion(NO,cancelled);
                } else {
                    NSMutableArray *privkeys = [NSMutableArray array];
                    for (NSDictionary * dictionary in usedDerivationPaths) {
                        DSFundsDerivationPath * derivationPath = dictionary[@"derivationPath"];
                        NSMutableOrderedSet *externalIndexes = dictionary[@"externalIndexes"],
                        *internalIndexes = dictionary[@"internalIndexes"];
                        [privkeys addObjectsFromArray:[derivationPath serializedPrivateKeys:externalIndexes.array internal:NO fromSeed:seed]];
                        [privkeys addObjectsFromArray:[derivationPath serializedPrivateKeys:internalIndexes.array internal:YES fromSeed:seed]];
                    }
                    
                    BOOL signedSuccessfully = [transaction signWithSerializedPrivateKeys:privkeys];
                    if (completion) completion(signedSuccessfully,NO);
                }
                
            }
        }
    });
}

// MARK: = Registration

// records the transaction in the account, or returns false if it isn't associated with the wallet
- (BOOL)registerTransaction:(DSTransaction *)transaction
{
    NSParameterAssert(transaction);
    
    DSDLog(@"[DSAccount] registering transaction %@", transaction);
    UInt256 txHash = transaction.txHash;
    NSValue *hash = uint256_obj(txHash);
    
    if (uint256_is_zero(txHash)) return NO;
    
    if (![self canContainTransaction:transaction]) {
        //this transaction is not meant for this account
        if (transaction.blockHeight == TX_UNCONFIRMED) {
            if ([self checkIsFirstTransaction:transaction]) _firstTransactionHash = txHash; //it's okay if this isn't really the first, as it will be close enough (500 blocks close)
            self.allTx[hash] = transaction;
        }
        return NO;
    }
    
    if (self.allTx[hash] != nil) {
        DSDLog(@"[DSAccount] transaction already registered %@", transaction);
        return YES;
    }
    
    //TODO: handle tx replacement with input sequence numbers (now replacements appear invalid until confirmation)
    DSDLog(@"[DSAccount] received unseen transaction %@", transaction);
    if ([self checkIsFirstTransaction:transaction]) _firstTransactionHash = txHash; //it's okay if this isn't really the first, as it will be close enough (500 blocks close)
    self.allTx[hash] = transaction;
    [self.transactions insertObject:transaction atIndex:0];
    for (NSString * address in transaction.inputAddresses) {
        for (DSFundsDerivationPath * derivationPath in self.fundDerivationPaths) {
            [derivationPath registerTransactionAddress:address]; //only will register if derivation path contains address
        }
    }
    for (NSString * address in transaction.outputAddresses) {
        for (DSFundsDerivationPath * derivationPath in self.fundDerivationPaths) {
            [derivationPath registerTransactionAddress:address]; //only will register if derivation path contains address
        }
    }
    [self updateBalance];
    
    [transaction saveInitial];
    
    return YES;
}

// MARK: = Transaction State

// true if no previous wallet transactions spend any of the given transaction's inputs, and no input tx is invalid
- (BOOL)transactionIsValid:(DSTransaction *)transaction
{
    NSParameterAssert(transaction);
    
    //TODO: XXX attempted double spends should cause conflicted tx to remain unverified until they're confirmed
    //TODO: XXX verify signatures for spends
    if (transaction.blockHeight != TX_UNCONFIRMED) return YES;
    
    if (self.allTx[uint256_obj(transaction.txHash)] != nil) {
        return ([self.invalidTx containsObject:uint256_obj(transaction.txHash)]) ? NO : YES;
    }
    
    uint32_t i = 0;
    
    for (NSValue *hash in transaction.inputHashes) {
        DSTransaction *tx = self.allTx[hash];
        uint32_t n = [transaction.inputIndexes[i++] unsignedIntValue];
        UInt256 h;
        
        [hash getValue:&h];
        if ((tx && ! [self transactionIsValid:tx]) ||
            [self.spentOutputs containsObject:dsutxo_obj(((DSUTXO) { h, n }))]) return NO;
    }
    
    return YES;
}

// true if transaction cannot be immediately spent (i.e. if it or an input tx can be replaced-by-fee)
- (BOOL)transactionIsPending:(DSTransaction *)transaction
{
    NSParameterAssert(transaction);
    
    if (transaction.blockHeight != TX_UNCONFIRMED) return NO; // confirmed transactions are not pending
    if (transaction.size > TX_MAX_SIZE) return YES; // check transaction size is under TX_MAX_SIZE
    
    // check for future lockTime or replace-by-fee: https://github.com/bitcoin/bips/blob/master/bip-0125.mediawiki
    for (NSNumber *sequence in transaction.inputSequences) {
        if (sequence.unsignedIntValue < UINT32_MAX - 1) return YES;
        if (sequence.unsignedIntValue < UINT32_MAX && transaction.lockTime < TX_MAX_LOCK_HEIGHT &&
            transaction.lockTime > self.wallet.chain.bestBlockHeight + 1) return YES;
        if (sequence.unsignedIntValue < UINT32_MAX && transaction.lockTime >= TX_MAX_LOCK_HEIGHT &&
            transaction.lockTime > [NSDate timeIntervalSince1970]) return YES;
    }
    
    for (NSNumber *amount in transaction.outputAmounts) { // check that no outputs are dust
        if (amount.unsignedLongLongValue < TX_MIN_OUTPUT_AMOUNT) return YES;
    }
    
    for (NSValue *txHash in transaction.inputHashes) { // check if any inputs are known to be pending
        if (self.allTx[txHash]) {
            if ([self transactionIsPending:self.allTx[txHash]]) return YES;
        }
    }
    
    return NO;
}

//true if this transaction outputs can not be used in inputs
-(BOOL)transactionOutputsAreLocked:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    
    if ([transaction isKindOfClass:[DSCoinbaseTransaction class]]) { //only allow these to be spent after 100 inputs
        DSCoinbaseTransaction * coinbaseTransaction = (DSCoinbaseTransaction*)transaction;
        if (coinbaseTransaction.height + 100 > self.wallet.chain.lastBlockHeight) return YES;
    }
    return NO;
}

// true if tx is considered 0-conf safe (valid and not pending, timestamp is greater than 0, and no unverified inputs)
- (BOOL)transactionIsVerified:(DSTransaction *)transaction
{
    NSParameterAssert(transaction);
    
    if (transaction.blockHeight != TX_UNCONFIRMED) return YES; // confirmed transactions are always verified
    if (transaction.timestamp == 0) return NO; // a timestamp of 0 indicates transaction is to remain unverified
    if (! [self transactionIsValid:transaction] || [self transactionIsPending:transaction]) return NO;
    
    for (NSValue *txHash in transaction.inputHashes) { // check if any inputs are known to be unverfied
        if (! self.allTx[txHash]) continue;
        if (! [self transactionIsVerified:self.allTx[txHash]]) return NO;
    }
    
    return YES;
}

// MARK: = Amounts

// returns the amount received by the wallet from the transaction (total outputs to change and/or receive addresses)
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction
{
    NSParameterAssert(transaction);
    
    uint64_t amount = 0;
    NSUInteger n = 0;
    
    //TODO: don't include outputs below TX_MIN_OUTPUT_AMOUNT
    for (NSString *address in transaction.outputAddresses) {
        if ([self containsAddress:address]) amount += [transaction.outputAmounts[n] unsignedLongLongValue];
        n++;
    }
    
    return amount;
}

// retuns the amount sent from the wallet by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction
{
    NSParameterAssert(transaction);
    
    uint64_t amount = 0;
    NSUInteger i = 0;
    
    for (NSValue *hash in transaction.inputHashes) {
        DSTransaction *tx = self.allTx[hash];
        uint32_t n = [transaction.inputIndexes[i++] unsignedIntValue];
        
        if (n < tx.outputAddresses.count && [self containsAddress:tx.outputAddresses[n]]) {
            amount += [tx.outputAmounts[n] unsignedLongLongValue];
        }
    }
    
    return amount;
}

// MARK: = Fees

// returns the fee for the given transaction if all its inputs are from wallet transactions, UINT64_MAX otherwise
- (uint64_t)feeForTransaction:(DSTransaction *)transaction
{
    NSParameterAssert(transaction);
    
    uint64_t amount = 0;
    NSUInteger i = 0;
    
    for (NSValue *hash in transaction.inputHashes) {
        DSTransaction *tx = self.allTx[hash];
        uint32_t n = [transaction.inputIndexes[i++] unsignedIntValue];
        
        if (n >= tx.outputAmounts.count) return UINT64_MAX;
        amount += [tx.outputAmounts[n] unsignedLongLongValue];
    }
    
    for (NSNumber *amt in transaction.outputAmounts) {
        amount -= amt.unsignedLongLongValue;
    }
    
    return amount;
}

// MARK: = Outputs

- (uint64_t)maxOutputAmountUsingInstantSend:(BOOL)instantSend
{
    return [self maxOutputAmountWithConfirmationCount:0 usingInstantSend:instantSend returnInputCount:nil];
}

- (uint64_t)maxOutputAmountWithConfirmationCount:(uint64_t)confirmationCount usingInstantSend:(BOOL)instantSend returnInputCount:(uint32_t*)rInputCount;
{
    DSUTXO o;
    DSTransaction *tx;
    uint32_t inputCount = 0;
    uint64_t amount = 0, fee;
    size_t cpfpSize = 0, txSize;
    
    for (NSValue *output in self.utxos) {
        [output getValue:&o];
        tx = self.allTx[uint256_obj(o.hash)];
        if (o.n >= tx.outputAmounts.count) continue;
        if (confirmationCount && (tx.blockHeight >= (self.blockHeight - confirmationCount))) continue;
        inputCount++;
        amount += [tx.outputAmounts[o.n] unsignedLongLongValue];
        
        // size of unconfirmed, non-change inputs for child-pays-for-parent fee
        // don't include parent tx with more than 10 inputs or 10 outputs
        if (tx.blockHeight == TX_UNCONFIRMED && tx.inputHashes.count <= 10 && tx.outputAmounts.count <= 10 &&
            [self amountSentByTransaction:tx] == 0) cpfpSize += tx.size;
    }
    
    
    txSize = 8 + [NSMutableData sizeOfVarInt:inputCount] + TX_INPUT_SIZE*inputCount +
    [NSMutableData sizeOfVarInt:2] + TX_OUTPUT_SIZE*2;
    fee = [self.wallet.chain feeForTxSize:txSize + cpfpSize isInstant:instantSend inputCount:inputCount];
    if (rInputCount) {
        *rInputCount = inputCount;
    }
    return (amount > fee) ? amount - fee : 0;
}

// MARK: = Autolocks

- (BOOL)canUseAutoLocksForAmount:(uint64_t)requiredAmount
{
    const uint64_t confirmationCount = self.wallet.chain.ixPreviousConfirmationsNeeded;
    
    DSUTXO o;
    DSTransaction *tx;
    NSUInteger inputCount = 0;
    uint64_t amount = 0;
    
    for (NSValue *output in self.utxos) {
        [output getValue:&o];
        tx = self.allTx[uint256_obj(o.hash)];
        if (o.n >= tx.outputAmounts.count) continue;
        if (confirmationCount && (tx.blockHeight >= (self.blockHeight - confirmationCount))) continue;
        inputCount++;
        amount += [tx.outputAmounts[o.n] unsignedLongLongValue];
        
        if (amount >= requiredAmount) {
            break;
        }
    }
    
    if (amount < requiredAmount) {
        return NO;
    }
    
    DSChain *chain = self.wallet.chain;
    return [chain canUseAutoLocksWithInputCount:inputCount];
}

// MARK: - Private Key Sweeping

// given a private key, queries dash insight for unspent outputs and calls the completion block with a signed transaction
// that will sweep the balance into the account (doesn't publish the tx)
// this can only be done on main chain for now
- (void)sweepPrivateKey:(NSString *)privKey withFee:(BOOL)fee
             completion:(void (^)(DSTransaction *tx, uint64_t fee, NSError *error))completion
{
    NSParameterAssert(privKey);
    
    if (! completion) return;
    
    if ([privKey isValidDashBIP38Key]) {
        [[DSAuthenticationManager sharedInstance] requestKeyPasswordForSweepCompletion:completion userInfo:@{AUTH_SWEEP_KEY:privKey,AUTH_SWEEP_FEE:@(fee)} completion:^(void (^sweepCompletion)(DSTransaction *tx, uint64_t fee, NSError *error), NSDictionary *userInfo, NSString *password) {
            dispatch_async(dispatch_get_main_queue(), ^{
                DSECDSAKey *key = [DSECDSAKey keyWithBIP38Key:userInfo[AUTH_SWEEP_KEY] andPassphrase:password onChain:self.wallet.chain];
                
                if (! key) {
                    [[DSAuthenticationManager sharedInstance] badKeyPasswordForSweepCompletion:^{
                        [self sweepPrivateKey:privKey withFee:fee completion:completion];
                    } cancel:^{
                        if (sweepCompletion) sweepCompletion(nil, 0, nil);
                    }];
                }
                else {
                    [self sweepPrivateKey:[key privateKeyStringForChain:self.wallet.chain] withFee:[userInfo[AUTH_SWEEP_FEE] boolValue] completion:sweepCompletion];
                }
            });
        } cancel:^{
            
        }];
        
        
        
        return;
    }
    
    DSECDSAKey *key = [DSECDSAKey keyWithPrivateKey:privKey onChain:self.wallet.chain];
    NSString * address = [key addressForChain:self.wallet.chain];
    if (! address) {
        completion(nil, 0, [NSError errorWithDomain:@"DashSync" code:187 userInfo:@{NSLocalizedDescriptionKey:
                                                                                        DSLocalizedString(@"not a valid private key", nil)}]);
        return;
    }
    if ([self.wallet containsAddress:address]) {
        completion(nil, 0, [NSError errorWithDomain:@"DashSync" code:187 userInfo:@{NSLocalizedDescriptionKey:
                                                                                        DSLocalizedString(@"this private key is already in your wallet", nil)}]);
        return;
    }
    
    [[DSInsightManager sharedInstance] utxosForAddresses:@[address] onChain:self.wallet.chain
                                              completion:^(NSArray *utxos, NSArray *amounts, NSArray *scripts, NSError *error) {
                                                  DSTransaction *tx = [[DSTransaction alloc] initOnChain:self.wallet.chain];
                                                  uint64_t balance = 0, feeAmount = 0;
                                                  NSUInteger i = 0;
                                                  
                                                  if (error) {
                                                      completion(nil, 0, error);
                                                      return;
                                                  }
                                                  
                                                  //TODO: make sure not to create a transaction larger than TX_MAX_SIZE
                                                  for (NSValue *output in utxos) {
                                                      DSUTXO o;
                                                      
                                                      [output getValue:&o];
                                                      [tx addInputHash:o.hash index:o.n script:scripts[i]];
                                                      balance += [amounts[i++] unsignedLongLongValue];
                                                  }
                                                  
                                                  if (balance == 0) {
                                                      completion(nil, 0, [NSError errorWithDomain:@"DashSync" code:417 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                                                      DSLocalizedString(@"this private key is empty", nil)}]);
                                                      return;
                                                  }
                                                  
                                                  // we will be adding a wallet output (34 bytes), also non-compact pubkey sigs are larger by 32bytes each
                                                  if (fee) feeAmount = [self.wallet.chain feeForTxSize:tx.size + 34 + (key.publicKeyData.length - 33)*tx.inputHashes.count isInstant:false inputCount:0]; //input count doesn't matter for non instant transactions
                                                  
                                                  if (feeAmount + self.wallet.chain.minOutputAmount > balance) {
                                                      completion(nil, 0, [NSError errorWithDomain:@"DashSync" code:417 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                                                      DSLocalizedString(@"transaction fees would cost more than the funds available on this "
                                                                                                                                                        "private key (due to tiny \"dust\" deposits)",nil)}]);
                                                      return;
                                                  }
                                                  
                                                  [tx addOutputAddress:self.receiveAddress amount:balance - feeAmount];
                                                  
                                                  if (! [tx signWithSerializedPrivateKeys:@[privKey]]) {
                                                      completion(nil, 0, [NSError errorWithDomain:@"DashSync" code:401 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                                                      DSLocalizedString(@"error signing transaction", nil)}]);
                                                      return;
                                                  }
                                                  
                                                  completion(tx, feeAmount, nil);
                                              }];
}

@end
