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

#import "DSChain+Params.h"
#import "DSAssetLockDerivationPath.h"
#import "DSDerivationPath+Protected.h"
#import "DSDerivationPathFactory.h"
#import "DSMasternodeManager.h"
#import "DSSimpleIndexedDerivationPath+Protected.h"
#import "DSWallet+Protected.h"

@implementation DSAssetLockDerivationPath

+ (instancetype)identityRegistrationFundingDerivationPathForWallet:(DSWallet *)wallet {
    return [[DSDerivationPathFactory sharedInstance] identityRegistrationFundingDerivationPathForWallet:wallet];
}

+ (instancetype)identityTopupFundingDerivationPathForWallet:(DSWallet *)wallet {
    return [[DSDerivationPathFactory sharedInstance] identityTopupFundingDerivationPathForWallet:wallet];
}

+ (instancetype)identityInvitationFundingDerivationPathForWallet:(DSWallet *)wallet {
    return [[DSDerivationPathFactory sharedInstance] identityInvitationFundingDerivationPathForWallet:wallet];
}

+ (instancetype)identityRegistrationFundingDerivationPathForChain:(DSChain *)chain {
    UInt256 indexes[] = {
        uint256_from_long(FEATURE_PURPOSE),
        uint256_from_long(chain.coinType),
        uint256_from_long(FEATURE_PURPOSE_IDENTITIES),
        uint256_from_long(FEATURE_PURPOSE_IDENTITIES_SUBFEATURE_REGISTRATION)
    };
    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
    return [DSAssetLockDerivationPath derivationPathWithIndexes:indexes
                                                           hardened:hardenedIndexes
                                                             length:4
                                                               type:DSDerivationPathType_CreditFunding
                                                   signingAlgorithm:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor()
                                                          reference:DSDerivationPathReference_IdentityCreditRegistrationFunding
                                                            onChain:chain];
}

+ (instancetype)identityTopupFundingDerivationPathForChain:(DSChain *)chain {
    UInt256 indexes[] = {
        uint256_from_long(FEATURE_PURPOSE),
        uint256_from_long(chain.coinType),
        uint256_from_long(FEATURE_PURPOSE_IDENTITIES),
        uint256_from_long(FEATURE_PURPOSE_IDENTITIES_SUBFEATURE_TOPUP)
    };
    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
    return [DSAssetLockDerivationPath derivationPathWithIndexes:indexes
                                                           hardened:hardenedIndexes
                                                             length:4
                                                               type:DSDerivationPathType_CreditFunding
                                                   signingAlgorithm:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor()
                                                          reference:DSDerivationPathReference_IdentityCreditTopupFunding
                                                            onChain:chain];
}

+ (instancetype)identityInvitationFundingDerivationPathForChain:(DSChain *)chain {
    UInt256 indexes[] = {
        uint256_from_long(FEATURE_PURPOSE),
        uint256_from_long(chain.coinType),
        uint256_from_long(FEATURE_PURPOSE_IDENTITIES),
        uint256_from_long(FEATURE_PURPOSE_IDENTITIES_SUBFEATURE_INVITATIONS)
    };
    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
    return [DSAssetLockDerivationPath derivationPathWithIndexes:indexes
                                                           hardened:hardenedIndexes
                                                             length:4
                                                               type:DSDerivationPathType_CreditFunding
                                                   signingAlgorithm:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor()
                                                          reference:DSDerivationPathReference_IdentityCreditInvitationFunding
                                                            onChain:chain];
}

- (NSString *)receiveAddress {
    NSString *addr = [self registerAddressesWithGapLimit:1 error:nil].lastObject;
    return addr ? addr : self.mOrderedAddresses.lastObject;
}

- (NSUInteger)defaultGapLimit {
    return 5;
}

@end
