//
//  Created by Andrew Podkovyrin
//  Copyright © 2018 Dash Core Group. All rights reserved.
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

#import "DSHTTPDashCentralOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSHTTPDashCentralOperation ()

@property (strong, nonatomic, nullable) NSNumber *btcDashPrice;

@end

@implementation DSHTTPDashCentralOperation

- (void)processSuccessResponse:(id)parsedData responseHeaders:(NSDictionary *)responseHeaders statusCode:(NSInteger)statusCode {
    NSParameterAssert(parsedData);

    NSDictionary *response = (NSDictionary *)parsedData;
    if (![response isKindOfClass:NSDictionary.class]) {
        [self cancelWithInvalidResponse:response];

        return;
    }

    NSNumber *btcDashPrice = response[@"exchange_rates"][@"btc_dash"];
    if (btcDashPrice.doubleValue > 0.0) {
        self.btcDashPrice = btcDashPrice;

        [self finish];
    }
    else {
        [self cancelWithInvalidResponse:response];
    }
}

@end

NS_ASSUME_NONNULL_END
