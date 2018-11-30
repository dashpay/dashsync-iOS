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

#import "DSParseSparkResponseOperation.h"

#import "DSCurrencyPriceObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSParseSparkResponseOperation ()

@property (copy, nonatomic, nullable) NSArray<DSCurrencyPriceObject *> *prices;

@end

@implementation DSParseSparkResponseOperation

- (void)execute {
    NSParameterAssert(self.responseToParse);

    NSDictionary *response = (NSDictionary *)self.responseToParse;
    if (![response isKindOfClass:NSDictionary.class]) {
        [self cancelWithError:[self.class invalidResponseErrorWithUserInfo:@{NSDebugDescriptionErrorKey : response}]];

        return;
    }

    if (![response.allKeys.firstObject isKindOfClass:NSString.class] ||
        ![response.allValues.firstObject isKindOfClass:NSNumber.class]) {

        [self cancelWithError:[self.class invalidResponseErrorWithUserInfo:@{NSDebugDescriptionErrorKey : response}]];

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
