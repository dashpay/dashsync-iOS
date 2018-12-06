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

NS_ASSUME_NONNULL_BEGIN

#define SEQUENCE_GAP_LIMIT_EXTERNAL 10
#define SEQUENCE_GAP_LIMIT_INTERNAL 5

#define EXTENDED_0_PUBKEY_KEY_BIP44_V0   @"masterpubkeyBIP44" //these are old and need to be retired
#define EXTENDED_0_PUBKEY_KEY_BIP32_V0   @"masterpubkeyBIP32" //these are old and need to be retired
#define EXTENDED_0_PUBKEY_KEY_BIP44_V1   @"extended0pubkeyBIP44"
#define EXTENDED_0_PUBKEY_KEY_BIP32_V1   @"extended0pubkeyBIP32"

typedef void (^TransactionValidityCompletionBlock)(BOOL signedTransaction);

#define BIP32_HARD 0x80000000

@class DSTransaction,DSKey,DSAccount,DSDerivationPath;

typedef NS_ENUM(NSUInteger, DSDerivationPathType) {
    DSDerivationPathType_ClearFunds = 1,
    DSDerivationPathType_AnonymousFunds = 1 << 1,
    DSDerivationPathType_ViewOnlyFunds = 1 << 2,
    DSDerivationPathType_Authentication = 1 << 3,
    DSDerivationPathType_Transitioning = 1 << 4,
    
    DSDerivationPathType_IsForFunds = DSDerivationPathType_ClearFunds | DSDerivationPathType_AnonymousFunds | DSDerivationPathType_ViewOnlyFunds
};

typedef NS_ENUM(NSUInteger, DSDerivationPathSigningAlgorith) {
    DSDerivationPathSigningAlgorith_ECDSA,
    DSDerivationPathSigningAlgorith_BLS
};

typedef NS_ENUM(NSUInteger, DSDerivationPathReference) {
    DSDerivationPathReference_Unknown = 0,
    DSDerivationPathReference_BIP32 = 1,
    DSDerivationPathReference_BIP44 = 2,
    DSDerivationPathReference_BlochainUsers = 3
};

@interface DSDerivationPath : NSIndexPath

//is this an open account
@property (nonatomic,assign,readonly) DSDerivationPathType type;

@property (nonatomic,assign,readonly) DSDerivationPathSigningAlgorith signingAlgorithm;

// account for the derivation path
@property (nonatomic, readonly) DSChain * chain;
// account for the derivation path
@property (nonatomic, readonly, weak, nullable) DSAccount * account;

@property (nonatomic, readonly, weak, nullable) DSWallet * wallet;

// extended Public Key
@property (nonatomic, readonly) NSData * extendedPublicKey;

@property (nonatomic, readonly) BOOL hasExtendedPublicKey;

// this returns the derivation path's visual representation (e.g. m/44'/5'/0')
@property (nonatomic, readonly) NSString * stringRepresentation;

// extended Public Key Identifier, which is just the short hex string of the extended public key
@property (nonatomic, readonly, nullable) NSString * standaloneExtendedPublicKeyUniqueID;

// the walletBasedExtendedPublicKeyLocationString is the key used to store the public key in nsuserdefaults
@property (nonatomic, readonly, nullable) NSString * walletBasedExtendedPublicKeyLocationString;

// current derivation path balance excluding transactions known to be invalid
@property (nonatomic, assign) uint64_t balance;

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

// purpose of the derivation path if BIP 43 based
@property (nonatomic, readonly) NSUInteger purpose;

// currently the derivationPath is synced to this block height
@property (nonatomic, assign) uint32_t syncBlockHeight;


// the reference of type of derivation path
@property (nonatomic, readonly) DSDerivationPathReference reference;

// there might be times where the derivationPath is actually unknown, for example when importing from an extended public key
@property (nonatomic, readonly) BOOL derivationPathIsKnown;

+ (instancetype)bip32DerivationPathOnChain:(DSChain*)chain forAccountNumber:(uint32_t)accountNumber;

+ (instancetype)bip44DerivationPathOnChain:(DSChain*)chain forAccountNumber:(uint32_t)accountNumber;

+ (instancetype)blockchainUsersDerivationPathForWallet:(DSWallet*)wallet;

+ (instancetype _Nullable)derivationPathWithIndexes:(NSUInteger *)indexes length:(NSUInteger)length
                                               type:(DSDerivationPathType)type signingAlgorithm:(DSDerivationPathSigningAlgorith)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain*)chain;

+ (instancetype _Nullable)derivationPathWithSerializedExtendedPrivateKey:(NSString*)serializedExtendedPrivateKey fundsType:(DSDerivationPathType)fundsType signingAlgorithm:(DSDerivationPathSigningAlgorith)signingAlgorithm onChain:(DSChain*)chain;

+ (instancetype _Nullable)derivationPathWithSerializedExtendedPublicKey:(NSString*)serializedExtendedPublicKey onChain:(DSChain*)chain;

- (instancetype _Nullable)initWithExtendedPublicKeyIdentifier:(NSString*)extendedPublicKeyIdentifier onChain:(DSChain*)chain;

- (instancetype _Nullable)initWithIndexes:(NSUInteger *)indexes length:(NSUInteger)length
                                     type:(DSDerivationPathType)type signingAlgorithm:(DSDerivationPathSigningAlgorith)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain*)chain;

-(BOOL)isBIP32Only;
-(BOOL)isBIP43Based;

// set the account, can not be later changed
- (void)setAccount:(DSAccount *)account;

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString *)address;

// true if the address was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsed:(NSString *)address;

// inform the derivation path that the address has been used by a transaction
- (void)registerTransactionAddress:(NSString *)address;

// gets a public key at an index
- (NSData*)publicKeyAtIndex:(uint32_t)index;

// gets a public key at an index path
- (NSData*)publicKeyAtIndexPath:(NSIndexPath *)indexPath;

- (NSString *)receiveAddressAtOffset:(NSUInteger)offset;

// gets an addess at an index
- (NSString *)addressAtIndex:(uint32_t)index;

// gets an address at an index path
- (NSString *)addressAtIndexPath:(NSIndexPath *)indexPath;

// gets an addess at an index one level down based on bip32
- (NSString *)addressAtIndex:(uint32_t)index internal:(BOOL)internal;

// Derivation paths are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused addresses
// following the last used address in the chain. The internal chain is used for change addresses and the external chain
// for receive addresses.  These have a hardened purpose scheme depending on the derivation path
- (NSArray * _Nullable)registerAddressesWithGapLimit:(NSUInteger)gapLimit internal:(BOOL)internal;

- (NSData * _Nullable)deprecatedIncorrectExtendedPublicKeyFromSeed:(NSData * _Nullable)seed;

//you can set wallet unique Id to nil if you don't wish to store the extended Public Key
- (NSData * _Nullable)generateExtendedPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString* _Nullable)walletUniqueId;
- (NSData * _Nullable)generatePublicKeyAtIndex:(uint32_t)n internal:(BOOL)internal;
- (NSArray *)publicKeysToIndex:(NSUInteger)index;
- (NSArray *)addressesToIndex:(NSUInteger)index;
- (DSKey * _Nullable)privateKeyAtIndexPath:(NSIndexPath*)indexPath fromSeed:(NSData *)seed;
- (NSString * _Nullable)privateKey:(uint32_t)n internal:(BOOL)internal fromSeed:(NSData *)seed;
- (NSArray * _Nullable)privateKeys:(NSArray *)n internal:(BOOL)internal fromSeed:(NSData *)seed;

// key used for authenticated API calls, i.e. bitauth: https://github.com/bitpay/bitauth
+ (NSString * _Nullable)authPrivateKeyFromSeed:(NSData * _Nullable)seed forChain:(DSChain*)chain;

// key used for BitID: https://github.com/bitid/bitid/blob/master/BIP_draft.md
+ (NSString * _Nullable)bitIdPrivateKey:(uint32_t)n forURI:(NSString *)uri fromSeed:(NSData *)seed forChain:(DSChain*)chain;

- (NSString * _Nullable)serializedExtendedPublicKey;

- (NSString * _Nullable)serializedExtendedPrivateKeyFromSeed:(NSData * _Nullable)seed;
+ (NSData * _Nullable)deserializedExtendedPrivateKey:(NSString *)extendedPrivateKeyString onChain:(DSChain*)chain;

+ (NSData *)deserializedExtendedPublicKey:(NSString *)extendedPublicKeyString onChain:(DSChain*)chain;
- (NSData * _Nullable)deserializedExtendedPublicKey:(NSString *)extendedPublicKeyString;

- (NSArray *)addressesForExportWithInternalRange:(NSRange)exportInternalRange externalCount:(NSRange)exportExternalRange;

//this loads the derivation path once it is set to an account that has a wallet;
-(void)loadAddresses;

-(BOOL)isDerivationPathEqual:(id)object;

@end

NS_ASSUME_NONNULL_END
