//
//  DSFundsDerivationPath.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPath.h"

#define SEQUENCE_GAP_LIMIT_EXTERNAL 10
#define SEQUENCE_GAP_LIMIT_INTERNAL 5

#define EXTENDED_0_PUBKEY_KEY_BIP44_V0   @"masterpubkeyBIP44" //these are old and need to be retired
#define EXTENDED_0_PUBKEY_KEY_BIP32_V0   @"masterpubkeyBIP32" //these are old and need to be retired
#define EXTENDED_0_PUBKEY_KEY_BIP44_V1   @"extended0pubkeyBIP44"
#define EXTENDED_0_PUBKEY_KEY_BIP32_V1   @"extended0pubkeyBIP32"

NS_ASSUME_NONNULL_BEGIN

@interface DSFundsDerivationPath : DSDerivationPath

// returns the first unused external address
@property (nonatomic, readonly, nullable) NSString * receiveAddress;

// returns the first unused internal address
@property (nonatomic, readonly, nullable) NSString * changeAddress;

// all previously generated external addresses
@property (nonatomic, readonly) NSArray * allReceiveAddresses;

// all previously generated internal addresses
@property (nonatomic, readonly) NSArray * allChangeAddresses;

// all previously generated addresses
@property (nonatomic, readonly) NSSet * allAddresses;

// all previously used addresses
@property (nonatomic, readonly) NSSet * usedAddresses;

+ (instancetype)bip32DerivationPathOnChain:(DSChain*)chain forAccountNumber:(uint32_t)accountNumber;

+ (instancetype)bip44DerivationPathOnChain:(DSChain*)chain forAccountNumber:(uint32_t)accountNumber;

// Derivation paths are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused addresses
// following the last used address in the chain. The internal chain is used for change addresses and the external chain
// for receive addresses.  These have a hardened purpose scheme depending on the derivation path
- (NSArray * _Nullable)registerAddressesWithGapLimit:(NSUInteger)gapLimit internal:(BOOL)internal;

- (NSString * _Nullable)privateKey:(uint32_t)n internal:(BOOL)internal fromSeed:(NSData *)seed;
- (NSArray * _Nullable)serializedPrivateKeys:(NSArray *)n internal:(BOOL)internal fromSeed:(NSData *)seed;

- (NSData * _Nullable)generatePublicKeyAtIndex:(uint32_t)n internal:(BOOL)internal;

// gets an addess at an index one level down based on bip32
- (NSString *)addressAtIndex:(uint32_t)index internal:(BOOL)internal;

- (NSArray *)addressesForExportWithInternalRange:(NSRange)exportInternalRange externalCount:(NSRange)exportExternalRange;

- (NSString *)receiveAddressAtOffset:(NSUInteger)offset;

@end

NS_ASSUME_NONNULL_END
