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
#import "DSMasternodeManager.h"
#import "DSTransaction+Protected.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTransactionFactory.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSTransactionInput.h"
#import "DSTransactionOutput.h"
#import "DSWallet.h"
#import "NSData+DSHash.h"
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
@property (nonatomic, strong) NSMutableArray<DSTransactionInput *> *mInputs;
@property (nonatomic, strong) NSMutableArray<DSTransactionOutput *> *mOutputs;

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
    self.mInputs = [NSMutableArray array];
    self.mOutputs = [NSMutableArray array];
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

        for (NSUInteger i = 0; i < count; i++) {          // inputs
            UInt256 hash = [message UInt256AtOffset:off]; // input hash
            off += sizeof(UInt256);
            uint32_t index = [message UInt32AtOffset:off]; // input index
            off += sizeof(uint32_t);
            NSData *inScript = nil;                                   // placeholder for input script (comes from input transaction)
            NSData *signature = [message dataAtOffset:off length:&l]; // input signature
            off += l.unsignedIntegerValue;
            uint32_t sequence = [message UInt32AtOffset:off]; // input sequence number (for replacement tx)
            off += sizeof(uint32_t);
            DSTransactionInput *transactionInput = [DSTransactionInput transactionInputWithHash:hash index:index inScript:inScript signature:signature sequence:sequence];
            [self.mInputs addObject:transactionInput];
        }

        count = (NSUInteger)[message varIntAtOffset:off length:&l]; // output count
        off += l.unsignedIntegerValue;

        for (NSUInteger i = 0; i < count; i++) {            // outputs
            uint64_t amount = [message UInt64AtOffset:off]; // output amount
            off += sizeof(uint64_t);
            NSData *outScript = [message dataAtOffset:off length:&l]; // output script
            off += l.unsignedIntegerValue;
            DSTransactionOutput *transactionOutput = [DSTransactionOutput transactionOutputWithAmount:amount outScript:outScript onChain:self.chain];
            [self.mOutputs addObject:transactionOutput];
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

    if (self.associatedShapeshift || ![self.outputs count]) return self;

    NSString *mainOutputAddress = nil;
    NSMutableArray *allAddresses = [NSMutableArray array];
    for (DSAddressEntity *e in [DSAddressEntity allObjectsInContext:chain.chainManagedObjectContext]) {
        [allAddresses addObject:e.address];
    }
    for (DSTransactionOutput *output in self.outputs) {
        NSString *outputAddress = output.address;
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
    self.mInputs = [NSMutableArray array];
    UInt256 inputHash;
    for (int i = 0; i < hashes.count; i++) {
        NSValue *hashValue = [hashes objectAtIndex:i];
        [hashValue getValue:&inputHash];
        uint32_t index = [[indexes objectAtIndex:i] unsignedIntValue];
        uint32_t inputSequence = [[inputSequences objectAtIndex:i] unsignedIntValue];
        NSData *inputScript = (scripts.count > 0) ? [scripts objectAtIndex:i] : nil;
        [self.mInputs addObject:[DSTransactionInput transactionInputWithHash:inputHash index:index inScript:inputScript signature:nil sequence:inputSequence]];
    }

    self.mOutputs = [NSMutableArray array];
    for (int i = 0; i < amounts.count; i++) {
        uint64_t amount = [[amounts objectAtIndex:i] unsignedLongValue];
        id address = [addresses objectAtIndex:i];
        NSMutableData *outScript = [NSMutableData data];
        if ([address isEqual:[NSNull null]]) {
            [outScript appendUInt8:OP_RETURN];
        } else {
            [outScript appendScriptPubKeyForAddress:address forChain:chain];
        }
        [self.mOutputs addObject:[DSTransactionOutput transactionOutputWithAmount:amount outScript:outScript onChain:self.chain]];
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

- (NSArray<DSTransactionInput *> *)inputs {
    return [self.mInputs copy];
}

- (NSArray<DSTransactionOutput *> *)outputs {
    return [self.mOutputs copy];
}

- (NSArray *)inputAddresses {
    @synchronized (self) {
        NSMutableArray *rAddresses = [NSMutableArray arrayWithCapacity:self.mInputs.count];
        for (DSTransactionInput *input in self.mInputs) {
            if (input.inScript) {
                NSString *address = [NSString addressWithScriptPubKey:input.inScript onChain:self.chain];
                [rAddresses addObject:(address) ? address : [NSNull null]];
            } else {
                NSString *address = [NSString addressWithScriptSig:input.signature onChain:self.chain];
                [rAddresses addObject:(address) ? address : [NSNull null]];
            }
        }
        return rAddresses;
    }
}

- (NSArray *)outputAddresses {
    @synchronized (self) {
        NSMutableArray *rAddresses = [NSMutableArray array];
        for (DSTransactionOutput *output in self.mOutputs) {
            if (output.address) {
                [rAddresses addObject:output.address];
            } else {
                [rAddresses addObject:[NSNull null]];
            }
        }
        return [rAddresses copy];
    }
}

- (NSString *)description {
    NSString *txid = [NSString hexWithData:[NSData dataWithBytes:self.txHash.u8 length:sizeof(UInt256)].reverse];
    return [NSString stringWithFormat:@"%@(id=%@-block=%@) + (%@)", [self class], txid, (self.blockHeight == TX_UNCONFIRMED) ? @"Not mined" : @(self.blockHeight), [super description]];
}

- (NSString *)longDescription {
    NSString *txid = [NSString hexWithData:[NSData dataWithBytes:self.txHash.u8 length:sizeof(UInt256)].reverse];
    return [NSString stringWithFormat:@"%@(id=%@, inputs=%@, outputs=%@)",
                     [[self class] description], txid,
                     self.inputs,
                     self.outputs];
}

// retuns the amount sent from the wallet by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSent {
    uint64_t amount = 0;
    for (DSTransactionInput *input in self.inputs) {
        UInt256 hash = input.inputHash;
        DSTransaction *tx = [self.chain transactionForHash:hash];
        DSAccount *account = [self.chain firstAccountThatCanContainTransaction:tx];
        uint32_t n = input.index;
        if (n < tx.outputs.count) {
            DSTransactionOutput *output = tx.outputs[n];
            if ([account containsAddress:output.address])
                amount += output.amount;
        }
    }
    return amount;
}

// size in bytes if signed, or estimated size assuming compact pubkey sigs
- (size_t)size {
    if (uint256_is_not_zero(_txHash)) return self.data.length;
    @synchronized(self) {
        uint32_t inputCount = (uint32_t)self.mInputs.count;
        uint32_t outputCount = (uint32_t)self.mOutputs.count;
        return 8 + [NSMutableData sizeOfVarInt:inputCount] + [NSMutableData sizeOfVarInt:outputCount] +
               TX_INPUT_SIZE * inputCount + TX_OUTPUT_SIZE * outputCount;
    }
}

- (uint64_t)standardFee {
    return self.size * TX_FEE_PER_B;
}

- (uint64_t)standardInstantFee {
    return TX_FEE_PER_INPUT * [self.inputs count];
}

// checks if all signatures exist, but does not verify them
- (BOOL)isSigned {
    @synchronized (self) {
        BOOL isSigned = TRUE;
        for (DSTransactionInput *transactionInput in self.mInputs) {
            BOOL inputIsSigned = transactionInput.signature != nil;
            isSigned &= inputIsSigned;
            if (!inputIsSigned) {
                break;
            }
        }
        return isSigned;
    }
}

- (BOOL)isCoinbaseClassicTransaction {
    @synchronized (self) {
        if (([self.mInputs count] == 1)) {
            DSTransactionInput *firstInput = self.mInputs[0];
            if (uint256_is_zero(firstInput.inputHash) && firstInput.index == UINT32_MAX) return TRUE;
        }
        return NO;
    }
}

- (BOOL)isCreditFundingTransaction {
    for (DSTransactionOutput *output in self.outputs) {
        NSData *script = output.outScript;
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
    @synchronized (self) {
        BOOL forSigHash = ([self isMemberOfClass:[DSTransaction class]] || [self isMemberOfClass:[DSCreditFundingTransaction class]]) && subscriptIndex != NSNotFound;
        NSUInteger dataSize = 8 + [NSMutableData sizeOfVarInt:self.mInputs.count] + [NSMutableData sizeOfVarInt:self.mOutputs.count] + TX_INPUT_SIZE * self.mInputs.count + TX_OUTPUT_SIZE * self.mOutputs.count + (forSigHash ? 4 : 0);
        NSMutableData *d = [NSMutableData dataWithCapacity:dataSize];

        [d appendUInt16:self.version];
        [d appendUInt16:self.type];
        [d appendVarInt:self.mInputs.count];


        for (NSUInteger i = 0; i < self.mInputs.count; i++) {
            DSTransactionInput *input = self.mInputs[i];
            [d appendUInt256:input.inputHash];
            [d appendUInt32:input.index];

            if (subscriptIndex == NSNotFound && input.signature != nil) {
                [d appendVarInt:[input.signature length]];
                [d appendData:input.signature];
            } else if (subscriptIndex == i && input.inScript != nil) {
                //TODO: to fully match the reference implementation, OP_CODESEPARATOR related checksig logic should go here
                [d appendVarInt:[input.inScript length]];
                [d appendData:input.inScript];
            } else
                [d appendVarInt:0];

            [d appendUInt32:input.sequence];
        }

        [d appendVarInt:self.mOutputs.count];

        for (NSUInteger i = 0; i < self.mOutputs.count; i++) {
            DSTransactionOutput *output = self.mOutputs[i];
            [d appendUInt64:output.amount];
            [d appendVarInt:[output.outScript length]];
            [d appendData:output.outScript];
        }

        [d appendUInt32:self.lockTime];
        if (forSigHash) [d appendUInt32:SIGHASH_ALL];
        return d;
    }
}

// MARK: - Construction

- (void)addInputHash:(UInt256)hash index:(NSUInteger)index script:(NSData *)script {
    [self addInputHash:hash index:index script:script signature:nil sequence:TXIN_SEQUENCE];
}

- (void)addInputHash:(UInt256)hash index:(NSUInteger)index script:(NSData *)script signature:(NSData *)signature
            sequence:(uint32_t)sequence {
    @synchronized (self) {
        DSTransactionInput *transactionInput = [DSTransactionInput transactionInputWithHash:hash index:(uint32_t)index inScript:script signature:signature sequence:sequence];
        [self.mInputs addObject:transactionInput];
    }
}

- (void)addOutputAddress:(NSString *)address amount:(uint64_t)amount {
    @synchronized (self) {
        DSTransactionOutput *transactionOutput = [DSTransactionOutput transactionOutputWithAmount:amount outScript:[NSData scriptPubKeyForAddress:address forChain:self.chain] onChain:self.chain];
        [self.mOutputs addObject:transactionOutput];
    }
}

- (void)addOutputCreditAddress:(NSString *)address amount:(uint64_t)amount {
    @synchronized (self) {
        DSTransactionOutput *transactionOutput = [DSTransactionOutput transactionOutputWithAmount:amount outScript:[NSData scriptPubKeyForAddress:address forChain:self.chain] onChain:self.chain];
        [self.mOutputs addObject:transactionOutput];
    }
}

- (void)addOutputShapeshiftAddress:(NSString *)address {
    @synchronized (self) {
        NSMutableData *outScript = [NSMutableData data];
        [outScript appendShapeshiftMemoForAddress:address];
        DSTransactionOutput *transactionOutput = [DSTransactionOutput transactionOutputWithAmount:0 outScript:outScript onChain:self.chain];
        [self.mOutputs addObject:transactionOutput];
    }
}

- (void)addOutputBurnAmount:(uint64_t)amount {
    @synchronized (self) {
        NSMutableData *outScript = [NSMutableData data];
        [outScript appendUInt8:OP_RETURN];
        DSTransactionOutput *transactionOutput = [DSTransactionOutput transactionOutputWithAmount:amount outScript:outScript onChain:self.chain];
        [self.mOutputs addObject:transactionOutput];
    }
}

- (void)addOutputScript:(NSData *)script amount:(uint64_t)amount {
    @synchronized (self) {
        NSString *address = [NSString addressWithScriptPubKey:script onChain:self.chain];
        [self addOutputScript:script withAddress:address amount:amount];
    }
}


- (void)addOutputScript:(NSData *_Nonnull)script withAddress:(NSString *)address amount:(uint64_t)amount {
    NSParameterAssert(script);
    @synchronized (self) {
        if (!address && script) {
            address = [NSString addressWithScriptPubKey:script onChain:self.chain];
        }
        DSTransactionOutput *transactionOutput = [DSTransactionOutput transactionOutputWithAmount:amount address:address outScript:script onChain:self.chain];
        [self.mOutputs addObject:transactionOutput];
    }
}

- (void)setInputAddress:(NSString *)address atIndex:(NSUInteger)index {
    @synchronized (self) {
        NSMutableData *inputScript = [NSMutableData data];
        [inputScript appendScriptPubKeyForAddress:address forChain:self.chain];
        self.mInputs[index].inScript = inputScript;
    }
}

- (void)shuffleOutputOrder {
    @synchronized (self) {
        for (NSUInteger i = 0; i + 1 < self.mOutputs.count; i++) { // fischer-yates shuffle
            NSUInteger j = i + arc4random_uniform((uint32_t)(self.mOutputs.count - i));

            if (j == i) continue;
            [self.mOutputs exchangeObjectAtIndex:i withObjectAtIndex:j];
        }
    }
}

/**
 * Hashes (in reversed byte-order) are to be sorted in ASC order, lexicographically.
 * If they're match -> the respective indices will be compared, in ASC.
 */
- (void)sortInputsAccordingToBIP69 {
    @synchronized (self) {
        self.mInputs = [[self.mInputs sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
            DSTransactionInput *input1 = (DSTransactionInput *)obj1;
            DSTransactionInput *input2 = (DSTransactionInput *)obj2;
            return [input1 compare:input2];
        }] mutableCopy];
    }
}

/**
 * Amounts are to be sorted in ASC.
 * If they're equal -> respective outScripts will be compared lexicographically, in ASC.
 */
- (void)sortOutputsAccordingToBIP69 {
    @synchronized (self) {
        self.mOutputs = [[self.mOutputs sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
            DSTransactionOutput *output1 = (DSTransactionOutput *)obj1;
            DSTransactionOutput *output2 = (DSTransactionOutput *)obj2;
            return [output1 compare:output2];
        }] mutableCopy];
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
    @synchronized (self) {
        for (NSUInteger i = 0; i < self.mInputs.count; i++) {
            DSTransactionInput *transactionInput = self.mInputs[i];
            NSMutableData *sig = [NSMutableData data];
            NSData *data = [self toDataWithSubscriptIndex:i];
            UInt256 hash = data.SHA256_2;
            NSMutableData *s = [NSMutableData dataWithData:[keys[i] sign:hash]];
            NSArray *elem = [transactionInput.inScript scriptElements];

            [s appendUInt8:SIGHASH_ALL];
            [sig appendScriptPushData:s];

            if (elem.count >= 2 && [elem[elem.count - 2] intValue] == OP_EQUALVERIFY) { // pay-to-pubkey-hash scriptSig
                [sig appendScriptPushData:[keys[i] publicKeyData]];
            }

            transactionInput.signature = sig;
        }

        if (!self.isSigned) return NO;
        _txHash = self.data.SHA256_2;
        return YES;
    }
}

- (BOOL)signWithPrivateKeys:(NSArray *)keys forAddresses:(NSArray *)addresses {
    @synchronized (self) {
       for (NSUInteger i = 0; i < self.mInputs.count; i++) {
            DSTransactionInput *transactionInput = self.mInputs[i];
            NSString *addr = [NSString addressWithScriptPubKey:transactionInput.inScript onChain:self.chain];
            NSUInteger keyIdx = (addr) ? [addresses indexOfObject:addr] : NSNotFound;

            if (keyIdx == NSNotFound) continue;

            NSMutableData *sig = [NSMutableData data];
            NSData *data = [self toDataWithSubscriptIndex:i];
            UInt256 hash = data.SHA256_2;
            NSMutableData *s = [NSMutableData dataWithData:[keys[keyIdx] sign:hash]];
            NSArray *elem = [transactionInput.inScript scriptElements];

            [s appendUInt8:SIGHASH_ALL];
            [sig appendScriptPushData:s];

            if (elem.count >= 2 && [elem[elem.count - 2] intValue] == OP_EQUALVERIFY) { // pay-to-pubkey-hash scriptSig
                [sig appendScriptPushData:[keys[keyIdx] publicKeyData]];
            }

            transactionInput.signature = sig;
        }

        if (!self.isSigned) return NO;
        _txHash = self.data.SHA256_2;
        return YES;
    }
}

// MARK: - Priority (Deprecated)

// priority = sum(input_amount_in_satoshis*input_age_in_blocks)/size_in_bytes
- (uint64_t)priorityForAmounts:(NSArray *)amounts withAges:(NSArray *)ages {
    uint64_t p = 0;
    @synchronized (self) {
        if (amounts.count != self.mInputs.count || ages.count != self.mInputs.count || [ages containsObject:@(0)]) return 0;
        for (NSUInteger i = 0; i < amounts.count; i++) {
            p += [amounts[i] unsignedLongLongValue] * [ages[i] unsignedLongLongValue];
        }
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
    for (DSTransactionOutput *output in self.outputs) {
        if (output.amount > TX_MIN_OUTPUT_AMOUNT && [wallet containsAddress:output.address]) {
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
    for (DSTransactionOutput *output in self.outputs) {
        for (DSFundsDerivationPath *derivationPath in derivationPaths) {
            if ([derivationPath isKindOfClass:[DSIncomingFundsDerivationPath class]] &&
                [derivationPath containsAddress:output.address]) {
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
    for (DSTransactionOutput *output in self.outputs) {
        NSString *outboundAddress = [DSTransaction shapeshiftOutboundAddressForScript:output.outScript onChain:self.chain];
        if (outboundAddress) return outboundAddress;
    }
    return nil;
}

- (NSString *)shapeshiftOutboundAddressForceScript {
    for (DSTransactionOutput *output in self.outputs) {
        NSString *outboundAddress = [DSTransaction shapeshiftOutboundAddressForceScript:output.outScript];
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
