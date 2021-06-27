//
//  DSTransaction.m
//  DashSync
//
//  Created by Aaron Voisine for BreadWallet on 5/16/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
//  Updated by Quantum Explorer on 05/11/18.
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

#import "DSAccount.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSCreditFundingTransaction.h"
#import "DSECDSAKey.h"
#import "DSIdentitiesManager.h"
#import "DSInstantSendTransactionLock.h"
#import "DSTransaction+Protected.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTransactionFactory.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSWallet.h"
#import "NSData+Bitcoin.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"
#import "NSString+Dash.h"

@interface DSTransaction ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, assign) BOOL confirmed;
@property (nonatomic, strong) NSSet<DSBlockchainIdentity *> *sourceBlockchainIdentities;
@property (nonatomic, strong) NSSet<DSBlockchainIdentity *> *destinationBlockchainIdentities;

@end

@implementation DSTransaction

// MARK: - Initiation

+ (instancetype)transactionWithMessage:(NSData *)message onChain:(DSChain *)chain {
    return [[self alloc] initWithMessage:message onChain:chain];
}

+ (instancetype)devnetGenesisCoinbaseWithIdentifier:(NSString *)identifier forChain:(DSChain *)chain {
    DSTransaction *transaction = [[self alloc] initOnChain:chain];
    NSMutableData *coinbaseData = [NSMutableData data];
    [coinbaseData appendDevnetGenesisCoinbaseMessage:identifier];
    [transaction addInputHash:UINT256_ZERO index:UINT32_MAX script:nil signature:coinbaseData sequence:UINT32_MAX];
    NSMutableData *outputScript = [NSMutableData data];
    [outputScript appendUInt8:OP_RETURN];
    [transaction addOutputScript:outputScript amount:chain.baseReward];
    //    DSLogPrivate(@"we are hashing %@",transaction.toData);
    transaction.txHash = transaction.toData.SHA256_2;
    //    DSLogPrivate(@"data is %@",[NSData dataWithUInt256:transaction.txHash]);
    return transaction;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    NSAssert(FALSE, @"this method is not supported");
    return self;
}

- (instancetype)initOnChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;

    _version = TX_VERSION;
    self.hashes = [NSMutableArray array];
    self.indexes = [NSMutableArray array];
    self.inScripts = [NSMutableArray array];
    self.amounts = [NSMutableArray array];
    self.addresses = [NSMutableArray array];
    self.outScripts = [NSMutableArray array];
    self.signatures = [NSMutableArray array];
    self.sequences = [NSMutableArray array];
    self.chain = chain;
    self.persistenceStatus = DSTransactionPersistenceStatus_NotSaved;
    self.hasUnverifiedInstantSendLock = NO;
    _lockTime = TX_LOCKTIME;
    self.blockHeight = TX_UNCONFIRMED;
    self.sourceBlockchainIdentities = [NSSet set];
    self.destinationBlockchainIdentities = [NSSet set];
    return self;
}

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [self initOnChain:chain])) return nil;

    NSString *address = nil;
    NSNumber *l = 0;
    uint32_t off = 0;
    uint64_t count = 0;
    NSData *d = nil;

    @autoreleasepool {
        self.chain = chain;
        _version = [message UInt16AtOffset:off]; // tx version
        off += sizeof(uint16_t);
        _type = [message UInt16AtOffset:off]; // tx type
        off += sizeof(uint16_t);
        count = [message varIntAtOffset:off length:&l]; // input count
        if (count == 0 && [self transactionTypeRequiresInputs]) {
            return nil; // at least one input is required
        }
        off += l.unsignedIntegerValue;

        for (NSUInteger i = 0; i < count; i++) { // inputs
            [self.hashes addObject:uint256_obj([message UInt256AtOffset:off])];
            off += sizeof(UInt256);
            [self.indexes addObject:@([message UInt32AtOffset:off])]; // input index
            off += sizeof(uint32_t);
            [self.inScripts addObject:[NSNull null]]; // placeholder for input script (comes from input transaction)
            d = [message dataAtOffset:off length:&l];
            [self.signatures addObject:(d.length > 0) ? d : [NSNull null]]; // input signature
            off += l.unsignedIntegerValue;
            [self.sequences addObject:@([message UInt32AtOffset:off])]; // input sequence number (for replacement tx)
            off += sizeof(uint32_t);
        }

        count = (NSUInteger)[message varIntAtOffset:off length:&l]; // output count
        off += l.unsignedIntegerValue;

        for (NSUInteger i = 0; i < count; i++) {                      // outputs
            [self.amounts addObject:@([message UInt64AtOffset:off])]; // output amount
            off += sizeof(uint64_t);
            d = [message dataAtOffset:off length:&l];
            [self.outScripts addObject:(d) ? d : [NSNull null]]; // output script
            off += l.unsignedIntegerValue;
            address = [NSString addressWithScriptPubKey:d onChain:self.chain]; // address from output script if applicable
            [self.addresses addObject:(address) ? address : [NSNull null]];
        }

        _lockTime = [message UInt32AtOffset:off]; // tx locktime
        off += 4;
        _payloadOffset = off;
        if ([self type] == DSTransactionType_Classic) {
            _txHash = self.data.SHA256_2;
        }
    }

    if ([self type] != DSTransactionType_Classic) return self; //only classic transactions are shapeshifted

    NSString *outboundShapeshiftAddress = [self shapeshiftOutboundAddress];
    if (!outboundShapeshiftAddress) return self;
    self.associatedShapeshift = [DSShapeshiftEntity shapeshiftHavingWithdrawalAddress:outboundShapeshiftAddress inContext:[NSManagedObjectContext chainContext]];
    if (self.associatedShapeshift && [self.associatedShapeshift.shapeshiftStatus integerValue] == eShapeshiftAddressStatus_Unused) {
        self.associatedShapeshift.shapeshiftStatus = @(eShapeshiftAddressStatus_NoDeposits);
    }
    if (!self.associatedShapeshift) {
        NSString *possibleOutboundShapeshiftAddress = [self shapeshiftOutboundAddressForceScript];
        self.associatedShapeshift = [DSShapeshiftEntity shapeshiftHavingWithdrawalAddress:possibleOutboundShapeshiftAddress inContext:[NSManagedObjectContext chainContext]];
        if (self.associatedShapeshift && [self.associatedShapeshift.shapeshiftStatus integerValue] == eShapeshiftAddressStatus_Unused) {
            self.associatedShapeshift.shapeshiftStatus = @(eShapeshiftAddressStatus_NoDeposits);
        }
    }

    if (self.associatedShapeshift || ![self.outputAddresses count]) return self;

    NSString *mainOutputAddress = nil;
    NSMutableArray *allAddresses = [NSMutableArray array];
    for (DSAddressEntity *e in [DSAddressEntity allObjectsInContext:chain.chainManagedObjectContext]) {
        [allAddresses addObject:e.address];
    }
    for (NSString *outputAddress in self.outputAddresses) {
        if (outputAddress && [allAddresses containsObject:address]) continue;
        if ([outputAddress isEqual:[NSNull null]]) continue;
        mainOutputAddress = outputAddress;
    }
    //NSAssert(mainOutputAddress, @"there should always be an output address");
    if (mainOutputAddress) {
        self.associatedShapeshift = [DSShapeshiftEntity registerShapeshiftWithInputAddress:mainOutputAddress andWithdrawalAddress:outboundShapeshiftAddress withStatus:eShapeshiftAddressStatus_NoDeposits inContext:[NSManagedObjectContext chainContext]];
    }

    return self;
}

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray *)inputSequences
                    outputAddresses:(NSArray *)addresses
                      outputAmounts:(NSArray *)amounts
                            onChain:(DSChain *)chain {
    if ([self transactionTypeRequiresInputs] && hashes.count == 0) return nil;
    if (hashes.count != indexes.count) return nil;
    if (scripts.count > 0 && hashes.count != scripts.count) return nil;
    if (addresses.count != amounts.count) return nil;

    if (!(self = [super init])) return nil;

    self.persistenceStatus = DSTransactionPersistenceStatus_NotSaved;
    self.chain = chain;
    _version = chain.transactionVersion;
    self.hashes = [NSMutableArray arrayWithArray:hashes];
    self.sequences = [NSMutableArray arrayWithArray:inputSequences];
    self.indexes = [NSMutableArray arrayWithArray:indexes];

    if (scripts.count > 0) {
        self.inScripts = [NSMutableArray arrayWithArray:scripts];
    } else
        self.inScripts = [NSMutableArray arrayWithCapacity:hashes.count];

    while (self.inScripts.count < hashes.count) {
        [self.inScripts addObject:[NSNull null]];
    }

    self.amounts = [NSMutableArray arrayWithArray:amounts];
    self.addresses = [NSMutableArray arrayWithArray:addresses];
    self.outScripts = [NSMutableArray arrayWithCapacity:addresses.count];

    for (int i = 0; i < addresses.count; i++) {
        [self.outScripts addObject:[NSMutableData data]];
        if ([self.addresses[i] isEqual:[NSNull null]]) {
            [self.outScripts.lastObject appendUInt8:OP_RETURN];
        } else {
            [self.outScripts.lastObject appendScriptPubKeyForAddress:self.addresses[i] forChain:chain];
        }
    }

    self.signatures = [NSMutableArray arrayWithCapacity:hashes.count];

    for (int i = 0; i < hashes.count; i++) {
        [self.signatures addObject:[NSNull null]];
    }

    _lockTime = TX_LOCKTIME;
    self.blockHeight = TX_UNCONFIRMED;
    return self;
}

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts
                    outputAddresses:(NSArray *)addresses
                      outputAmounts:(NSArray *)amounts
                            onChain:(DSChain *)chain {
    NSMutableArray *sequences = [NSMutableArray arrayWithCapacity:hashes.count];
    for (int i = 0; i < hashes.count; i++) {
        [sequences addObject:@(TXIN_SEQUENCE)];
    }
    return [self initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:sequences outputAddresses:addresses outputAmounts:amounts onChain:chain];
}

// MARK: - Object

- (BOOL)isEqual:(id)object {
    return self == object || ([object isKindOfClass:[DSTransaction class]] && uint256_eq(_txHash, [((DSTransaction *)object) txHash]));
}

// MARK: - Attributes

- (NSData *)payloadData {
    return [NSData data];
}

- (NSData *)payloadDataForHash {
    return [NSData data];
}

- (DSAccount *)firstAccount {
    return [self.chain firstAccountThatCanContainTransaction:self];
}

- (NSArray<DSAccount *> *)accounts {
    return [self.chain accountsThatCanContainTransaction:self];
}

- (NSArray *)inputHashes {
    return self.hashes;
}

- (NSArray *)inputIndexes {
    return self.indexes;
}

- (NSArray *)inputScripts {
    return self.inScripts;
}

- (NSArray *)inputAddresses {
    NSMutableArray *addresses = [NSMutableArray arrayWithCapacity:self.inScripts.count];
    NSInteger i = 0;

    //    for (NSData * data in self.signatures) {
    //        NSString * addr = [NSString addressWithScriptSig:data onChain:self.chain];
    //                           DSLogPrivate(@"%@",addr);
    //    }

    for (NSData *script in self.inScripts) {
        NSString *addr = [NSString addressWithScriptPubKey:script onChain:self.chain];
        if (!addr) addr = [NSString addressWithScriptSig:self.signatures[i] onChain:self.chain];
        [addresses addObject:(addr) ? addr : [NSNull null]];
        i++;
    }

    return addresses;
}


- (NSArray *)inputSignatures {
    return self.signatures;
}

- (NSArray *)inputSequences {
    return self.sequences;
}

- (NSArray *)outputAmounts {
    return self.amounts;
}

- (NSArray *)outputAddresses {
    return self.addresses;
}

- (NSArray *)outputScripts {
    return self.outScripts;
}

- (NSString *)description {
    NSString *txid = [NSString hexWithData:[NSData dataWithBytes:self.txHash.u8 length:sizeof(UInt256)].reverse];
    return [NSString stringWithFormat:@"%@(id=%@-block=%@) + (%@)", [self class], txid, (self.blockHeight == TX_UNCONFIRMED) ? @"Not mined" : @(self.blockHeight), [super description]];
}

- (NSString *)longDescription {
    NSString *txid = [NSString hexWithData:[NSData dataWithBytes:self.txHash.u8 length:sizeof(UInt256)].reverse];
    return [NSString stringWithFormat:
                         @"%@(id=%@, inputHashes=%@, inputIndexes=%@, inputScripts=%@, inputSignatures=%@, inputSequences=%@, "
                          "outputAmounts=%@, outputAddresses=%@, outputScripts=%@)",
                     [[self class] description], txid,
                     self.inputHashes, self.inputIndexes, self.inputScripts, self.inputSignatures, self.inputSequences,
                     self.outputAmounts, self.outputAddresses, self.outputScripts];
}

// retuns the amount sent from the wallet by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSent {
    uint64_t amount = 0;
    NSUInteger i = 0;

    for (NSValue *hashValue in self.inputHashes) {
        UInt256 hash;
        [hashValue getValue:&hash];
        DSTransaction *tx = [self.chain transactionForHash:hash];
        DSAccount *account = [self.chain firstAccountThatCanContainTransaction:tx];
        uint32_t n = [self.inputIndexes[i++] unsignedIntValue];

        if (n < tx.outputAddresses.count && [account containsAddress:tx.outputAddresses[n]]) {
            amount += [tx.outputAmounts[n] unsignedLongLongValue];
        }
    }

    return amount;
}

// size in bytes if signed, or estimated size assuming compact pubkey sigs
- (size_t)size {
    if (uint256_is_not_zero(_txHash)) return self.data.length;
    return 8 + [NSMutableData sizeOfVarInt:self.hashes.count] + [NSMutableData sizeOfVarInt:self.addresses.count] +
           TX_INPUT_SIZE * self.hashes.count + TX_OUTPUT_SIZE * self.addresses.count;
}

- (uint64_t)standardFee {
    return self.size * TX_FEE_PER_B;
}

- (uint64_t)standardInstantFee {
    return TX_FEE_PER_INPUT * [self.inputHashes count];
}

// checks if all signatures exist, but does not verify them
- (BOOL)isSigned {
    return (self.signatures.count > 0 && self.signatures.count == self.hashes.count &&
               ![self.signatures containsObject:[NSNull null]]) ?
               YES :
               NO;
}

- (BOOL)isCoinbaseClassicTransaction {
    if (([self.hashes count] == 1)) {
        UInt256 firstInputHash;
        [self.hashes[0] getValue:&firstInputHash];
        if (uint256_is_zero(firstInputHash) && [[self.inputIndexes objectAtIndex:0] integerValue] == UINT32_MAX) return TRUE;
    }
    return NO;
}

- (BOOL)isCreditFundingTransaction {
    for (NSData *script in self.outputScripts) {
        if ([script UInt8AtOffset:0] == OP_RETURN && script.length == 22) {
            return YES;
        }
    }
    return NO;
}

- (NSUInteger)hash {
    if (uint256_is_zero(_txHash)) return super.hash;
    return *(const NSUInteger *)&_txHash;
}

// MARK: - Wire Serialization

- (NSData *)toData {
    return [self toDataWithSubscriptIndex:NSNotFound];
}

// Returns the binary transaction data that needs to be hashed and signed with the private key for the tx input at
// subscriptIndex. A subscriptIndex of NSNotFound will return the entire signed transaction.
- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex {
    UInt256 hash = UINT256_ZERO;
    NSMutableData *d = [NSMutableData dataWithCapacity:10 + TX_INPUT_SIZE * self.hashes.count +
                                                       TX_OUTPUT_SIZE * self.addresses.count];

    [d appendUInt16:self.version];
    [d appendUInt16:self.type];
    [d appendVarInt:self.hashes.count];


    for (NSUInteger i = 0; i < self.hashes.count; i++) {
        [self.hashes[i] getValue:&hash];
        [d appendBytes:&hash length:sizeof(hash)];
        [d appendUInt32:[self.indexes[i] unsignedIntValue]];

        if (subscriptIndex == NSNotFound && self.signatures[i] != [NSNull null]) {
            [d appendVarInt:[self.signatures[i] length]];
            [d appendData:self.signatures[i]];
        } else if (subscriptIndex == i && self.inScripts[i] != [NSNull null]) {
            //TODO: to fully match the reference implementation, OP_CODESEPARATOR related checksig logic should go here
            [d appendVarInt:[self.inScripts[i] length]];
            [d appendData:self.inScripts[i]];
        } else
            [d appendVarInt:0];

        [d appendUInt32:[self.sequences[i] unsignedIntValue]];
    }

    [d appendVarInt:self.amounts.count];

    for (NSUInteger i = 0; i < self.amounts.count; i++) {
        [d appendUInt64:[self.amounts[i] unsignedLongLongValue]];
        [d appendVarInt:[self.outScripts[i] length]];
        [d appendData:self.outScripts[i]];
    }

    [d appendUInt32:self.lockTime];
    if (([self isMemberOfClass:[DSTransaction class]] || [self isMemberOfClass:[DSCreditFundingTransaction class]]) && subscriptIndex != NSNotFound) [d appendUInt32:SIGHASH_ALL];
    return d;
}

// MARK: - Construction

- (void)addInputHash:(UInt256)hash index:(NSUInteger)index script:(NSData *)script {
    [self addInputHash:hash index:index script:script signature:nil sequence:TXIN_SEQUENCE];
}

- (void)addInputHash:(UInt256)hash index:(NSUInteger)index script:(NSData *)script signature:(NSData *)signature
            sequence:(uint32_t)sequence {
    [self.hashes addObject:uint256_obj(hash)];
    [self.indexes addObject:@(index)];
    [self.inScripts addObject:(script) ? script : [NSNull null]];
    [self.signatures addObject:(signature) ? signature : [NSNull null]];
    [self.sequences addObject:@(sequence)];
}

- (void)addOutputAddress:(NSString *)address amount:(uint64_t)amount {
    [self.amounts addObject:@(amount)];
    [self.addresses addObject:address];
    [self.outScripts addObject:[NSMutableData data]];
    [self.outScripts.lastObject appendScriptPubKeyForAddress:address forChain:self.chain];
}

- (void)addOutputCreditAddress:(NSString *)address amount:(uint64_t)amount {
    [self.amounts addObject:@(amount)];
    [self.addresses addObject:address];
    [self.outScripts addObject:[NSMutableData data]];
    [self.outScripts.lastObject appendScriptPubKeyForAddress:address forChain:self.chain];
}

- (void)addOutputShapeshiftAddress:(NSString *)address {
    [self.amounts addObject:@(0)];
    [self.addresses addObject:[NSNull null]];
    [self.outScripts addObject:[NSMutableData data]];
    [self.outScripts.lastObject appendShapeshiftMemoForAddress:address];
}

- (void)addOutputBurnAmount:(uint64_t)amount {
    [self.amounts addObject:@(amount)];
    [self.addresses addObject:[NSNull null]];
    [self.outScripts addObject:[NSMutableData data]];
    [self.outScripts.lastObject appendUInt8:OP_RETURN];
}

- (void)addOutputScript:(NSData *)script amount:(uint64_t)amount {
    NSString *address = [NSString addressWithScriptPubKey:script onChain:self.chain];
    [self addOutputScript:script withAddress:address amount:amount];
}


- (void)addOutputScript:(NSData *_Nonnull)script withAddress:(NSString *)address amount:(uint64_t)amount {
    NSParameterAssert(script);
    if (!address && script) {
        address = [NSString addressWithScriptPubKey:script onChain:self.chain];
    }
    [self.amounts addObject:@(amount)];
    [self.outScripts addObject:script];
    [self.addresses addObject:(address) ? address : [NSNull null]];
}

- (void)setInputAddress:(NSString *)address atIndex:(NSUInteger)index {
    NSMutableData *d = [NSMutableData data];

    [d appendScriptPubKeyForAddress:address forChain:self.chain];
    self.inScripts[index] = d;
}

- (void)shuffleOutputOrder {
    for (NSUInteger i = 0; i + 1 < self.amounts.count; i++) { // fischer-yates shuffle
        NSUInteger j = i + arc4random_uniform((uint32_t)(self.amounts.count - i));

        if (j == i) continue;
        [self.amounts exchangeObjectAtIndex:i withObjectAtIndex:j];
        [self.outScripts exchangeObjectAtIndex:i withObjectAtIndex:j];
        [self.addresses exchangeObjectAtIndex:i withObjectAtIndex:j];
    }
}

// MARK: - Signing

- (BOOL)signWithSerializedPrivateKeys:(NSArray *)privateKeys {
    NSMutableArray *keys = [NSMutableArray arrayWithCapacity:privateKeys.count];

    for (NSString *pk in privateKeys) {
        DSECDSAKey *key = [DSECDSAKey keyWithPrivateKey:pk onChain:self.chain];

        if (!key) continue;
        [keys addObject:key];
    }

    return [self signWithPrivateKeys:keys];
}

- (BOOL)signWithPrivateKeys:(NSArray *)keys {
    NSMutableArray *addresses = [NSMutableArray arrayWithCapacity:keys.count];

    for (DSECDSAKey *key in keys) {
        [addresses addObject:[key addressForChain:self.chain]];
    }

    return [self signWithPrivateKeys:keys forAddresses:addresses];
}

- (BOOL)signWithPreorderedPrivateKeys:(NSArray *)keys {
    for (NSUInteger i = 0; i < self.hashes.count; i++) {
        NSMutableData *sig = [NSMutableData data];
        NSData *data = [self toDataWithSubscriptIndex:i];
        UInt256 hash = data.SHA256_2;
        NSMutableData *s = [NSMutableData dataWithData:[keys[i] sign:hash]];
        NSArray *elem = [self.inScripts[i] scriptElements];

        [s appendUInt8:SIGHASH_ALL];
        [sig appendScriptPushData:s];

        if (elem.count >= 2 && [elem[elem.count - 2] intValue] == OP_EQUALVERIFY) { // pay-to-pubkey-hash scriptSig
            [sig appendScriptPushData:[keys[i] publicKeyData]];
        }

        self.signatures[i] = sig;
    }

    if (!self.isSigned) return NO;
    _txHash = self.data.SHA256_2;
    return YES;
}

- (BOOL)signWithPrivateKeys:(NSArray *)keys forAddresses:(NSArray *)addresses {
    for (NSUInteger i = 0; i < self.hashes.count; i++) {
        NSString *addr = [NSString addressWithScriptPubKey:self.inScripts[i] onChain:self.chain];
        NSUInteger keyIdx = (addr) ? [addresses indexOfObject:addr] : NSNotFound;

        if (keyIdx == NSNotFound) continue;

        NSMutableData *sig = [NSMutableData data];
        NSData *data = [self toDataWithSubscriptIndex:i];
        UInt256 hash = data.SHA256_2;
        NSMutableData *s = [NSMutableData dataWithData:[keys[keyIdx] sign:hash]];
        NSArray *elem = [self.inScripts[i] scriptElements];

        [s appendUInt8:SIGHASH_ALL];
        [sig appendScriptPushData:s];

        if (elem.count >= 2 && [elem[elem.count - 2] intValue] == OP_EQUALVERIFY) { // pay-to-pubkey-hash scriptSig
            [sig appendScriptPushData:[keys[keyIdx] publicKeyData]];
        }

        self.signatures[i] = sig;
    }

    if (!self.isSigned) return NO;
    _txHash = self.data.SHA256_2;
    return YES;
}

// MARK: - Priority (Deprecated)

// priority = sum(input_amount_in_satoshis*input_age_in_blocks)/size_in_bytes
- (uint64_t)priorityForAmounts:(NSArray *)amounts withAges:(NSArray *)ages {
    uint64_t p = 0;

    if (amounts.count != self.hashes.count || ages.count != self.hashes.count || [ages containsObject:@(0)]) return 0;

    for (NSUInteger i = 0; i < amounts.count; i++) {
        p += [amounts[i] unsignedLongLongValue] * [ages[i] unsignedLongLongValue];
    }

    return p / self.size;
}

// MARK: - Fees

// returns the fee for the given transaction if all its inputs are from wallet transactions, UINT64_MAX otherwise
- (uint64_t)feeUsed {
    //TODO: This most likely does not work when sending from multiple accounts
    return [self.firstAccount feeForTransaction:self];
}

- (uint64_t)roundedFeeCostPerByte {
    uint64_t feeUsed = [self feeUsed];
    if (feeUsed == UINT64_MAX) return UINT64_MAX;
    return lroundf(((float)feeUsed) / self.size);
}

// MARK: - Info

- (BOOL)hasNonDustOutputInWallet:(DSWallet *)wallet {
    for (int i = 0; i < self.outputAddresses.count; i++) {
        NSString *outputAddress = self.outputAddresses[i];
        uint64_t outputAmount = [self.outputAmounts[i] longLongValue];
        if (outputAmount > TX_MIN_OUTPUT_AMOUNT && [wallet containsAddress:outputAddress]) {
            return TRUE;
        }
    }
    return FALSE;
}

// MARK: - Instant Send

// v14

- (void)setInstantSendReceivedWithInstantSendLock:(DSInstantSendTransactionLock *)instantSendLock {
    self.instantSendReceived = instantSendLock.signatureVerified;
    self.hasUnverifiedInstantSendLock = (instantSendLock && !instantSendLock.signatureVerified);
    if (self.hasUnverifiedInstantSendLock) {
        self.instantSendLockAwaitingProcessing = instantSendLock;
    } else {
        self.instantSendLockAwaitingProcessing = nil;
    }
    if (!instantSendLock.saved) {
        [instantSendLock saveInitial];
    }
}

- (uint32_t)confirmations {
    if (self.blockHeight == TX_UNCONFIRMED) return 0;
    const uint32_t lastHeight = self.chain.lastTerminalBlockHeight;
    return lastHeight - self.blockHeight;
}

- (BOOL)confirmed {
    if (_confirmed) return YES; //because it can't be unconfirmed
    if (self.blockHeight == TX_UNCONFIRMED) return NO;
    const uint32_t lastHeight = self.chain.lastSyncBlockHeight;
    if (self.blockHeight > self.chain.lastSyncBlockHeight) {
        //this should only be possible if and only if we have migrated and kept old transactions.
        return YES;
    }
    if (lastHeight - self.blockHeight > 6) return YES;
    _confirmed = [self.chain blockHeightChainLocked:self.blockHeight];
    return _confirmed;
}

// MARK: - Blockchain Identities

- (void)loadBlockchainIdentitiesFromDerivationPaths:(NSArray<DSDerivationPath *> *)derivationPaths {
    NSMutableSet *destinationBlockchainIdentities = [NSMutableSet set];
    NSMutableSet *sourceBlockchainIdentities = [NSMutableSet set];
    for (NSString *address in self.outputAddresses) {
        for (DSFundsDerivationPath *derivationPath in derivationPaths) {
            if ([derivationPath isKindOfClass:[DSIncomingFundsDerivationPath class]] && [derivationPath containsAddress:address]) {
                DSIncomingFundsDerivationPath *incomingFundsDerivationPath = ((DSIncomingFundsDerivationPath *)derivationPath);
                DSBlockchainIdentity *destinationBlockchainIdentity = [incomingFundsDerivationPath contactDestinationBlockchainIdentity];
                DSBlockchainIdentity *sourceBlockchainIdentity = [incomingFundsDerivationPath contactSourceBlockchainIdentity];
                if (sourceBlockchainIdentity) {
                    [destinationBlockchainIdentities addObject:sourceBlockchainIdentity]; //these need to be inverted since the derivation path is incoming
                }
                if (destinationBlockchainIdentity) {
                    [sourceBlockchainIdentities addObject:destinationBlockchainIdentity]; //these need to be inverted since the derivation path is incoming
                }
            }
        }
    }
    self.sourceBlockchainIdentities = [self.sourceBlockchainIdentities setByAddingObjectsFromSet:[sourceBlockchainIdentities copy]];
    self.destinationBlockchainIdentities = [self.destinationBlockchainIdentities setByAddingObjectsFromSet:[destinationBlockchainIdentities copy]];
}

// MARK: - Polymorphic data

- (Class)entityClass {
    return [DSTransactionEntity class];
}

- (BOOL)transactionTypeRequiresInputs {
    return YES;
}

- (void)hasSetInputsAndOutputs {
    //nothing to do here
}

// MARK: - Extra shapeshift methods

- (NSString *)shapeshiftOutboundAddress {
    for (NSData *script in self.outputScripts) {
        NSString *outboundAddress = [DSTransaction shapeshiftOutboundAddressForScript:script onChain:self.chain];
        if (outboundAddress) return outboundAddress;
    }
    return nil;
}

- (NSString *)shapeshiftOutboundAddressForceScript {
    for (NSData *script in self.outputScripts) {
        NSString *outboundAddress = [DSTransaction shapeshiftOutboundAddressForceScript:script];
        if (outboundAddress) return outboundAddress;
    }
    return nil;
}

+ (NSString *)shapeshiftOutboundAddressForceScript:(NSData *)script {
    if ([script UInt8AtOffset:0] == OP_RETURN) {
        UInt8 length = [script UInt8AtOffset:1];
        if ([script UInt8AtOffset:2] == OP_SHAPESHIFT) {
            NSMutableData *data = [NSMutableData data];
            uint8_t v = BITCOIN_SCRIPT_ADDRESS;
            [data appendBytes:&v length:1];
            NSData *addressData = [script subdataWithRange:NSMakeRange(3, length - 1)];

            [data appendData:addressData];
            return [NSString base58checkWithData:data];
        }
    }
    return nil;
}

+ (NSString *)shapeshiftOutboundAddressForScript:(NSData *)script onChain:(DSChain *)chain {
    if (chain.isMainnet) {
        if ([script UInt8AtOffset:0] != OP_RETURN) return nil;
        UInt8 length = [script UInt8AtOffset:1];
        if ([script UInt8AtOffset:2] == OP_SHAPESHIFT) {
            NSMutableData *data = [NSMutableData data];
            uint8_t v = BITCOIN_PUBKEY_ADDRESS;
            [data appendBytes:&v length:1];
            NSData *addressData = [script subdataWithRange:NSMakeRange(3, length - 1)];

            [data appendData:addressData];
            return [NSString base58checkWithData:data];
        } else if ([script UInt8AtOffset:2] == OP_SHAPESHIFT_SCRIPT) {
            NSMutableData *data = [NSMutableData data];
            uint8_t v = BITCOIN_SCRIPT_ADDRESS;
            [data appendBytes:&v length:1];
            NSData *addressData = [script subdataWithRange:NSMakeRange(3, length - 1)];

            [data appendData:addressData];
            return [NSString base58checkWithData:data];
        }
    }
    return nil;
}

// MARK: - Persistence

- (DSTransactionEntity *)transactionEntityInContext:(NSManagedObjectContext *)context {
    __block DSTransactionEntity *transactionEntity = nil;
    [context performBlockAndWait:^{ // add the transaction to core data
        transactionEntity = [DSTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@", uint256_data(self.txHash)];
    }];
    return transactionEntity;
}

- (DSTransactionEntity *)save {
    NSManagedObjectContext *context = self.chain.chainManagedObjectContext;
    return [self saveInContext:context];
}

- (DSTransactionEntity *)saveInContext:(NSManagedObjectContext *)context {
    __block DSTransactionEntity *transactionEntity = nil;
    [context performBlockAndWait:^{ // add the transaction to core data
        Class transactionEntityClass = [self entityClass];
        if ([DSTransactionEntity countObjectsInContext:context matching:@"transactionHash.txHash == %@", uint256_data(self.txHash)] == 0) {
            transactionEntity = [transactionEntityClass managedObjectInBlockedContext:context];
            [transactionEntity setAttributesFromTransaction:self];
            [context ds_save];
        } else {
            transactionEntity = [DSTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@", uint256_data(self.txHash)];
            [transactionEntity setAttributesFromTransaction:self];
            [context ds_save];
        }
    }];
    return transactionEntity;
}

- (BOOL)setInitialPersistentAttributesInContext:(NSManagedObjectContext *)context {
    Class transactionEntityClass = [self entityClass];
    if ([DSTransactionEntity countObjectsInContext:context matching:@"transactionHash.txHash == %@", uint256_data(self.txHash)] == 0) {
        DSTransactionEntity *transactionEntity = [transactionEntityClass managedObjectInBlockedContext:context];
        [transactionEntity setAttributesFromTransaction:self];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)saveInitial {
    NSManagedObjectContext *context = self.chain.chainManagedObjectContext;
    return [self saveInitialInContext:context];
}

- (BOOL)saveInitialInContext:(NSManagedObjectContext *)context {
    if (self.persistenceStatus != DSTransactionPersistenceStatus_NotSaved) return NO;
    self.persistenceStatus = DSTransactionPersistenceStatus_Saving;
    [context performBlock:^{ // add the transaction to core data
        if ([self setInitialPersistentAttributesInContext:context]) {
            if (![context ds_save]) {
                self.persistenceStatus = DSTransactionPersistenceStatus_Saved;
            } else {
                DSLog(@"There was an error saving the transaction");
                self.persistenceStatus = DSTransactionPersistenceStatus_NotSaved;
            }
        } else {
            //it already existed
            self.persistenceStatus = DSTransactionPersistenceStatus_Saved;
        }
    }];
    return YES;
}

@end
