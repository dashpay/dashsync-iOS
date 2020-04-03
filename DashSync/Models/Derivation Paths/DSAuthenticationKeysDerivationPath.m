//
//  DSAuthenticationKeysDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSAuthenticationKeysDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSSimpleIndexedDerivationPath+Protected.h"
#import "DSCreditFundingDerivationPath.h"

@interface DSAuthenticationKeysDerivationPath()

@property (nonatomic, assign) BOOL shouldStoreExtendedPrivateKey;

@end

@implementation DSAuthenticationKeysDerivationPath

+ (instancetype)providerVotingKeysDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:wallet];
}
+ (instancetype)providerOwnerKeysDerivationPathForWallet:(DSWallet*)wallet {
     return [[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:wallet];
}
+ (instancetype)providerOperatorKeysDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:wallet];
}
+ (instancetype)blockchainIdentitiesBLSKeysDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:wallet];
}
+ (instancetype)blockchainIdentitiesECDSAKeysDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] blockchainIdentityECDSAKeysDerivationPathForWallet:wallet];
}

-(NSUInteger)defaultGapLimit {
    return 10;
}

- (instancetype)initWithIndexes:(const UInt256[_Nullable])indexes hardened:(const BOOL[_Nullable])hardenedIndexes length:(NSUInteger)length
type:(DSDerivationPathType)type signingAlgorithm:(DSKeyType)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain*)chain {
    DSAuthenticationKeysDerivationPath * authenticationKeysDerivationPath = [super initWithIndexes:indexes hardened:hardenedIndexes length:length type:type signingAlgorithm:signingAlgorithm reference:reference onChain:chain];
    authenticationKeysDerivationPath.shouldStoreExtendedPrivateKey = NO;
    return authenticationKeysDerivationPath;
}

+ (instancetype _Nullable)derivationPathWithIndexes:(const UInt256[_Nullable])indexes hardened:(const BOOL[_Nullable])hardenedIndexes length:(NSUInteger)length
                                               type:(DSDerivationPathType)type signingAlgorithm:(DSKeyType)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain*)chain {
    DSAuthenticationKeysDerivationPath * derivationPath = [super derivationPathWithIndexes:indexes hardened:hardenedIndexes length:length type:type signingAlgorithm:signingAlgorithm reference:reference onChain:chain];
    derivationPath.shouldStoreExtendedPrivateKey = NO;
    return derivationPath;
}

+ (instancetype)providerVotingKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(3), uint256_from_long(1)};
    BOOL hardenedIndexes[] = {YES,YES,YES,YES};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_ProviderVotingKeys onChain:chain];
}

+ (instancetype)providerOwnerKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(3), uint256_from_long(2)};
    BOOL hardenedIndexes[] = {YES,YES,YES,YES};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_ProviderOwnerKeys onChain:chain];
}

+ (instancetype)providerOperatorKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(3), uint256_from_long(3)};
    BOOL hardenedIndexes[] = {YES,YES,YES,YES};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSKeyType_BLS reference:DSDerivationPathReference_ProviderOperatorKeys onChain:chain];
}

+ (instancetype)blockchainIdentityECDSAKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(5), uint256_from_long(0), uint256_from_long(0)};
    BOOL hardenedIndexes[] = {YES,YES,YES,YES,YES};
    DSAuthenticationKeysDerivationPath * blockchainIdentityECDSAKeysDerivationPath = [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:5 type:DSDerivationPathType_Authentication signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_BlockchainIdentities onChain:chain];
    blockchainIdentityECDSAKeysDerivationPath.shouldStoreExtendedPrivateKey = YES;
    return blockchainIdentityECDSAKeysDerivationPath;
}

+ (instancetype)blockchainIdentityBLSKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(5), uint256_from_long(0), uint256_from_long(1)};
    BOOL hardenedIndexes[] = {YES,YES,YES,YES,YES};
    DSAuthenticationKeysDerivationPath * blockchainIdentityBLSKeysDerivationPath = [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:5 type:DSDerivationPathType_Authentication signingAlgorithm:DSKeyType_BLS reference:DSDerivationPathReference_BlockchainIdentities onChain:chain];
    blockchainIdentityBLSKeysDerivationPath.shouldStoreExtendedPrivateKey = YES;
    return blockchainIdentityBLSKeysDerivationPath;
}

- (NSData*)firstUnusedPublicKey {
    return [self publicKeyDataAtIndex:(uint32_t)[self firstUnusedIndex]];
}

- (DSKey*)firstUnusedPrivateKeyFromSeed:(NSData*)seed {
    return [self privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:[self firstUnusedIndex]] fromSeed:seed];
}

- (DSKey*)privateKeyForAddress:(NSString*)address fromSeed:(NSData*)seed {
    NSUInteger index = [self indexOfKnownAddress:address];
    return [self privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:index] fromSeed:seed];
}

- (DSKey*)privateKeyForHash160:(UInt160)hash160 fromSeed:(NSData*)seed {
    NSString * address = [[NSData dataWithUInt160:hash160] addressFromHash160DataForChain:self.chain];
    return [self privateKeyForAddress:address fromSeed:seed];
}

- (NSData *)generateExtendedPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString*)walletUniqueId
{
    if (! seed) return nil;
    if (![self length]) return nil; //there needs to be at least 1 length
    if (self.signingAlgorithm == DSKeyType_ECDSA) {
        return [self generateExtendedECDSAPublicKeyFromSeed:seed storeUnderWalletUniqueId:walletUniqueId storePrivateKey:self.shouldStoreExtendedPrivateKey];
    } else if (self.signingAlgorithm == DSKeyType_BLS) {
        return [self generateExtendedBLSPublicKeyFromSeed:seed storeUnderWalletUniqueId:walletUniqueId storePrivateKey:self.shouldStoreExtendedPrivateKey];
    }
    return nil;
}

-(NSData*)extendedPrivateKey {
    NSError * error = nil;
    NSData * data = getKeychainData([self walletBasedExtendedPublicKeyLocationString], &error);
    return data;
}

- (DSKey * _Nullable)privateKeyAtIndexPath:(NSIndexPath*)indexPath {
    if (self.signingAlgorithm == DSKeyType_ECDSA) {
        
        UInt256 chain = [self.extendedPrivateKey UInt256AtOffset:4];
        UInt256 privKey = [self.extendedPrivateKey UInt256AtOffset:36];
        for (NSInteger i = 0;i<[indexPath length];i++) {
            uint32_t derivation = (uint32_t)[indexPath indexAtPosition:i];
            CKDpriv(&privKey, &chain, derivation);
        }
        return [DSECDSAKey keyWithSecret:privKey compressed:YES];;
    } else if (self.signingAlgorithm == DSKeyType_BLS) {
        DSBLSKey * extendedPrivateKey = [DSBLSKey blsKeyWithExtendedPrivateKeyData:self.extendedPrivateKey onChain:self.chain];
        DSBLSKey * extendedPrivateKeyAtIndexPath = [extendedPrivateKey deriveToPath:indexPath];
        return extendedPrivateKeyAtIndexPath;
    }
    return nil;
}

@end
