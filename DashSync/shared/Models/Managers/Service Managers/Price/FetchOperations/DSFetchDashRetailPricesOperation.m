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

#import "DSFetchDashRetailPricesOperation.h"

#import "DSHTTPDashRetailOperation.h"

NS_ASSUME_NONNULL_BEGIN

#define DASHRETAIL_TICKER_URL @"https://rates2.dashretail.org/rates?source=dashretail"

@interface DSFetchDashRetailPricesOperation ()

@property (strong, nonatomic) DSHTTPDashRetailOperation *dashRetailOperation;

@property (copy, nonatomic) void (^fetchCompletion)(NSArray<DSCurrencyPriceObject *> *_Nullable, NSString *priceSource);

@end

@implementation DSFetchDashRetailPricesOperation

- (DSOperation *)initOperationWithCompletion:(void (^)(NSArray<DSCurrencyPriceObject *> *_Nullable, NSString *priceSource))completion {
    self = [super initWithOperations:nil];
    if (self) {
        HTTPRequest *request = [HTTPRequest requestWithURL:[NSURL URLWithString:DASHRETAIL_TICKER_URL]
                                                    method:HTTPRequestMethod_GET
                                                parameters:nil];
        request.timeout = 30.0;
        request.cachePolicy = NSURLRequestReloadIgnoringCacheData;

        DSHTTPDashRetailOperation *operation = [[DSHTTPDashRetailOperation alloc] initWithRequest:request];
        _dashRetailOperation = operation;
        _fetchCompletion = [completion copy];

        [self addOperation:operation];
    }
    return self;
}

- (void)finishedWithErrors:(NSArray<NSError *> *)errors {
    if (self.cancelled) {
        return;
    }

    NSArray<DSCurrencyPriceObject *> *prices = self.dashRetailOperation.prices;
    self.fetchCompletion(prices, [self.class priceSourceInfo]);
}

+ (NSString *)priceSourceInfo {
    return @"dashretail.org";
}

@end

NS_ASSUME_NONNULL_END
