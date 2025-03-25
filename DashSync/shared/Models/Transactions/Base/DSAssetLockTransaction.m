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

#import "DSAssetLockTransaction.h"
#import "DSChain+Params.h"
#import "DSAssetLockDerivationPath.h"
#import "DSAssetLockTransactionEntity+CoreDataClass.h"
#import "DSDerivationPathFactory.h"
#import "DSGapLimit.h"
#import "DSTransactionFactory.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"

@implementation DSAssetLockTransaction

- (instancetype)initOnChain:(DSChain *)chain withCreditOutputs:(NSArray<DSTransactionOutput *> *)creditOutputs {
    self = [super initOnChain:chain];
    if (self) {
        self.type = DSTransactionType_AssetLock;
        self.version = SPECIAL_TX_VERSION;
        self.creditOutputs = [creditOutputs mutableCopy];
        self.specialTransactionVersion = 1;
    }
    return self;
}

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [super initWithMessage:message onChain:chain]))
        return nil;
    self.type = DSTransactionType_AssetLock;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 1) return nil;
    NSNumber *payloadLengthSize = nil;
    __unused uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
    off += payloadLengthSize.unsignedLongValue;

    if (length - off < 1) return nil;
    self.specialTransactionVersion = [message UInt8AtOffset:off];
    off += 1;

    NSNumber *l = 0;
    if (length - off < 1) return nil;
    uint64_t count = (NSUInteger)[message varIntAtOffset:off length:&l]; // output count
    off += l.unsignedIntegerValue;
 
    NSMutableArray *creditOutputs = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {            // outputs
        uint64_t amount = [message UInt64AtOffset:off]; // output amount
        off += sizeof(uint64_t);
        NSData *outScript = [message dataAtOffset:off length:&l]; // output script
        off += l.unsignedIntegerValue;
        DSTransactionOutput *transactionOutput = [DSTransactionOutput transactionOutputWithAmount:amount outScript:outScript onChain:self.chain];
        [creditOutputs addObject:transactionOutput];
    }
    self.creditOutputs = creditOutputs;
    self.payloadOffset = off;
    self.txHash = self.data.SHA256_2;
    
    return self;
}

- (NSData *)payloadData {
    return [self basePayloadData];
}

- (NSData *)basePayloadData {
    NSMutableData *data = [NSMutableData data];
    [data appendUInt8:self.specialTransactionVersion];
    NSUInteger creditOutputsCount = self.creditOutputs.count;
    [data appendVarInt:creditOutputsCount];
    for (NSUInteger i = 0; i < creditOutputsCount; i++) {
        DSTransactionOutput *output = self.creditOutputs[i];
        [data appendUInt64:output.amount];
        [data appendCountedData:output.outScript];
    }
    return data;
}


- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex anyoneCanPay:(BOOL)anyoneCanPay {
    @synchronized(self) {
        NSMutableData *data = [[super toDataWithSubscriptIndex:subscriptIndex anyoneCanPay:anyoneCanPay] mutableCopy];
        [data appendCountedData:[self payloadData]];
        if (subscriptIndex != NSNotFound) [data appendUInt32:SIGHASH_ALL];
        return data;
    }
}
- (size_t)size {
    @synchronized(self) {
        if (uint256_is_not_zero(self.txHash)) return self.data.length;
        return [super size] + [NSMutableData sizeOfVarInt:self.payloadData.length] + ([self basePayloadData].length);
    }
}

- (UInt256)creditBurnIdentityIdentifier {
    DSUTXO outpoint = [self lockedOutpoint];
    if (dsutxo_is_zero(outpoint)) return UINT256_ZERO;
    return [dsutxo_data(outpoint) SHA256_2];
}

- (DSUTXO)lockedOutpoint {
    if (![self.creditOutputs count]) return DSUTXO_ZERO;
    DSUTXO outpoint = {.hash = uint256_reverse(self.txHash), .n = 0}; //!OCLINT
    return outpoint;
}

- (UInt160)creditBurnPublicKeyHash {
    DSTransactionOutput *output = self.creditOutputs.firstObject;
    Vec_u8 *maybe_pub_key_hash = dash_spv_crypto_util_address_address_public_key_hash_from_script(bytes_ctor(output.outScript));
    if (maybe_pub_key_hash) {
        NSData *result = NSDataFromPtr(maybe_pub_key_hash);
        bytes_dtor(maybe_pub_key_hash);
        return result.UInt160;
    }
    return UINT160_ZERO;
}
- (BOOL)checkInvitationDerivationPathIndexForWallet:(DSWallet *)wallet isIndex:(uint32_t)index {
    DSAssetLockDerivationPath *path = [[DSDerivationPathFactory sharedInstance] identityInvitationFundingDerivationPathForWallet:wallet];
    NSString *address = [DSKeyManager addressFromHash160:[self creditBurnPublicKeyHash] forChain:self.chain];
    return [[path addressAtIndexPath:[NSIndexPath indexPathWithIndex:index]] isEqualToString:address];
}

- (BOOL)checkDerivationPathIndexForWallet:(DSWallet *)wallet isIndex:(uint32_t)index {
    DSAssetLockDerivationPath *path = [[DSDerivationPathFactory sharedInstance] identityRegistrationFundingDerivationPathForWallet:wallet];
    NSString *address = [DSKeyManager addressFromHash160:[self creditBurnPublicKeyHash] forChain:self.chain];
    return [[path addressAtIndexPath:[NSIndexPath indexPathWithIndex:index]] isEqualToString:address];
}


- (void)markInvitationAddressAsUsedInWallet:(DSWallet *)wallet {
    DSAssetLockDerivationPath *path = [[DSDerivationPathFactory sharedInstance] identityInvitationFundingDerivationPathForWallet:wallet];
    NSString *address = [DSKeyManager addressFromHash160:[self creditBurnPublicKeyHash] forChain:self.chain];
    [path registerTransactionAddress:address];
    [path registerAddressesWithSettings:[DSGapLimit withLimit:10]];
}

- (void)markAddressAsUsedInWallet:(DSWallet *)wallet {
    DSAssetLockDerivationPath *path = [[DSDerivationPathFactory sharedInstance] identityRegistrationFundingDerivationPathForWallet:wallet];
    NSString *address = [DSKeyManager addressFromHash160:[self creditBurnPublicKeyHash] forChain:self.chain];
    [path registerTransactionAddress:address];
    [path registerAddressesWithSettings:[DSGapLimit withLimit:10]];
}
- (void)markTopUpAddressAsUsedInWallet:(DSWallet *)wallet {
    DSAssetLockDerivationPath *path = [[DSDerivationPathFactory sharedInstance] identityTopupFundingDerivationPathForWallet:wallet];
    NSString *address = [DSKeyManager addressFromHash160:[self creditBurnPublicKeyHash] forChain:self.chain];
    [path registerTransactionAddress:address];
    [path registerAddressesWithSettings:[DSGapLimit withLimit:10]];
}

- (Class)entityClass {
    return [DSAssetLockTransactionEntity class];
}


@end

@implementation DSAssetLockTransaction (FFI)
+ (instancetype)ffi_from:(dashcore_blockdata_transaction_Transaction *)transaction onChain:(DSChain *)chain {
    if (!transaction->special_transaction_payload) {
        return nil;
    }
    // TODO: it's used just for ui
    switch (transaction->special_transaction_payload->tag) {
        case dashcore_blockdata_transaction_special_transaction_TransactionPayload_AssetLockPayloadType: {
            dashcore_blockdata_transaction_special_transaction_asset_lock_AssetLockPayload *payload = transaction->special_transaction_payload->asset_lock_payload_type;
            // TODO: implement it
            DSAssetLockTransaction *tx = [[DSAssetLockTransaction alloc] initOnChain:chain];
//            tx.
            return tx;
        }
        default: return nil;
    }
}
@end
