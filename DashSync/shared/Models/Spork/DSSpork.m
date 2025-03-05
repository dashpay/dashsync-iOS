//
//  DSSpork.m
//  dashwallet
//
//  Created by Sam Westrich on 10/18/17.
//  Copyright © 2017 Aaron Voisine. All rights reserved.
//

#import "DSSpork.h"
#import "DSChain.h"
#import "DSChain+Params.h"
#import "DSChainManager.h"
#import "DSKeyManager.h"
#import "DSPeerManager.h"
#import "DSSporkManager+Protected.h"
#import "NSData+DSHash.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Dash.h"

@interface DSSpork ()

@property (nonatomic, strong) NSData *signature;
@property (nonatomic, strong) DSChain *chain;

@end

@implementation DSSpork


- (UInt256)sporkHash {
    //hash calculation
    NSMutableData *hashImportantData = [NSMutableData data];
    uint32_t index = (uint32_t)self.identifier;
    [hashImportantData appendBytes:&index length:4];
    uint64_t value = (uint64_t)self.value;
    [hashImportantData appendBytes:&value length:8];
    uint64_t timeSigned = (uint64_t)self.timeSigned;
    [hashImportantData appendBytes:&timeSigned length:8];
    return hashImportantData.SHA256_2;
}


+ (instancetype)sporkWithMessage:(NSData *)message onChain:(DSChain *)chain {
    return [[DSSpork alloc] initWithMessage:message onChain:chain];
}

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [self init])) return nil;
    _chain = chain;
    _identifier = [message UInt32AtOffset:0];
    _value = [message UInt64AtOffset:4];
    _timeSigned = [message UInt64AtOffset:12];
    NSNumber *lNumber = nil;
    NSData *signature = [message dataAtOffset:20 length:&lNumber];
    _valid = [self checkSignature:signature];
    self.signature = signature;
    return self;
}

- (instancetype)initWithIdentifier:(DSSporkIdentifier)identifier value:(uint64_t)value timeSigned:(uint64_t)timeSigned signature:(NSData *)signature onChain:(DSChain *)chain {
    if (!(self = [self init])) return nil;
    _chain = chain;
    _identifier = identifier;
    _value = value;
    _timeSigned = timeSigned;
    _valid = TRUE;
    self.signature = signature;
    return self;
}

- (BOOL)isEqualToSpork:(DSSpork *)spork {
    return (([self.chain isEqual:spork.chain]) && (self.identifier == spork.identifier) && (self.value == spork.value) && (self.timeSigned == spork.timeSigned) && (self.valid == spork.valid));
}

- (BOOL)checkSignature70208Method:(NSData *)signature {
    NSString *stringMessage = [NSString stringWithFormat:@"%d%llu%llu", self.identifier, self.value, self.timeSigned];
    NSMutableData *stringMessageData = [NSMutableData data];
    [stringMessageData appendString:DASH_MESSAGE_MAGIC];
    [stringMessageData appendString:stringMessage];
    UInt256 messageDigest = stringMessageData.SHA256_2;
    SLICE *compact_sig = slice_ctor(signature);
    u256 *message_digest = Arr_u8_32_ctor(32, messageDigest.u8);

    Result_ok_dash_spv_crypto_keys_ecdsa_key_ECDSAKey_err_dash_spv_crypto_keys_KeyError *msg_public_key = dash_spv_crypto_keys_ecdsa_key_ECDSAKey_key_with_compact_sig(compact_sig, message_digest);
//    slice_dtor(compact_sig);
//    u256_dtor(message_digest);
    if (!msg_public_key) {
        return NO;
    }
    if (!msg_public_key->ok) {
        Result_ok_dash_spv_crypto_keys_ecdsa_key_ECDSAKey_err_dash_spv_crypto_keys_KeyError_destroy(msg_public_key);
        return NO;
    }
    NSData *publicKeyData = [NSData dataFromHexString:[self sporkKey]];
    SLICE *public_key_data = slice_ctor(publicKeyData);
    
    Result_ok_dash_spv_crypto_keys_ecdsa_key_ECDSAKey_err_dash_spv_crypto_keys_KeyError *spork_public_key = dash_spv_crypto_keys_ecdsa_key_ECDSAKey_key_with_public_key_data(public_key_data);
//    slice_dtor(public_key_data);
    if (!spork_public_key) {
        Result_ok_dash_spv_crypto_keys_ecdsa_key_ECDSAKey_err_dash_spv_crypto_keys_KeyError_destroy(msg_public_key);
        return NO;
    }
    if (!spork_public_key->ok) {
        Result_ok_dash_spv_crypto_keys_ecdsa_key_ECDSAKey_err_dash_spv_crypto_keys_KeyError_destroy(msg_public_key);
        Result_ok_dash_spv_crypto_keys_ecdsa_key_ECDSAKey_err_dash_spv_crypto_keys_KeyError_destroy(spork_public_key);
        return NO;
    }
    BYTES *spork_public_key_data = dash_spv_crypto_keys_ecdsa_key_ECDSAKey_public_key_data(spork_public_key->ok);
    BOOL isEqual = dash_spv_crypto_keys_ecdsa_key_ECDSAKey_public_key_data_equal_to(msg_public_key->ok, spork_public_key_data);
    bytes_dtor(spork_public_key_data);
    Result_ok_dash_spv_crypto_keys_ecdsa_key_ECDSAKey_err_dash_spv_crypto_keys_KeyError_destroy(msg_public_key);
    Result_ok_dash_spv_crypto_keys_ecdsa_key_ECDSAKey_err_dash_spv_crypto_keys_KeyError_destroy(spork_public_key);

//    DOpaqueKey *messagePublicKey = key_ecdsa_recovered_from_compact_sig(signature.bytes, signature.length, messageDigest.u8);
//    DOpaqueKey *sporkPublicKey = [DSKeyManager keyWithPublicKeyData:[NSData dataFromHexString:[self sporkKey]] ofType:KeyKind_ECDSA];
//    BOOL isEqual = [DSKeyManager keysPublicKeyDataIsEqual:sporkPublicKey key2:messagePublicKey];
//    processor_destroy_opaque_key(messagePublicKey);
//    processor_destroy_opaque_key(sporkPublicKey);
    return isEqual;
}

- (BOOL)checkSignature:(NSData *)signature {
    if (self.chain.protocolVersion < 70209) {
        return [self checkSignature70208Method:signature];
    } else {
        SLICE *compact_sig = slice_ctor(signature);
        u256 *message_digest = Arr_u8_32_ctor(32, self.sporkHash.u8);
        Result_ok_dash_spv_crypto_keys_ecdsa_key_ECDSAKey_err_dash_spv_crypto_keys_KeyError *result = dash_spv_crypto_keys_ecdsa_key_ECDSAKey_key_with_compact_sig(compact_sig, message_digest);
        if (!result) return NO;
        if (!result->ok) {
            Result_ok_dash_spv_crypto_keys_ecdsa_key_ECDSAKey_err_dash_spv_crypto_keys_KeyError_destroy(result);
            return NO;
        }
        char *addr = dash_spv_crypto_keys_ecdsa_key_ECDSAKey_address_with_public_key_data(result->ok, self.chain.chainType);
        NSString *sporkAddress = [DSKeyManager NSStringFrom:addr];
        Result_ok_dash_spv_crypto_keys_ecdsa_key_ECDSAKey_err_dash_spv_crypto_keys_KeyError_destroy(result);

//        DOpaqueKey *messagePublicKey = key_ecdsa_recovered_from_compact_sig(signature.bytes, signature.length, self.sporkHash.u8);
//        NSString *sporkAddress = [DSKeyManager addressForKey:messagePublicKey forChainType:self.chain.chainType];
//        processor_destroy_opaque_key(messagePublicKey);
        DSSporkManager *sporkManager = self.chain.chainManager.sporkManager;
        return [[self sporkAddress] isEqualToString:sporkAddress] || (![sporkManager sporksUpdatedSignatures] && [self checkSignature70208Method:signature]);
    }
}

- (NSString *)sporkKey {
    if (self.chain.sporkPublicKeyHexString) return self.chain.sporkPublicKeyHexString;
    NSString *key = NULL;
    if (self.chain.sporkPrivateKeyBase58String) {
        DMaybeKeyData *result = dash_spv_crypto_keys_ecdsa_key_ECDSAKey_public_key_data_for_private_key(DChar(self.chain.sporkPrivateKeyBase58String), self.chain.chainType);
        if (result) {
            NSData *data = NSDataFromPtr(result->ok);
            if (data)
                key = data.hexString;
            DMaybeKeyDataDtor(result);
        }
    }
    return key;
}

//starting in 12.3 sporks use addresses instead of public keys
- (NSString *)sporkAddress {
    return self.chain.sporkAddress;
}

- (NSString *)identifierString {
    switch (self.identifier) { //!OCLINT
        case DSSporkIdentifier_Spork2InstantSendEnabled:
            return @"Instant Send enabled";
        case DSSporkIdentifier_Spork3InstantSendBlockFiltering:
            return @"Instant Send block filtering";
        case DSSporkIdentifier_Spork5InstantSendMaxValue:
            return @"Instant Send max value";
        case DSSporkIdentifier_Spork6NewSigs:
            return @"New Signature/Message Format";
        case DSSporkIdentifier_Spork8MasternodePaymentEnforcement:
            return @"Masternode payment enforcement";
        case DSSporkIdentifier_Spork9SuperblocksEnabled:
            return @"Superblocks enabled";
        case DSSporkIdentifier_Spork10MasternodePayUpdatedNodes:
            return @"Masternode pay updated nodes";
        case DSSporkIdentifier_Spork12ReconsiderBlocks:
            return @"Reconsider blocks";
        case DSSporkIdentifier_Spork13OldSuperblockFlag:
            return @"Old superblock flag";
        case DSSporkIdentifier_Spork14RequireSentinelFlag:
            return @"Require sentinel flag";
        case DSSporkIdentifier_Spork15DeterministicMasternodesEnabled:
            return @"DML enabled at block";
        case DSSporkIdentifier_Spork16InstantSendAutoLocks:
            return @"Instant Send auto-locks";
        case DSSporkIdentifier_Spork17QuorumDKGEnabled:
            return @"Quorum DKG enabled";
        case DSSporkIdentifier_Spork18QuorumDebugEnabled:
            return @"Quorum debugging enabled";
        case DSSporkIdentifier_Spork19ChainLocksEnabled:
            return @"Chain locks enabled";
        case DSSporkIdentifier_Spork20InstantSendLLMQBased:
            return @"LLMQ based Instant Send";
        case DSSporkIdentifier_Spork21QuorumAllConnected:
            return @"Quorum All connected";
        case DSSporkIdentifier_Spork22PSMoreParticipants:
            return @"PS More Participants";
        case DSSporkIdentifier_Spork23QuorumPoseConnected:
            return @"Quorum PoSe connected";
        default:
            return @"Unknown spork";
    }
}

@end
