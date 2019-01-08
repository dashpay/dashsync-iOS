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

#import "DSParsePoloniexResponseOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSParsePoloniexResponseOperation ()

@property (strong, nonatomic, nullable) NSNumber *lastTradePriceNumber;

@end

@implementation DSParsePoloniexResponseOperation

- (void)execute {
    NSParameterAssert(self.httpOperationResult.parsedResponse);

    NSDictionary *response = (NSDictionary *)self.httpOperationResult.parsedResponse;
    if (![response isKindOfClass:NSDictionary.class]) {
        [self cancelWithError:[self.class invalidResponseErrorWithUserInfo:@{NSDebugDescriptionErrorKey : response}]];

        return;
    }

    NSArray *asks = response[@"asks"];
    NSArray *bids = response[@"bids"];
    NSString *lastTradePriceStringAsks = [asks.firstObject firstObject];
    NSString *lastTradePriceStringBids = [bids.firstObject firstObject];
    if (lastTradePriceStringAsks && lastTradePriceStringBids) {
        NSNumberFormatter *numberFormatter = [self.class poloniesNumberFormatter];
        NSNumber *lastTradePriceNumberAsks = [numberFormatter numberFromString:lastTradePriceStringAsks];
        NSNumber *lastTradePriceNumberBids = [numberFormatter numberFromString:lastTradePriceStringBids];

        self.lastTradePriceNumber = @((lastTradePriceNumberAsks.floatValue + lastTradePriceNumberBids.floatValue) / 2.0);

        [self finish];
    }
    else {
        [self cancelWithError:[self.class invalidResponseErrorWithUserInfo:@{NSDebugDescriptionErrorKey : response}]];
    }
}

+ (NSNumberFormatter *)poloniesNumberFormatter {
    static NSNumberFormatter *numberFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        numberFormatter = [[NSNumberFormatter alloc] init];
        numberFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    });
    return numberFormatter;
}

@end

NS_ASSUME_NONNULL_END
