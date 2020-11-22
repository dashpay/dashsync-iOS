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
#import "DSUInt256IndexPath.h"
#import "DSChain.h"
#import "DSECDSAKey.h"
#import "DSKey.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^TransactionValidityCompletionBlock)(BOOL signedTransaction, BOOL cancelled);

#define BIP32_HARD 0x80000000

#define FEATURE_PURPOSE 9
#define FEATURE_PURPOSE_IDENTITIES 5
#define FEATURE_PURPOSE_IDENTITIES_SUBFEATURE_AUTHENTICATION 0
#define FEATURE_PURPOSE_DASHPAY 15

@class DSTransaction,DSKey,DSAccount,DSDerivationPath;

typedef NS_ENUM(NSUInteger, DSDerivationPathType) {
    DSDerivationPathType_Unknown = 0,
    DSDerivationPathType_ClearFunds = 1,
    DSDerivationPathType_AnonymousFunds = 1 << 1,
    DSDerivationPathType_ViewOnlyFunds = 1 << 2,
    DSDerivationPathType_SingleUserAuthentication = 1 << 3,
    DSDerivationPathType_MultipleUserAuthentication = 1 << 4,
    DSDerivationPathType_PartialPath = 1 << 5,
    DSDerivationPathType_ProtectedFunds = 1 << 6,
    DSDerivationPathType_CreditFunding = 1 << 7,
    
    DSDerivationPathType_IsForAuthentication = DSDerivationPathType_SingleUserAuthentication | DSDerivationPathType_MultipleUserAuthentication,
    DSDerivationPathType_IsForFunds = DSDerivationPathType_ClearFunds | DSDerivationPathType_AnonymousFunds | DSDerivationPathType_ViewOnlyFunds | DSDerivationPathType_ProtectedFunds
};

typedef NS_ENUM(NSUInteger, DSDerivationPathReference) {
    DSDerivationPathReference_Unknown = 0,
    DSDerivationPathReference_BIP32 = 1,
    DSDerivationPathReference_BIP44 = 2,
    DSDerivationPathReference_BlockchainIdentities = 3,
    DSDerivationPathReference_ProviderFunds = 4,
    DSDerivationPathReference_ProviderVotingKeys = 5,
    DSDerivationPathReference_ProviderOperatorKeys = 6,
    DSDerivationPathReference_ProviderOwnerKeys = 7,
    DSDerivationPathReference_ContactBasedFunds = 8,
    DSDerivationPathReference_ContactBasedFundsRoot = 9,
    DSDerivationPathReference_ContactBasedFundsExternal = 10,
    DSDerivationPathReference_BlockchainIdentityCreditRegistrationFunding = 11,
    DSDerivationPathReference_BlockchainIdentityCreditTopupFunding = 12,
};

@interface DSDerivationPath : DSUInt256IndexPath {
@private
    BOOL *_hardenedIndexes;
}

//is this an open account
@property (nonatomic,assign,readonly) DSDerivationPathType type;

@property (nonatomic,assign,readonly) DSKeyType signingAlgorithm;

// account for the derivation path
@property (nonatomic, readonly) DSChain * chain;
// account for the derivation path
@property (nonatomic, readonly, weak, nullable) DSAccount * account;

@property (nonatomic, readonly, weak, nullable) DSWallet * wallet;

// extended Public Key
@property (nonatomic, readonly) NSData * extendedPublicKeyData;

@property (nonatomic, readonly) BOOL hasExtendedPublicKey;

// this returns the derivation path's visual representation (e.g. m/44'/5'/0')
@property (nonatomic, readonly) NSString * stringRepresentation;

// extended Public Key Identifier, which is just the short hex string of the extended public key
@property (nonatomic, readonly, nullable) NSString * standaloneExtendedPublicKeyUniqueID;

// the walletBasedExtendedPublicKeyLocationString is the key used to store the public key in the key chain
@property (nonatomic, readonly, nullable) NSString * walletBasedExtendedPublicKeyLocationString;

// the walletBasedExtendedPublicKeyLocationString is the key used to store the private key in the key chain, this is only available on authentication derivation paths
@property (nonatomic, readonly, nullable) NSString * walletBasedExtendedPrivateKeyLocationString;

// current derivation path balance excluding transactions known to be invalid
@property (nonatomic, assign) uint64_t balance;

// purpose of the derivation path if BIP 43 based
@property (nonatomic, readonly) NSUInteger purpose;

// currently the derivationPath is synced to this block height
@property (nonatomic, assign) uint32_t syncBlockHeight;

// all previously generated addresses
@property (nonatomic, readonly) NSSet * allAddresses;

// all previously used addresses
@property (nonatomic, readonly) NSSet * usedAddresses;


// the reference of type of derivation path
@property (nonatomic, readonly) DSDerivationPathReference reference;

// the reference of type of derivation path
@property (nonatomic, readonly) NSString * referenceName;

// there might be times where the derivationPath is actually unknown, for example when importing from an extended public key
@property (nonatomic, readonly) BOOL derivationPathIsKnown;

+ (instancetype)masterBlockchainIdentityContactsDerivationPathForAccountNumber:(uint32_t)accountNumber onChain:(DSChain*)chain;

+ (instancetype _Nullable)derivationPathWithIndexes:(const UInt256[_Nullable])indexes hardened:(const BOOL[_Nullable])hardenedIndexes length:(NSUInteger)length type:(DSDerivationPathType)type signingAlgorithm:(DSKeyType)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain*)chain;

+ (instancetype _Nullable)derivationPathWithSerializedExtendedPrivateKey:(NSString*)serializedExtendedPrivateKey fundsType:(DSDerivationPathType)fundsType signingAlgorithm:(DSKeyType)signingAlgorithm onChain:(DSChain*)chain;

+ (instancetype _Nullable)derivationPathWithSerializedExtendedPublicKey:(NSString*)serializedExtendedPublicKey onChain:(DSChain*)chain;

- (instancetype _Nullable)initWithExtendedPublicKeyIdentifier:(NSString*)extendedPublicKeyIdentifier onChain:(DSChain*)chain;

- (instancetype _Nullable)initWithIndexes:(const UInt256[_Nullable])indexes hardened:(const BOOL[_Nullable])hardenedIndexes length:(NSUInteger)length type:(DSDerivationPathType)type signingAlgorithm:(DSKeyType)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain*)chain;

-(BOOL)isBIP32Only;
-(BOOL)isBIP43Based;

-(NSIndexPath*)baseIndexPath;

// set the account, can not be later changed
- (void)setAccount:(DSAccount *)account;

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString *)address;

// true if the address was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsed:(NSString *)address;

// true if the address at index path was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsedAtIndexPath:(NSIndexPath *)indexPath;

// inform the derivation path that the address has been used by a transaction, true if the derivation path contains the address
- (BOOL)registerTransactionAddress:(NSString *)address;

// gets an address at an index path
- (NSString *)addressAtIndexPath:(NSIndexPath *)indexPath;

// gets a private key at an index path
- (DSKey * _Nullable)privateKeyAtIndexPath:(NSIndexPath*)indexPath fromSeed:(NSData *)seed;

- (DSKey * _Nullable)privateKeyForKnownAddress:(NSString*)address fromSeed:(NSData *)seed;

- (DSKey * _Nullable)deprecatedIncorrectExtendedPublicKeyFromSeed:(NSData * _Nullable)seed;

//you can set wallet unique Id to nil if you don't wish to store the extended Public Key
- (DSKey * _Nullable)generateExtendedPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString* _Nullable)walletUniqueId;

//addition option to store the private key, this should generally not be used unless the key is meant to be used without authentication
- (DSKey * _Nullable)generateExtendedPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString* _Nullable)walletUniqueId storePrivateKey:(BOOL)storePrivateKey;

//you can set wallet unique Id to nil if you don't wish to store the extended Public Key
- (DSKey * _Nullable)generateExtendedPublicKeyFromParentDerivationPath:(DSDerivationPath*)parentDerivationPath storeUnderWalletUniqueId:(NSString* _Nullable)walletUniqueId;

//sometimes we need to store the public key but not at generation time, use this method for that
- (BOOL)storeExtendedPublicKeyUnderWalletUniqueId:(NSString* _Nonnull)walletUniqueId;

- (NSString * _Nullable)serializedExtendedPublicKey;

- (NSString * _Nullable)serializedExtendedPrivateKeyFromSeed:(NSData * _Nullable)seed;
+ (NSData * _Nullable)deserializedExtendedPrivateKey:(NSString *)extendedPrivateKeyString onChain:(DSChain*)chain;

+ (NSData *)deserializedExtendedPublicKey:(NSString *)extendedPublicKeyString onChain:(DSChain*)chain;
- (NSData * _Nullable)deserializedExtendedPublicKey:(NSString *)extendedPublicKeyString;

- (DSKey* _Nullable)publicKeyAtIndexPath:(NSIndexPath*)indexPath;

- (NSData * _Nullable)publicKeyDataAtIndexPath:(NSIndexPath*)indexPath;

- (NSArray * _Nullable)privateKeysAtIndexPaths:(NSArray*)indexPaths fromSeed:(NSData *)seed;

- (NSArray * _Nullable)serializedPrivateKeysAtIndexPaths:(NSArray*)indexPaths fromSeed:(NSData *)seed;

//this loads the derivation path once it is set to an account that has a wallet;
-(void)loadAddresses;

-(void)reloadAddresses;

-(BOOL)isHardenedAtPosition:(NSUInteger)position;

-(BOOL)isDerivationPathEqual:(id)object;

@end

NS_ASSUME_NONNULL_END
