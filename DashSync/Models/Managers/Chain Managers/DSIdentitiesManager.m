//  
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

#import "DSIdentitiesManager.h"
#import "DSChain.h"
#import "DSWallet.h"

@interface DSIdentitiesManager()

@property (nonatomic, strong) DSChain * chain;

@end

@implementation DSIdentitiesManager

- (instancetype)initWithChain:(DSChain*)chain
{
    NSParameterAssert(chain);
    
    if (! (self = [super init])) return nil;
    
    self.chain = chain;
    
    return self;
}

// MARK: - Identities

-(void)retrieveAllBlockchainIdentitiesChainStates {
    for (DSWallet * wallet in self.chain.wallets) {
        [self retrieveAllBlockchainIdentitiesChainStatesForWallet:wallet];
    }
}

-(void)retrieveAllBlockchainIdentitiesChainStatesForWallet:(DSWallet*)wallet {
    for (DSBlockchainIdentity * identity in [wallet.blockchainIdentities allValues]) {
        if (identity.registrationStatus == DSBlockchainIdentityRegistrationStatus_Unknown) {
            [identity retrieveIdentityNetworkStateInformationWithCompletion:^(BOOL success) {
                if (success) {
                    //now lets get dpns info
                    [identity fetchUsernamesWithCompletion:^(BOOL success) {
                        
                    }];
                }
            }];
        } else if (identity.registrationStatus == DSBlockchainIdentityRegistrationStatus_Registered) {
            if (!identity.currentUsername) {
                [identity fetchUsernamesWithCompletion:^(BOOL success) {
                    
                }];
            }
        }
    }
}

@end
