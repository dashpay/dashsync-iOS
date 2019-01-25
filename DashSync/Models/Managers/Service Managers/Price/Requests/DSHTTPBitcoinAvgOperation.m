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

#import "DSHTTPBitcoinAvgOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSHTTPBitcoinAvgOperation ()

@property (strong, nonatomic, nullable) NSDictionary<NSString *, NSNumber *> *pricesByCode;

@end

@implementation DSHTTPBitcoinAvgOperation

- (void)processSuccessResponse:(id)parsedData responseHeaders:(NSDictionary *)responseHeaders statusCode:(NSInteger)statusCode {
    NSParameterAssert(parsedData);

    NSDictionary *response = (NSDictionary *)parsedData;
    if (![response isKindOfClass:NSDictionary.class]) {
        [self cancelWithInvalidResponse:response];

        return;
    }

    NSMutableDictionary<NSString *, NSNumber *> *pricesByCode = [NSMutableDictionary dictionary];

    for (NSString *btcFiatCode in response) {
        if (btcFiatCode.length > 3) {
            NSString *code = [btcFiatCode substringFromIndex:3];
            NSDictionary *value = response[btcFiatCode];
            NSNumber *price = value[@"last"];

            if (code.length > 0 && [price isKindOfClass:NSNumber.class]) {
                pricesByCode[code] = price;
            }
        }
    }

    if (pricesByCode.count == 0) {
        [self cancelWithInvalidResponse:response];

        return;
    }

    self.pricesByCode = pricesByCode;

    [self finish];
}

@end

NS_ASSUME_NONNULL_END
