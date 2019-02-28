//
//  DSMasternodeHoldingsDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSDerivationPath+Protected.h"
#import "DSDerivationPathFactory.h"
#import "DSSimpleIndexedDerivationPath+Protected.h"
#import "DSMasternodeManager.h"

@interface DSMasternodeHoldingsDerivationPath()

@end

@implementation DSMasternodeHoldingsDerivationPath

+ (instancetype _Nonnull)providerFundsDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] providerFundsDerivationPathForWallet:wallet];
}

+ (instancetype _Nonnull)providerFundsDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {FEATURE_PURPOSE_HARDENED, coinType | BIP32_HARD, 3 | BIP32_HARD, 0 | BIP32_HARD};
    return [self derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_ProtectedFunds signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_ProviderFunds onChain:chain];
}

-(NSString*)receiveAddress {
    return [self addressAtIndex:[self unusedIndex]];
}

// sign any inputs in the given transaction that can be signed using private keys from the wallet
- (void)signTransaction:(DSTransaction *)transaction withPrompt:(NSString *)authprompt completion:(TransactionValidityCompletionBlock)completion;
{
    if ([transaction inputAddresses].count != 1) {
        completion(NO);
        return;
    }
    
    uint32_t index = (uint32_t)[self indexOfKnownAddress:[[transaction inputAddresses] firstObject]];
    
    @autoreleasepool { // @autoreleasepool ensures sensitive data will be dealocated immediately
        self.wallet.seedRequestBlock(authprompt, MASTERNODE_COST,^void (NSData * _Nullable seed, BOOL cancelled) {
            if (! seed) {
                if (completion) completion(YES);
            } else {
                DSECDSAKey * key = (DSECDSAKey *)[self privateKeyAtIndex:index fromSeed:seed];
                
                BOOL signedSuccessfully = [transaction signWithPrivateKeys:@[key]];
                if (completion) completion(signedSuccessfully);
            }
        });
    }
}

@end
