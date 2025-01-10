//
//  DSFundsDerivationPath.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPath.h"

#define SEQUENCE_GAP_LIMIT_EXTERNAL 10
#define SEQUENCE_GAP_LIMIT_INTERNAL 5
#define SEQUENCE_GAP_LIMIT_INITIAL 100

#define SEQUENCE_UNUSED_GAP_LIMIT_EXTERNAL 10
#define SEQUENCE_UNUSED_GAP_LIMIT_INTERNAL 5
#define SEQUENCE_UNUSED_GAP_LIMIT_INITIAL 15

#define SEQUENCE_DASHPAY_GAP_LIMIT_INCOMING 6
#define SEQUENCE_DASHPAY_GAP_LIMIT_OUTGOING 3
#define SEQUENCE_DASHPAY_GAP_LIMIT_INITIAL 10

#define EXTENDED_0_PUBKEY_KEY_BIP44_V0 @"masterpubkeyBIP44" //these are old and need to be retired
#define EXTENDED_0_PUBKEY_KEY_BIP32_V0 @"masterpubkeyBIP32" //these are old and need to be retired
#define EXTENDED_0_PUBKEY_KEY_BIP44_V1 @"extended0pubkeyBIP44"
#define EXTENDED_0_PUBKEY_KEY_BIP32_V1 @"extended0pubkeyBIP32"

NS_ASSUME_NONNULL_BEGIN

@interface DSFundsDerivationPath : DSDerivationPath

// returns the first unused external address
@property (nonatomic, readonly, nullable) NSString *receiveAddress;

// returns the first unused internal address
@property (nonatomic, readonly, nullable) NSString *changeAddress;

// all previously generated external addresses
@property (nonatomic, readonly) NSArray *allReceiveAddresses;

// all previously generated internal addresses
@property (nonatomic, readonly) NSArray *allChangeAddresses;

// used external addresses
@property (nonatomic, readonly) NSArray *usedReceiveAddresses;

// used internal addresses
@property (nonatomic, readonly) NSArray *usedChangeAddresses;

// we should use a reduced gap limit on derivation paths with no balance (except account 0 on bip44)
@property (nonatomic, readonly) BOOL shouldUseReducedGapLimit;

+ (instancetype)bip32DerivationPathForAccountNumber:(uint32_t)accountNumber onChain:(DSChain *)chain;

+ (instancetype)bip44DerivationPathForAccountNumber:(uint32_t)accountNumber onChain:(DSChain *)chain;

// Derivation paths are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused addresses
// following the last used address in the chain. The internal chain is used for change addresses and the external chain
// for receive addresses.  These have a hardened purpose scheme depending on the derivation path
- (NSArray *_Nullable)registerAddressesWithGapLimit:(NSUInteger)gapLimit internal:(BOOL)internal error:(NSError **)error;

- (NSData *_Nullable)publicKeyDataAtIndex:(uint32_t)n internal:(BOOL)internal;

// gets an addess at an index one level down based on bip32
- (NSString *)addressAtIndex:(uint32_t)index internal:(BOOL)internal;

- (NSArray *)addressesForExportWithInternalRange:(NSRange)exportInternalRange externalCount:(NSRange)exportExternalRange;

- (NSString *)receiveAddressAtOffset:(NSUInteger)offset;

- (NSIndexPath *_Nullable)indexPathForKnownAddress:(NSString *)address;

- (BOOL)containsChangeAddress:(NSString *)address;
- (BOOL)containsReceiveAddress:(NSString *)address;

- (void)setHasKnownBalance;

@end

NS_ASSUME_NONNULL_END
