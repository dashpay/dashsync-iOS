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

#import "DSTransitionFactory.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBlockchainIdentityTopupTransition.h"
#import "DSBlockchainIdentityResetTransition.h"
#import "DSBlockchainIdentityCloseTransition.h"
#import "DSTransition.h"
#import "NSData+Dash.h"
#import "NSData+Bitcoin.h"

@implementation DSTransitionFactory

+(DSTransitionType)transitionTypeOfMessage:(NSData*)message {
    uint16_t version = [message UInt16AtOffset:0];
    if (version < 3) return DSTransitionType_Classic;
    return [message UInt16AtOffset:2];
}

+(DSTransition*)transitionWithMessage:(NSData*)message onChain:(DSChain*)chain {
    uint16_t version = [message UInt16AtOffset:0];
    if (version < 3) return [DSTransition transitionWithMessage:message onChain:chain]; //no special transitions yet
    uint16_t type = [message UInt16AtOffset:2];
    switch (type) {
        case DSTransitionType_Classic:
            return [DSTransition transitionWithMessage:message onChain:chain];
        case DSTransitionType_Coinbase:
            return [DSCoinbaseTransition transitionWithMessage:message onChain:chain];
        case DSTransitionType_SubscriptionRegistration:
            return [DSBlockchainIdentityRegistrationTransition transitionWithMessage:message onChain:chain];
        case DSTransitionType_SubscriptionTopUp:
            return [DSBlockchainIdentityTopupTransition transitionWithMessage:message onChain:chain];
        case DSTransitionType_SubscriptionCloseAccount:
            return [DSBlockchainIdentityCloseTransition transitionWithMessage:message onChain:chain];
        case DSTransitionType_SubscriptionResetKey:
            return [DSBlockchainIdentityResetTransition transitionWithMessage:message onChain:chain];
        default:
            return [DSTransition transitionWithMessage:message onChain:chain]; //we won't be able to check the payload, but try best to support it.
    }
}

+(BOOL)ignoreMessagesOfTransitionType:(DSTransitionType)transitionType {
    switch (transitionType) {
        case DSTransitionType_Classic:
            return FALSE;
        case DSTransitionType_SubscriptionRegistration:
            return FALSE;
        case DSTransitionType_SubscriptionTopUp:
            return FALSE;
        case DSTransitionType_SubscriptionCloseAccount:
            return FALSE;
        case DSTransitionType_SubscriptionResetKey:
            return FALSE;
        default:
            return TRUE;
    }
}

+(BOOL)shouldIgnoreTransitionMessage:(NSData*)message {
    return [self ignoreMessagesOfTransitionType:[self transitionTypeOfMessage:message]];
}

@end
