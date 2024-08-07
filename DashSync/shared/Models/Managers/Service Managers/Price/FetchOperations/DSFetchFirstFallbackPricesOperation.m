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


#import "DSFetchFirstFallbackPricesOperation.h"

#import "DSCurrencyPriceObject.h"
#import "DSHTTPBitcoinAvgOperation.h"
#import "DSHTTPDashBtcCCOperation.h"
#import "DSHTTPDashCasaOperation.h"
#import "DSOperationQueue.h"

NS_ASSUME_NONNULL_BEGIN

#define DASHBTCCC_TICKER_URL @"https://min-api.cryptocompare.com/data/generateAvg?fsym=DASH&tsym=BTC&e=Binance,Kraken,Poloniex,Bitfinex"

@interface DSFetchFirstFallbackPricesOperation ()

@property (strong, nonatomic) DSHTTPDashBtcCCOperation *dashBtcCCOperation;
@property (strong, nonatomic) DSHTTPBitcoinAvgOperation *bitcoinAvgOperation;
@property (strong, nonatomic) DSHTTPDashCasaOperation *dashCasaOperation;

@property (copy, nonatomic) void (^fetchCompletion)(NSArray<DSCurrencyPriceObject *> *_Nullable, NSString *_Nullable priceSource, NSError *_Nullable error);

@end

@implementation DSFetchFirstFallbackPricesOperation

- (DSOperation *)initOperationWithCompletion:(void (^)(NSArray<DSCurrencyPriceObject *> *_Nullable, NSString *priceSource, NSError *_Nullable error))completion {
    self = [super initWithOperations:nil];
    if (self) {
        {
            HTTPRequest *request = [HTTPRequest requestWithURL:[NSURL URLWithString:DASHBTCCC_TICKER_URL]
                                                        method:HTTPRequestMethod_GET
                                                    parameters:nil];
            request.timeout = 30.0;
            request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
            DSHTTPDashBtcCCOperation *operation = [[DSHTTPDashBtcCCOperation alloc] initWithRequest:request];
            _dashBtcCCOperation = operation;
            [self addOperation:operation];
        }

        _fetchCompletion = [completion copy];
    }
    return self;
}

- (void)operationDidFinish:(NSOperation *)operation withErrors:(nullable NSArray<NSError *> *)errors {
    if (self.cancelled) {
        self.fetchCompletion(nil, [self.class priceSourceInfo], nil);
        
        return;
    }

    if (errors.count > 0) {
        [self.dashBtcCCOperation cancel];
        [self.bitcoinAvgOperation cancel];
        [self.dashCasaOperation cancel];
        
        self.fetchCompletion(nil, [self.class priceSourceInfo], errors.firstObject);
    }
}

- (void)finishedWithErrors:(NSArray<NSError *> *)errors {
    if (self.cancelled) {
        self.fetchCompletion(nil, [self.class priceSourceInfo], nil);
        
        return;
    }

    if (errors.count > 0) {
        self.fetchCompletion(nil, [self.class priceSourceInfo], errors.firstObject);

        return;
    }

    double dashBtcPrice = self.dashBtcCCOperation.dashBtcPrice.doubleValue;
    NSDictionary<NSString *, NSNumber *> *pricesByCode = self.bitcoinAvgOperation.pricesByCode;
    NSNumber *dashrateNumber = self.dashCasaOperation.dashrate;

    if (!pricesByCode || dashBtcPrice < DBL_EPSILON || !dashrateNumber) {
        self.fetchCompletion(nil, [self.class priceSourceInfo], nil);

        return;
    }

    NSMutableArray<DSCurrencyPriceObject *> *prices = [NSMutableArray array];
    for (NSString *code in pricesByCode) {
        double price = 0.0;
        if ([code isEqualToString:@"VES"]) {
            price = dashrateNumber.doubleValue;
        } else {
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

    self.fetchCompletion([prices copy], [self.class priceSourceInfo], nil);
}

+ (NSString *)priceSourceInfo {
    return @"cryptocompare.com";
}

@end

NS_ASSUME_NONNULL_END
