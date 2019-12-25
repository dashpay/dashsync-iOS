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

#import <Foundation/Foundation.h>
#import "DSTransition.h"

NS_ASSUME_NONNULL_BEGIN

//Special Transaction
//https://github.com/dashpay/dips/blob/master/dip-0002-special-transactions.md
typedef NS_ENUM(NSUInteger, DSTransitionType) {
    DSTransitionType_Classic = 12,
    DSTransitionType_SubscriptionRegistration = 8,
    DSTransitionType_SubscriptionTopUp = 9,
    DSTransitionType_SubscriptionResetKey = 10,
    DSTransitionType_SubscriptionCloseAccount = 11,
};

@interface DSTransitionFactory : NSObject

+(DSTransition*)transitionWithMessage:(NSData*)data onChain:(DSChain*)chain;

+(DSTransitionType)transitionTypeOfMessage:(NSData*)data;

+(BOOL)ignoreMessagesOfTransitionType:(DSTransitionType)transactionType;

+(BOOL)shouldIgnoreTransitionMessage:(NSData*)data;

@end

NS_ASSUME_NONNULL_END
