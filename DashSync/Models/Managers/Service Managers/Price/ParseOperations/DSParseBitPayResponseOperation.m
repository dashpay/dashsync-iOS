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

#import "DSParseBitPayResponseOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSParseBitPayResponseOperation ()

@property (copy, nonatomic, nullable) NSArray<NSString *> *currencyCodes;
@property (copy, nonatomic, nullable) NSArray<NSNumber *> *currencyPrices;

@end

@implementation DSParseBitPayResponseOperation

- (void)execute {
    NSParameterAssert(self.responseToParse);

    NSDictionary *response = (NSDictionary *)self.responseToParse;
    if (![response isKindOfClass:NSDictionary.class]) {
        [self cancelWithError:[self.class invalidResponseErrorWithUserInfo:@{NSDebugDescriptionErrorKey : response}]];

        return;
    }

    NSArray *data = response[@"data"];
    if (![data isKindOfClass:NSArray.class]) {
        [self cancelWithError:[self.class invalidResponseErrorWithUserInfo:@{NSDebugDescriptionErrorKey : response}]];

        return;
    }

    NSDictionary *testPrice = data.firstObject;
    if (![testPrice isKindOfClass:NSDictionary.class] ||
        ![testPrice[@"code"] isKindOfClass:NSString.class] ||
        ![testPrice[@"rate"] isKindOfClass:NSNumber.class]) {

        [self cancelWithError:[self.class invalidResponseErrorWithUserInfo:@{NSDebugDescriptionErrorKey : response}]];

        return;
    }

    NSMutableArray *currencyCodes = [NSMutableArray array];
    NSMutableArray *currencyPrices = [NSMutableArray array];
    for (NSDictionary *object in response[@"data"]) {
        [currencyCodes addObject:object[@"code"]];
        [currencyPrices addObject:object[@"rate"]];
    }

    self.currencyCodes = currencyCodes;
    self.currencyPrices = currencyPrices;

    [self finish];
}

@end

NS_ASSUME_NONNULL_END
