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

#import "DSHTTPSparkOperation.h"

#import "DSCurrencyPriceObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSHTTPSparkOperation ()

@property (copy, nonatomic, nullable) NSArray<DSCurrencyPriceObject *> *prices;

@end

@implementation DSHTTPSparkOperation

- (void)processSuccessResponse:(id)parsedData responseHeaders:(NSDictionary *)responseHeaders statusCode:(NSInteger)statusCode {
    NSParameterAssert(parsedData);

    NSDictionary *response = (NSDictionary *)parsedData;
    if (![response isKindOfClass:NSDictionary.class]) {
        [self cancelWithInvalidResponse:response];

        return;
    }

    BOOL responseIsValid = YES;
    for (id key in response) {
        id value = response[key];

        responseIsValid = [key isKindOfClass:NSString.class] && [value isKindOfClass:NSNumber.class];
        if (!responseIsValid) {
            break;
        }
    }

    if (!responseIsValid) {
        [self cancelWithInvalidResponse:response];

        return;
    }

    NSMutableArray<DSCurrencyPriceObject *> *prices = [NSMutableArray array];
    for (NSString *code in response) {
        NSNumber *price = response[code];
        DSCurrencyPriceObject *priceObject = [[DSCurrencyPriceObject alloc] initWithCode:code price:price];
        if (priceObject) {
            [prices addObject:priceObject];
        }
    }

    self.prices = prices;

    [self finish];
}

@end

NS_ASSUME_NONNULL_END
