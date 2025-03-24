//  
//  Created by Vladimir Pirogov
//  Copyright © 2025 Dash Core Group. All rights reserved.
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

#import "DSAccount.h"
#import "DSChain+Params.h"
#import "DSWallet+Protected.h"
#import "DSWallet+Tests.h"
#import "NSDate+Utils.h"
#import <objc/runtime.h>

//this is for testing purposes only
NSString const *transientDerivedKeyDataKey = @"transientDerivedKeyDataKey";

@implementation DSWallet (Tests)

- (NSData *)transientDerivedKeyData {
    return objc_getAssociatedObject(self, &transientDerivedKeyDataKey);
}

- (void)setTransientDerivedKeyData:(NSData *)transientDerivedKeyData {
    objc_setAssociatedObject(self, &transientDerivedKeyDataKey, transientDerivedKeyData, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (DSWallet *)transientWalletWithDerivedKeyData:(NSData *)derivedData forChain:(DSChain *)chain {
    NSParameterAssert(derivedData);
    NSParameterAssert(chain);

    DSAccount *account = [DSAccount accountWithAccountNumber:0 withDerivationPaths:[chain standardDerivationPathsForAccountNumber:0] inContext:chain.chainManagedObjectContext];


    NSString *uniqueId = [self setTransientDerivedKeyData:derivedData withAccounts:@[account] forChain:chain]; //make sure we can create the wallet first
    if (!uniqueId) return nil;
    //[self registerSpecializedDerivationPathsForSeedPhrase:seedPhrase underUniqueId:uniqueId onChain:chain];
    DSWallet *wallet = [[DSWallet alloc] initWithUniqueID:uniqueId andAccounts:@[account] forChain:chain storeSeedPhrase:NO isTransient:YES];

    wallet.transientDerivedKeyData = derivedData;

    return wallet;
}

+ (DSWallet *)standardWalletWithRandomSeedPhraseForChain:(DSChain *)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    NSParameterAssert(chain);

    return [self standardWalletWithRandomSeedPhraseInLanguage:DSBIP39Language_Default forChain:chain storeSeedPhrase:store isTransient:isTransient];
}

+ (DSWallet *)standardWalletWithRandomSeedPhraseInLanguage:(DSBIP39Language)language forChain:(DSChain *)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    NSParameterAssert(chain);

    return [self standardWalletWithSeedPhrase:[self generateRandomSeedPhraseForLanguage:language] setCreationDate:[NSDate timeIntervalSince1970] forChain:chain storeSeedPhrase:store isTransient:isTransient];
}

+ (NSString *)setTransientDerivedKeyData:(NSData *)derivedKeyData withAccounts:(NSArray *)accounts forChain:(DSChain *)chain {
    if (!derivedKeyData) return nil;
    NSString *uniqueID = nil;
    @autoreleasepool { // @autoreleasepool ensures sensitive data will be deallocated immediately
        // we store the wallet creation time on the keychain because keychain data persists even when an app is deleted
        Slice_u8 *derived_key_data = slice_ctor(derivedKeyData);
        uint64_t unique_id = DECDSAPublicKeyUniqueIdFromDerivedKeyData(derived_key_data, chain.chainType);
        uniqueID = [NSString stringWithFormat:@"%0llx", unique_id];
        for (DSAccount *account in accounts) {
            for (DSDerivationPath *derivationPath in account.fundDerivationPaths) {
                [derivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:nil];
            }
            if ([chain isEvolutionEnabled]) {
                [account.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:nil];
            }
        }
    }
    return uniqueID;
}


@end
