//
//  Created by Andrew Podkovyrin
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

#import "DSParseLocalBitcoinsResponseOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSParseLocalBitcoinsResponseOperation ()

@property (strong, nonatomic, nullable) NSNumber *vesPrice;

@end

@implementation DSParseLocalBitcoinsResponseOperation

- (void)execute {
    NSParameterAssert(self.httpOperationResult.parsedResponse);

    NSDictionary *response = (NSDictionary *)self.httpOperationResult.parsedResponse;
    if (![response isKindOfClass:NSDictionary.class]) {
        [self cancelWithError:[self.class invalidResponseErrorWithUserInfo:@{NSDebugDescriptionErrorKey : response}]];

        return;
    }

    NSDictionary *exchangeData = response[@"VES"];
    if (![exchangeData isKindOfClass:NSDictionary.class]) {
        [self cancelWithError:[self.class invalidResponseErrorWithUserInfo:@{NSDebugDescriptionErrorKey : response}]];

        return;
    }

    NSNumber *vesPrice = nil;
    if (exchangeData[@"avg_1h"]) {
        vesPrice = exchangeData[@"avg_1h"];
    }
    else if (exchangeData[@"avg_6h"]) {
        vesPrice = exchangeData[@"avg_6h"];
    }
    else if (exchangeData[@"avg_12h"]) {
        vesPrice = exchangeData[@"avg_12h"];
    }
    else if (exchangeData[@"avg_24h"]) {
        vesPrice = exchangeData[@"avg_24h"];
    }
    self.vesPrice = vesPrice;

    [self finish];
}

@end

NS_ASSUME_NONNULL_END
