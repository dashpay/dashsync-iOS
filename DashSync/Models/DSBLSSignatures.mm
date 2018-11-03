//
//  DSBLSSignatures.m
//  DashSync
//
//  Created by Andrew Podkovyrin on 02/11/2018.
//

#import "DSBLSSignatures.h"
#import "DSDerivationPath.h"
#import "NSIndexPath+Dash.h"

#include <bls-signatures-pod/bls.hpp>

NS_ASSUME_NONNULL_BEGIN

@implementation DSBLSSignatures

//A little recursive magic since extended private keys can't be re-assigned in the library
+(bls::ExtendedPrivateKey)derive:(bls::ExtendedPrivateKey)extendedPrivateKey indexes:(NSIndexPath*)indexPath {
    if (!indexPath.length) return extendedPrivateKey;
    uint32_t topIndexPath = (uint32_t)[indexPath indexAtPosition:0];
    bls::ExtendedPrivateKey skChild = extendedPrivateKey.PrivateChild(topIndexPath);
    return [self derive:skChild indexes:[indexPath indexPathByRemovingFirstIndex]];
}

+(UInt256)privateKeyDerivedFromSeed:(UInt512)seed toPath:(DSDerivationPath*)derivationPath {

    bls::ExtendedPrivateKey esk = bls::ExtendedPrivateKey::FromSeed(seed.u8, sizeof(seed.u8));

    bls::ExtendedPrivateKey skChild = [self derive:esk indexes:derivationPath];
    UInt256 privateKey;
    skChild.GetPrivateKey().Serialize(privateKey.u8);
    return privateKey;
}

+ (void)testSomeBLSSignaturesMethods {
    uint8_t seed[] = {0, 50, 6, 244, 24, 199, 1, 25, 52, 88, 192,
        19, 18, 12, 89, 6, 220, 18, 102, 58, 209,
        82, 12, 62, 89, 110, 182, 9, 44, 20, 254, 22};
    
    bls::PrivateKey sk = bls::PrivateKey::FromSeed(seed, sizeof(seed));
    __unused bls::PublicKey pk = sk.GetPublicKey();
    
    uint8_t msg[] = {100, 2, 254, 88, 90, 45, 23};
    
    __unused bls::Signature sig = sk.Sign(msg, sizeof(msg));
}

@end

NS_ASSUME_NONNULL_END
