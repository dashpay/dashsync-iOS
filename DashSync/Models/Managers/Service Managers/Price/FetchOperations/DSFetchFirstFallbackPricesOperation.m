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


#import "DSFetchFirstFallbackPricesOperation.h"

#import "DSChainedOperation.h"
#import "DSCurrencyPriceObject.h"
#import "DSHTTPOperation.h"
#import "DSOperationQueue.h"
#import "DSParseBitcoinAvgResponseOperation.h"
#import "DSParseDashBtcCCResponseOperation.h"
#import "DSParseDashCasaResponseOperation.h"

NS_ASSUME_NONNULL_BEGIN

#define DASHBTCCC_TICKER_URL @"https://min-api.cryptocompare.com/data/generateAvg?fsym=DASH&tsym=BTC&e=Binance,Kraken,Poloniex,Bitfinex"
#define BITCOINAVG_TICKER_URL @"https://apiv2.bitcoinaverage.com/indices/global/ticker/short?crypto=BTC"
#define DASHCASA_TICKER_URL @"http://dash.casa/api/?cur=VES"

@interface DSFetchFirstFallbackPricesOperation ()

@property (strong, nonatomic) DSParseDashBtcCCResponseOperation *parseDashBtcCCOperation;
@property (strong, nonatomic) DSParseBitcoinAvgResponseOperation *parseBitcoinAvgOperation;
@property (strong, nonatomic) DSParseDashCasaResponseOperation *parseDashCasaOperation;
@property (strong, nonatomic) DSChainedOperation *chainDashBtcCCOperation;
@property (strong, nonatomic) DSChainedOperation *chainBitcoinAvgOperation;
@property (strong, nonatomic) DSChainedOperation *chainDashCasaOperation;

@property (copy, nonatomic) void (^fetchCompletion)(NSArray<DSCurrencyPriceObject *> *_Nullable);

@end

@implementation DSFetchFirstFallbackPricesOperation

- (DSOperation *)initOperationWithCompletion:(void (^)(NSArray<DSCurrencyPriceObject *> *_Nullable))completion {
    self = [super initWithOperations:nil];
    if (self) {
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:DASHBTCCC_TICKER_URL]
                                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                 timeoutInterval:30.0];
            DSHTTPOperation *getOperation = [[DSHTTPOperation alloc] initWithRequest:request];
            DSParseDashBtcCCResponseOperation *parseOperation = [[DSParseDashBtcCCResponseOperation alloc] init];
            DSChainedOperation *chainOperation = [DSChainedOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parseDashBtcCCOperation = parseOperation;
            _chainDashBtcCCOperation = chainOperation;
            [self addOperation:chainOperation];
        }
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:BITCOINAVG_TICKER_URL]
                                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                 timeoutInterval:30.0];
            DSHTTPOperation *getOperation = [[DSHTTPOperation alloc] initWithRequest:request];
            DSParseBitcoinAvgResponseOperation *parseOperation = [[DSParseBitcoinAvgResponseOperation alloc] init];
            DSChainedOperation *chainOperation = [DSChainedOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parseBitcoinAvgOperation = parseOperation;
            _chainBitcoinAvgOperation = chainOperation;
            [self addOperation:chainOperation];
        }
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:DASHCASA_TICKER_URL]
                                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                 timeoutInterval:30.0];
            DSHTTPOperation *getOperation = [[DSHTTPOperation alloc] initWithRequest:request];
            DSParseDashCasaResponseOperation *parseOperation = [[DSParseDashCasaResponseOperation alloc] init];
            DSChainedOperation *chainOperation = [DSChainedOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parseDashCasaOperation = parseOperation;
            _chainDashCasaOperation = chainOperation;
            [self addOperation:chainOperation];
        }

        _fetchCompletion = [completion copy];
    }
    return self;
}

- (void)operationDidFinish:(NSOperation *)operation withErrors:(nullable NSArray<NSError *> *)errors {
    if (self.cancelled) {
        return;
    }

    if (errors.count > 0) {
        [self.chainDashBtcCCOperation cancel];
        [self.chainBitcoinAvgOperation cancel];
        [self.chainDashCasaOperation cancel];
    }
}

- (void)finishedWithErrors:(NSArray<NSError *> *)errors {
    if (self.cancelled) {
        return;
    }

    if (errors.count > 0) {
        self.fetchCompletion(nil);

        return;
    }

    double dashBtcPrice = self.parseDashBtcCCOperation.dashBtcPrice.doubleValue;
    NSDictionary<NSString *, NSNumber *> *pricesByCode = self.parseBitcoinAvgOperation.pricesByCode;
    NSNumber *dashcasaPrice = self.parseDashCasaOperation.dashrate;

    if (!pricesByCode || dashBtcPrice < DBL_EPSILON || !dashcasaPrice) {
        self.fetchCompletion(nil);

        return;
    }

    NSMutableArray<DSCurrencyPriceObject *> *prices = [NSMutableArray array];
    for (NSString *code in pricesByCode) {
        double price = 0.0;
        if ([code isEqualToString:@"VES"]) {
            price = dashcasaPrice.doubleValue;
        }
        else {
            double btcPrice = [pricesByCode[code] doubleValue];
            price = btcPrice * dashBtcPrice;
        }

        if (price > DBL_EPSILON) {
            DSCurrencyPriceObject *priceObject = [[DSCurrencyPriceObject alloc] initWithCode:code price:@(price)];
            if (priceObject) {
                [prices addObject:priceObject];
            }
        }
    }

    self.fetchCompletion([prices copy]);
}

@end

NS_ASSUME_NONNULL_END
