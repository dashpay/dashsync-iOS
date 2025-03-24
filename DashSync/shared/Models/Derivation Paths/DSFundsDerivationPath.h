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
#define SEQUENCE_GAP_LIMIT_INITIAL_COINJOIN 400

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

+ (instancetype)coinJoinDerivationPathForAccountNumber:(uint32_t)accountNumber onChain:(DSChain *)chain;

- (NSArray *)addressesForExportWithInternalRange:(NSRange)exportInternalRange externalCount:(NSRange)exportExternalRange;

- (NSString *)receiveAddressAtOffset:(NSUInteger)offset;

- (NSIndexPath *_Nullable)indexPathForKnownAddress:(NSString *)address;

- (BOOL)containsChangeAddress:(NSString *)address;
- (BOOL)containsReceiveAddress:(NSString *)address;

- (void)setHasKnownBalance;

@end

NS_ASSUME_NONNULL_END
