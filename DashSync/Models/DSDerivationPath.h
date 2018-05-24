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


typedef void (^TransactionValidityCompletionBlock)(BOOL signedTransaction);

#define BIP32_HARD 0x80000000

@class DSTransaction;
@class DSAccount;
@class DSDerivationPath;

typedef NS_ENUM(NSUInteger, DSDerivationPathFundsType) {
    DSDerivationPathFundsType_Clear,
    DSDerivationPathFundsType_Anonymous
};

@interface DSDerivationPath : NSIndexPath

//is this an open account
@property (nonatomic,assign,readonly) DSDerivationPathFundsType type;

// master public key
@property (nonatomic, readonly) NSDictionary * extendedPublicKeys;//master public key used to generate wallet addresses

// account for the account
@property (nonatomic, readonly, weak) DSAccount * account;
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

+ (instancetype _Nonnull)bip32DerivationPathForAccountNumber:(uint32_t)accountNumber;

+ (instancetype _Nonnull)bip44DerivationPathForChainType:(DSChainType)chain forAccountNumber:(uint32_t)accountNumber;

+ (instancetype _Nullable)derivationPathWithIndexes:(NSUInteger *)indexes length:(NSUInteger)length
                                               type:(DSDerivationPathFundsType)type;

- (instancetype _Nullable)initWithIndexes:(NSUInteger *)indexes length:(NSUInteger)length
                                     type:(DSDerivationPathFundsType)type;

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
- (NSData * _Nullable)extendedPublicKeyFromSeed:(NSData * _Nonnull)seed;
- (NSData * _Nullable)generatePublicKeyAtIndex:(uint32_t)n internal:(BOOL)internal;
- (NSString * _Nullable)privateKey:(uint32_t)n internal:(BOOL)internal fromSeed:(NSData * _Nonnull)seed;
- (NSArray * _Nullable)privateKeys:(NSArray * _Nonnull)n internal:(BOOL)internal fromSeed:(NSData * _Nonnull)seed;

// key used for authenticated API calls, i.e. bitauth: https://github.com/bitpay/bitauth
+ (NSString * _Nullable)authPrivateKeyFromSeed:(NSData * _Nullable)seed;

// key used for BitID: https://github.com/bitid/bitid/blob/master/BIP_draft.md
+ (NSString * _Nullable)bitIdPrivateKey:(uint32_t)n forURI:(NSString * _Nonnull)uri fromSeed:(NSData * _Nonnull)seed;

- (NSString * _Nullable)serializedPrivateMasterFromSeed:(NSData * _Nullable)seed;
- (NSString * _Nullable)serializedMasterPublicKey:(NSData * _Nonnull)masterPublicKey depth:(NSUInteger)depth;
- (NSData * _Nullable)deserializedMasterPublicKey:(NSString * _Nonnull)masterPublicKeyString;


@end
