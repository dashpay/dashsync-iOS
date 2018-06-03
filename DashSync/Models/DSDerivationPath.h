//
//  DSDerivationPath.h
//  DashSync
//
//  Created by Sam Westrich on 5/20/18.
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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "DSTransaction.h"
#import "NSData+Bitcoin.h"
#import "DSDerivationPath.h"
#import "DSChain.h"

#define SEQUENCE_GAP_LIMIT_EXTERNAL 10
#define SEQUENCE_GAP_LIMIT_INTERNAL 5

#define EXTENDED_0_PUBKEY_KEY_BIP44_V0   @"masterpubkeyBIP44" //these are old and need to be retired
#define EXTENDED_0_PUBKEY_KEY_BIP32_V0   @"masterpubkeyBIP32" //these are old and need to be retired
#define EXTENDED_0_PUBKEY_KEY_BIP44_V1   @"extended0pubkeyBIP44"
#define EXTENDED_0_PUBKEY_KEY_BIP32_V1   @"extended0pubkeyBIP32"

#define useDarkCoinSeed 0 //the darkcoin seed was retired quite a while ago

#if useDarkCoinSeed

#define BIP32_SEED_KEY "Darkcoin seed"

#define BIP32_XPRV_MAINNET     "\x02\xFE\x52\xCC" //// Dash BIP32 prvkeys start with 'drkp'
#define BIP32_XPUB_MAINNET     "\x02\xFE\x52\xF8" //// Dash BIP32 pubkeys start with 'drkv'
#define BIP32_XPRV_TESTNET     "\x02\xFE\x52\xCC"
#define BIP32_XPUB_TESTNET     "\x02\xFE\x52\xF8"

#else

#define BIP32_SEED_KEY "Bitcoin seed"

#define BIP32_XPRV_TESTNET     "\x04\x35\x83\x94"
#define BIP32_XPUB_TESTNET     "\x04\x35\x87\xCF"

#define BIP32_XPRV_MAINNET     "\x04\x88\xAD\xE4"
#define BIP32_XPUB_MAINNET     "\x04\x88\xB2\x1E"


#endif

typedef void (^TransactionValidityCompletionBlock)(BOOL signedTransaction);

#define BIP32_HARD 0x80000000

@class DSTransaction;
@class DSAccount;
@class DSDerivationPath;

typedef NS_ENUM(NSUInteger, DSDerivationPathFundsType) {
    DSDerivationPathFundsType_Clear,
    DSDerivationPathFundsType_Anonymous,
    DSDerivationPathFundsType_ViewOnly
};

typedef NS_ENUM(NSUInteger, DSDerivationPathReference) {
    DSDerivationPathReference_Unknown = 0,
    DSDerivationPathReference_BIP32 = 1,
    DSDerivationPathReference_BIP44 = 2
};

@interface DSDerivationPath : NSIndexPath

//is this an open account
@property (nonatomic,assign,readonly) DSDerivationPathFundsType type;

// account for the derivation path
@property (nonatomic, readonly, weak) DSAccount * account;

// extended Public Key
@property (nonatomic, readonly) NSData * extendedPublicKey;

// this returns the derivation path's visual representation (e.g. m/44'/5'/0')
@property (nonatomic, readonly) NSString * _Nonnull stringRepresentation;

// extended Public Key Identifier, which is just the short hex string of the extended public key
@property (nonatomic, readonly) NSString * _Nullable standaloneExtendedPublicKeyUniqueID;

// the walletBasedExtendedPublicKeyLocationString is the key used to store the public key in nsuserdefaults
@property (nonatomic, readonly) NSString * _Nullable walletBasedExtendedPublicKeyLocationString;

// current wallet balance excluding transactions known to be invalid
@property (nonatomic, readonly) uint64_t balance;

// returns the first unused external address
@property (nonatomic, readonly) NSString * _Nullable receiveAddress;

// returns the first unused internal address
@property (nonatomic, readonly) NSString * _Nullable changeAddress;

// all previously generated external addresses
@property (nonatomic, readonly) NSArray * _Nonnull allReceiveAddresses;

// all previously generated internal addresses
@property (nonatomic, readonly) NSArray * _Nonnull allChangeAddresses;

// all previously generated addresses
@property (nonatomic, readonly) NSSet * _Nonnull allAddresses;

// all previously used addresses
@property (nonatomic, readonly) NSSet * _Nonnull usedAddresses;



// the reference of type of derivation path
@property (nonatomic, readonly) DSDerivationPathReference reference;

// there might be times where the derivationPath is actually unknown, for example when importing from an extended public key
@property (nonatomic, readonly) BOOL derivationPathIsKnown;

+ (instancetype _Nonnull)bip32DerivationPathForAccountNumber:(uint32_t)accountNumber;

+ (instancetype _Nonnull)bip44DerivationPathForChainType:(DSChainType)chain forAccountNumber:(uint32_t)accountNumber;

+ (instancetype _Nullable)derivationPathWithIndexes:(NSUInteger *)indexes length:(NSUInteger)length
                                               type:(DSDerivationPathFundsType)type reference:(DSDerivationPathReference)reference;

+ (instancetype _Nullable)derivationPathWithSerializedExtendedPublicKey:(NSString* _Nonnull)serializedExtendedPublicKey onChain:(DSChain* _Nonnull)chain;

- (instancetype _Nullable)initWithExtendedPublicKeyIdentifier:(NSString* _Nonnull)extendedPublicKeyIdentifier onChain:(DSChain* _Nonnull)chain;

- (instancetype _Nullable)initWithIndexes:(NSUInteger *)indexes length:(NSUInteger)length
                                     type:(DSDerivationPathFundsType)type reference:(DSDerivationPathReference)reference;

// the extendedPublicKeyKeychainString is the key used to store the public key in nsuserdefaults, use this when setting for a new derivation path
- (NSString*)extendedPublicKeyKeychainStringForWalletUniqueID:(NSString*)uniqueID;

// set the account, can not be later changed
- (void)setAccount:(DSAccount *)account;

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString * _Nonnull)address;

// true if the address was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsed:(NSString * _Nonnull)address;

// inform the derivation path that the address has been used by a transaction
- (void)registerTransactionAddress:(NSString * _Nonnull)address;

// Derivation paths are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused addresses
// following the last used address in the chain. The internal chain is used for change addresses and the external chain
// for receive addresses.  These have a hardened purpose scheme depending on the derivation path
- (NSArray * _Nullable)registerAddressesWithGapLimit:(NSUInteger)gapLimit internal:(BOOL)internal;

- (NSData * _Nullable)deprecatedIncorrectExtendedPublicKeyFromSeed:(NSData * _Nullable)seed;

//you can set wallet unique Id to nil if you don't wish to store the extended Public Key
- (NSData * _Nullable)generateExtendedPublicKeyFromSeed:(NSData * _Nonnull)seed storeUnderWalletUniqueId:(NSString* _Nullable)walletUniqueId;
- (NSData * _Nullable)generatePublicKeyAtIndex:(uint32_t)n internal:(BOOL)internal;
- (NSString * _Nullable)privateKey:(uint32_t)n internal:(BOOL)internal fromSeed:(NSData * _Nonnull)seed;
- (NSArray * _Nullable)privateKeys:(NSArray * _Nonnull)n internal:(BOOL)internal fromSeed:(NSData * _Nonnull)seed;

// key used for authenticated API calls, i.e. bitauth: https://github.com/bitpay/bitauth
+ (NSString * _Nullable)authPrivateKeyFromSeed:(NSData * _Nullable)seed forChain:(DSChain* _Nonnull)chain;

// key used for BitID: https://github.com/bitid/bitid/blob/master/BIP_draft.md
+ (NSString * _Nullable)bitIdPrivateKey:(uint32_t)n forURI:(NSString * _Nonnull)uri fromSeed:(NSData * _Nonnull)seed forChain:(DSChain* _Nonnull)chain;

- (NSString * _Nullable)serializedPrivateMasterFromSeed:(NSData * _Nullable)seed;
- (NSString * _Nullable)serializedExtendedPublicKey;

+ (NSData *)deserializedExtendedPublicKey:(NSString * _Nonnull)extendedPublicKeyString onChain:(DSChain* _Nonnull)chain;
- (NSData * _Nullable)deserializedMasterPublicKey:(NSString * _Nonnull)masterPublicKeyString;



@end
