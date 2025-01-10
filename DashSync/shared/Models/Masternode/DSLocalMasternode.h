//
//  DSLocalMasternode.h
//  DashSync
//
//  Created by Sam Westrich on 2/9/19.
//

#import "BigIntTypes.h"
#import "DSKeyManager.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSChain, DSWallet, DSAccount, DSTransaction, DSProviderRegistrationTransaction, DSProviderUpdateServiceTransaction, DSProviderUpdateRegistrarTransaction, DSProviderUpdateRevocationTransaction;

typedef NS_ENUM(NSUInteger, DSLocalMasternodeStatus)
{
    DSLocalMasternodeStatus_New = 0,
    DSLocalMasternodeStatus_Created = 1,
    DSLocalMasternodeStatus_Registered = 2,
};

@interface DSLocalMasternode : NSObject

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) UInt128 ipAddress;
@property (nonatomic, readonly) NSString *ipAddressString;
@property (nonatomic, readonly) NSString *ipAddressAndPortString;
@property (nonatomic, readonly) NSString *ipAddressAndIfNonstandardPortString;
@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, readonly) NSString *portString;
@property (nonatomic, readonly) DSWallet *operatorKeysWallet; //only if this is contained in the wallet.
@property (nonatomic, readonly) uint32_t operatorWalletIndex; //the derivation path index of keys
@property (nonatomic, readonly) NSData *operatorPublicKeyData;
@property (nonatomic, readonly) DSWallet *ownerKeysWallet; //only if this is contained in the wallet.
@property (nonatomic, readonly) uint32_t ownerWalletIndex;
@property (nonatomic, readonly) NSData *ownerPublicKeyData;
@property (nonatomic, readonly) DSWallet *votingKeysWallet; //only if this is contained in the wallet.
@property (nonatomic, readonly) uint32_t votingWalletIndex;
@property (nonatomic, readonly) NSData *votingPublicKeyData;
@property (nonatomic, readonly) DSWallet *platformNodeKeysWallet; //only if this is contained in the wallet.
@property (nonatomic, readonly) uint32_t platformNodeWalletIndex;
@property (nonatomic, readonly) NSData *platformNodePublicKeyData;
@property (nonatomic, readonly) DSWallet *holdingKeysWallet; //only if this is contained in the wallet.
@property (nonatomic, readonly) uint32_t holdingWalletIndex;
@property (nonatomic, readonly) NSMutableIndexSet *previousOperatorWalletIndexes; //previously used operator indexes
@property (nonatomic, readonly) NSMutableIndexSet *previousVotingWalletIndexes;   //previously used voting indexes
@property (nonatomic, readonly) DSChain *chain;
@property (nonatomic, nullable, readonly) NSString *payoutAddress;
@property (nonatomic, readonly) NSString *operatorPayoutAddress;
@property (nonatomic, readonly) BOOL noLocalWallet;
@property (nonatomic, readonly) DSProviderRegistrationTransaction *providerRegistrationTransaction;
@property (nonatomic, readonly) NSArray<DSProviderUpdateRegistrarTransaction *> *providerUpdateRegistrarTransactions;
@property (nonatomic, readonly) NSArray<DSProviderUpdateServiceTransaction *> *providerUpdateServiceTransactions;
@property (nonatomic, readonly) NSArray<DSProviderUpdateRevocationTransaction *> *providerUpdateRevocationTransactions;
@property (nonatomic, readonly) DSLocalMasternodeStatus status;

- (void)registrationTransactionFundedByAccount:(DSAccount *)fundingAccount
                                     toAddress:(NSString *)address
                                    completion:(void (^_Nullable)(DSProviderRegistrationTransaction *providerRegistrationTransaction))completion;

- (void)registrationTransactionFundedByAccount:(DSAccount *)fundingAccount
                                     toAddress:(NSString *)address
                                withCollateral:(DSUTXO)collateral
                                    completion:(void (^_Nullable)(DSProviderRegistrationTransaction *providerRegistrationTransaction))completion;

- (void)updateTransactionForResetFundedByAccount:(DSAccount *)fundingAccount
                                      completion:(void (^_Nullable)(DSProviderUpdateServiceTransaction *providerRegistrationTransaction))completion;

- (void)updateTransactionFundedByAccount:(DSAccount *)fundingAccount
                             toIPAddress:(UInt128)ipAddress
                                    port:(uint32_t)port
                           payoutAddress:(NSString *_Nullable)payoutAddress
                              completion:(void (^_Nullable)(DSProviderUpdateServiceTransaction *providerUpdateServiceTransaction))completion;

- (void)updateTransactionFundedByAccount:(DSAccount *)fundingAccount
                          changeOperator:(UInt384)operatorKey
                     changeVotingKeyHash:(UInt160)votingKeyHash
                     changePayoutAddress:(NSString *_Nullable)payoutAddress
                              completion:(void (^_Nullable)(DSProviderUpdateRegistrarTransaction *providerUpdateRegistrarTransaction))completion;

- (void)reclaimTransactionToAccount:(DSAccount *)fundingAccount
                         completion:(void (^_Nullable)(DSTransaction *reclaimTransaction))completion;

- (void)registerName:(NSString *)name;

- (void)save;
- (void)saveInContext:(NSManagedObjectContext *)context;

// BLS
- (DMaybeOpaqueKey *_Nullable)operatorKeyFromSeed:(NSData *)seed;
// ECDSA
- (DMaybeOpaqueKey *_Nullable)ownerKeyFromSeed:(NSData *)seed;
- (DMaybeOpaqueKey *_Nullable)votingKeyFromSeed:(NSData *)seed;
// ED25519
- (DMaybeOpaqueKey *_Nullable)platformNodeKeyFromSeed:(NSData *)seed;

- (NSString *)operatorKeyStringFromSeed:(NSData *)seed;
- (NSString *_Nullable)ownerKeyStringFromSeed:(NSData *)seed;
- (NSString *_Nullable)votingKeyStringFromSeed:(NSData *)seed;
- (NSString *_Nullable)platformNodeKeyStringFromSeed:(NSData *)seed;

- (BOOL)forceOperatorPublicKey:(dash_spv_crypto_keys_key_OpaqueKey *)operatorPublicKey;
- (BOOL)forceOwnerPrivateKey:(dash_spv_crypto_keys_key_OpaqueKey *)ownerPrivateKey;
//the voting key can either be private or public key
- (BOOL)forceVotingKey:(dash_spv_crypto_keys_key_OpaqueKey *)votingKey;
- (BOOL)forcePlatformNodeKey:(dash_spv_crypto_keys_key_OpaqueKey *)platformNodeKey;

@end

NS_ASSUME_NONNULL_END
