//  
//  Created by Sam Westrich
//  Copyright © 2019 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSCreditFundingDerivationPath.h"
#import "DSDerivationPath+Protected.h"
#import "DSDerivationPathFactory.h"
#import "DSSimpleIndexedDerivationPath+Protected.h"
#import "DSMasternodeManager.h"
#import "DSWallet+Protected.h"

@implementation DSCreditFundingDerivationPath

+ (instancetype)blockchainIdentityRegistrationFundingDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] blockchainIdentityRegistrationFundingDerivationPathForWallet:wallet];
}
+ (instancetype)blockchainIdentityTopupFundingDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] blockchainIdentityTopupFundingDerivationPathForWallet:wallet];
}

+ (instancetype)blockchainIdentityRegistrationFundingDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(12)};
    BOOL hardenedIndexes[] = {YES,YES,YES};
    return [DSCreditFundingDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:3 type:DSDerivationPathType_CreditFunding signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_BlockchainIdentityCreditRegistrationFunding onChain:chain];
}

+ (instancetype)blockchainIdentityTopupFundingDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(13)};
    BOOL hardenedIndexes[] = {YES,YES,YES};
    return [DSCreditFundingDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:3 type:DSDerivationPathType_CreditFunding signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_BlockchainIdentityCreditRegistrationFunding onChain:chain];
}

-(NSString*)receiveAddress {
    NSString *addr = [self registerAddressesWithGapLimit:1 error:nil].lastObject;
    return (addr) ? addr : self.mOrderedAddresses.lastObject;
}

-(NSUInteger)defaultGapLimit {
    return 5;
}

// sign any inputs in the given transaction that can be signed using private keys from the wallet
- (void)signTransaction:(DSTransaction *)transaction withPrompt:(NSString *)authprompt completion:(TransactionValidityCompletionBlock)completion;
{
    if ([transaction inputAddresses].count != 1) {
        completion(NO,NO);
        return;
    }
    
    NSUInteger index = [self indexOfKnownAddress:[[transaction inputAddresses] firstObject]];
    
    @autoreleasepool { // @autoreleasepool ensures sensitive data will be dealocated immediately
        self.wallet.seedRequestBlock(authprompt, MASTERNODE_COST,^void (NSData * _Nullable seed, BOOL cancelled) {
            if (! seed) {
                if (completion) completion(NO,cancelled);
            } else {
                DSECDSAKey * key = (DSECDSAKey *)[self privateKeyAtIndex:(uint32_t)index fromSeed:seed];
                
                BOOL signedSuccessfully = [transaction signWithPrivateKeys:@[key]];
                if (completion) completion(signedSuccessfully,NO);
            }
        });
    }
}

@end
