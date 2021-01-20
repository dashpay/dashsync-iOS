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

#import "DSHTTPDashRetailOperation.h"

#import "DSCurrencyPriceObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSHTTPDashRetailOperation ()

@property (copy, nonatomic, nullable) NSArray<DSCurrencyPriceObject *> *prices;

@end

@implementation DSHTTPDashRetailOperation

- (void)processSuccessResponse:(id)parsedData responseHeaders:(NSDictionary *)responseHeaders statusCode:(NSInteger)statusCode {
    NSParameterAssert(parsedData);

    NSArray *response = (NSArray *)parsedData;
    if (![response isKindOfClass:NSArray.class]) {
        [self cancelWithInvalidResponse:response];

        return;
    }

    BOOL responseIsValid = YES;
    for (id value in response) {
        responseIsValid = [value isKindOfClass:NSDictionary.class] &&
                          [value[@"price"] isKindOfClass:NSString.class] &&
                          [value[@"symbol"] isKindOfClass:NSString.class];
        if (!responseIsValid) {
            break;
        }
    }

    if (!responseIsValid) {
        [self cancelWithInvalidResponse:response];

        return;
    }

    NSMutableArray<DSCurrencyPriceObject *> *prices = [NSMutableArray array];
    for (NSDictionary *rawPriceObject in response) {
        NSString *symbol = rawPriceObject[@"symbol"];
        if (![symbol hasPrefix:@"DASH"]) {
            continue;
        }
        NSString *code = [symbol substringFromIndex:4];
        NSNumber *price = @([rawPriceObject[@"price"] doubleValue]);
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
