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
#import "DSMasternodeManager.h"
#import "DSSimpleIndexedDerivationPath+Protected.h"
#import "DSWallet+Protected.h"

@implementation DSCreditFundingDerivationPath

+ (instancetype)blockchainIdentityRegistrationFundingDerivationPathForWallet:(DSWallet *)wallet {
    return [[DSDerivationPathFactory sharedInstance] blockchainIdentityRegistrationFundingDerivationPathForWallet:wallet];
}

+ (instancetype)blockchainIdentityTopupFundingDerivationPathForWallet:(DSWallet *)wallet {
    return [[DSDerivationPathFactory sharedInstance] blockchainIdentityTopupFundingDerivationPathForWallet:wallet];
}

+ (instancetype)blockchainIdentityInvitationFundingDerivationPathForWallet:(DSWallet *)wallet {
    return [[DSDerivationPathFactory sharedInstance] blockchainIdentityInvitationFundingDerivationPathForWallet:wallet];
}

+ (instancetype)blockchainIdentityRegistrationFundingDerivationPathForChain:(DSChain *)chain {
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(chain_coin_type(chain.chainType)), uint256_from_long(FEATURE_PURPOSE_IDENTITIES), uint256_from_long(FEATURE_PURPOSE_IDENTITIES_SUBFEATURE_REGISTRATION)};
    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
    return [DSCreditFundingDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_CreditFunding signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_BlockchainIdentityCreditRegistrationFunding onChain:chain];
}

+ (instancetype)blockchainIdentityTopupFundingDerivationPathForChain:(DSChain *)chain {
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(chain_coin_type(chain.chainType)), uint256_from_long(FEATURE_PURPOSE_IDENTITIES), uint256_from_long(FEATURE_PURPOSE_IDENTITIES_SUBFEATURE_TOPUP)};
    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
    return [DSCreditFundingDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_CreditFunding signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_BlockchainIdentityCreditTopupFunding onChain:chain];
}

+ (instancetype)blockchainIdentityInvitationFundingDerivationPathForChain:(DSChain *)chain {
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(chain_coin_type(chain.chainType)), uint256_from_long(FEATURE_PURPOSE_IDENTITIES), uint256_from_long(FEATURE_PURPOSE_IDENTITIES_SUBFEATURE_INVITATIONS)};
    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
    return [DSCreditFundingDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_CreditFunding signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_BlockchainIdentityCreditInvitationFunding onChain:chain];
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
                NSValue *val = [NSValue valueWithPointer:key];
                BOOL signedSuccessfully = [transaction signWithPrivateKeys:@[val]];
                processor_destroy_opaque_key(key);
                if (completion) completion(signedSuccessfully, NO);
            }
        });
    }
}

@end
