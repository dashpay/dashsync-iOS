//
//  DSMasternodeHoldingsDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSDerivationPath+Protected.h"
#import "DSDerivationPathFactory.h"
#import "DSMasternodeManager.h"
#import "DSSimpleIndexedDerivationPath+Protected.h"
#import "DSWallet+Protected.h"

@interface DSMasternodeHoldingsDerivationPath ()

@end

@implementation DSMasternodeHoldingsDerivationPath

+ (instancetype _Nonnull)providerFundsDerivationPathForWallet:(DSWallet *)wallet {
    return [[DSDerivationPathFactory sharedInstance] providerFundsDerivationPathForWallet:wallet];
}

+ (instancetype _Nonnull)providerFundsDerivationPathForChain:(DSChain *)chain {
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long((uint64_t) chain_coin_type(chain.chainType)), uint256_from_long(3), uint256_from_long(0)};
    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
    return [self derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_ProtectedFunds signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_ProviderFunds onChain:chain];
}

- (NSString *)receiveAddress {
    NSString *addr = [self registerAddressesWithGapLimit:1 error:nil].lastObject;
    return (addr) ? addr : self.mOrderedAddresses.lastObject;
}

- (NSUInteger)defaultGapLimit {
    return 5;
}

// sign any inputs in the given transaction that can be signed using private keys from the wallet
- (void)signTransaction:(DSTransaction *)transaction withPrompt:(NSString *)authprompt completion:(TransactionValidityCompletionBlock)completion;
{
    if ([transaction inputAddresses].count != 1) {
        completion(NO, NO);
        return;
    }

    NSUInteger index = [self indexOfKnownAddress:[[transaction inputAddresses] firstObject]];

    @autoreleasepool { // @autoreleasepool ensures sensitive data will be dealocated immediately
        self.wallet.secureSeedRequestBlock(authprompt, MASTERNODE_COST, ^void(NSData *_Nullable seed, BOOL cancelled) {
            if (!seed) {
                if (completion) completion(NO, cancelled);
            } else {
                OpaqueKey *key = [self privateKeyAtIndex:(uint32_t)index fromSeed:seed];
                BOOL signedSuccessfully = [transaction signWithPrivateKeys:@[[NSValue valueWithPointer:key]]];
                if (completion) completion(signedSuccessfully, NO);
            }
        });
    }
}

@end
