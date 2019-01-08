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

#import "DSFetchSparkPricesOperation.h"

#import "DSChainedOperation.h"
#import "DSHTTPOperation.h"
#import "DSParseSparkResponseOperation.h"

NS_ASSUME_NONNULL_BEGIN

#define SPARK_TICKER_URL @"https://api.get-spark.com/list"

@interface DSFetchSparkPricesOperation ()

@property (strong, nonatomic) DSParseSparkResponseOperation *parseOperation;

@property (copy, nonatomic) void (^fetchCompletion)(NSArray<DSCurrencyPriceObject *> *_Nullable);

@end

@implementation DSFetchSparkPricesOperation

- (DSOperation *)initOperationWithCompletion:(void (^)(NSArray<DSCurrencyPriceObject *> *_Nullable))completion {
    self = [super initWithOperations:nil];
    if (self) {
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:SPARK_TICKER_URL]
                                                 cachePolicy:NSURLRequestReloadIgnoringCacheData
                                             timeoutInterval:30.0];
        DSHTTPOperation *getOperation = [[DSHTTPOperation alloc] initWithRequest:request];
        DSParseSparkResponseOperation *parseOperation = [[DSParseSparkResponseOperation alloc] init];
        DSChainedOperation *chainOperation = [DSChainedOperation operationWithOperations:@[ getOperation, parseOperation ]];

        _parseOperation = parseOperation;
        _fetchCompletion = [completion copy];

        [self addOperation:chainOperation];
    }
    return self;
}

- (void)finishedWithErrors:(NSArray<NSError *> *)errors {
    if (self.cancelled) {
        return;
    }

    NSArray<DSCurrencyPriceObject *> *prices = self.parseOperation.prices;
    self.fetchCompletion(prices);
}

@end

NS_ASSUME_NONNULL_END
