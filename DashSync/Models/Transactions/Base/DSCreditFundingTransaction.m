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

#import "DSCreditFundingTransaction.h"
#import "DSCreditFundingTransactionEntity+CoreDataClass.h"
#import "NSData+Bitcoin.h"
#import "DSDerivationPathFactory.h"
#import "DSWallet.h"
#import "DSAccount.h"
#import "DSCreditFundingDerivationPath.h"

@implementation DSCreditFundingTransaction

-(UInt256)creditBurnIdentityIdentifier {
    DSUTXO outpoint = [self lockedOutpoint];
    if (dsutxo_is_zero(outpoint)) return UINT256_ZERO;
    return [dsutxo_data(outpoint) SHA256_2];
}

-(DSUTXO)lockedOutpoint {
    for (int i = 0; i<self.outputScripts.count;i++) {
        NSData * script = self.outputScripts[i];
        if ([script UInt8AtOffset:0] == OP_RETURN && script.length == 22) {
            DSUTXO outpoint = { .hash = uint256_reverse(self.txHash), .n = i };
            return outpoint;
        }
    }
    return DSUTXO_ZERO;
}

-(UInt160)creditBurnPublicKeyHash {
    for (NSData * script in self.outputScripts) {
        if ([script UInt8AtOffset:0] == OP_RETURN && script.length == 22) {
            return [script subdataWithRange:NSMakeRange(2,20)].UInt160;
        }
    }
    return UINT160_ZERO;
}

-(uint32_t)usedDerivationPathIndexForWallet:(DSWallet*)wallet {
    DSCreditFundingDerivationPath * registrationFundingDerivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityRegistrationFundingDerivationPathForWallet:wallet];
    NSString * address = [[NSData dataWithUInt160:[self creditBurnPublicKeyHash]] addressFromHash160DataForChain:self.chain];
    return (uint32_t)[registrationFundingDerivationPath indexOfKnownAddress:address];
}

-(BOOL)checkDerivationPathIndexForWallet:(DSWallet*)wallet isIndex:(uint32_t)index {
    DSCreditFundingDerivationPath * registrationFundingDerivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityRegistrationFundingDerivationPathForWallet:wallet];
    NSString * address = [[NSData dataWithUInt160:[self creditBurnPublicKeyHash]] addressFromHash160DataForChain:self.chain];
    return [[registrationFundingDerivationPath addressAtIndex:index] isEqualToString:address];
}

-(void)markAddressAsUsedInWallet:(DSWallet*)wallet {
    DSCreditFundingDerivationPath * registrationFundingDerivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityRegistrationFundingDerivationPathForWallet:wallet];
    NSString * address = [[NSData dataWithUInt160:[self creditBurnPublicKeyHash]] addressFromHash160DataForChain:self.chain];
    [registrationFundingDerivationPath registerTransactionAddress:address];
    [registrationFundingDerivationPath registerAddressesWithGapLimit:10];
}

-(uint32_t)usedDerivationPathIndex {
    if (!self.accounts.count) return UINT32_MAX;
    if (self.accounts.count == 1) {
        return [self usedDerivationPathIndexForWallet:self.firstAccount.wallet];
    } else {
        NSMutableArray * wallets = [NSMutableArray array];
        for (DSAccount * account in self.accounts) {
            if (!account.wallet) continue;
            if (![wallets containsObject:account.wallet]) {
                [wallets addObject:account.wallet];
            }
        }
        for (DSWallet * wallet in wallets) {
            uint32_t derivation = [self usedDerivationPathIndexForWallet:wallet];
            if (derivation != UINT32_MAX) return derivation;
        }
        return UINT32_MAX;
    }
}

-(Class)entityClass {
    return [DSCreditFundingTransactionEntity class];
}

@end
