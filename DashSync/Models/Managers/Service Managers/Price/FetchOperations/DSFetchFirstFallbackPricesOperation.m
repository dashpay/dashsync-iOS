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
#import "DSDynamicOptions.h"
#import "DSHTTPGETOperation.h"
#import "DSOperationQueue.h"
#import "DSParseBitcoinAvgResponseOperation.h"
#import "DSParseDashBtcCCResponseOperation.h"
#import "DSParseDashVesCCResponseOperation.h"

NS_ASSUME_NONNULL_BEGIN

#define DASHBTCCC_TICKER_URL @"https://min-api.cryptocompare.com/data/generateAvg?fsym=DASH&tsym=BTC&e=Binance,Kraken,Poloniex,Bitfinex"
#define DASHVESCC_TICKER_URL @"https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=VES"
#define BITCOINAVG_TICKER_URL @"https://apiv2.bitcoinaverage.com/indices/global/ticker/short?crypto=BTC"

#pragma mark - Cache

@interface DSFetchFirstFallbackPricesOperationCache : DSDynamicOptions

@property (strong, nonatomic, nullable) NSDictionary<NSString *, NSNumber *> *pricesByCode;
@property (strong, nonatomic, nullable) NSNumber *dashBtcPrice;
@property (strong, nonatomic, nullable) NSNumber *vesPrice;

@end

@implementation DSFetchFirstFallbackPricesOperationCache

@dynamic pricesByCode;
@dynamic dashBtcPrice;
@dynamic vesPrice;

+ (instancetype)sharedInstance {
    static DSFetchFirstFallbackPricesOperationCache *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (NSString *)defaultsKeyForPropertyName:(NSString *)propertyName {
    NSDictionary *defaultsKeyByProperty = @{
        @"pricesByCode" : @"ds_prices_bitcoinavg_pricesByCode",
        @"dashBtcPrice" : @"ds_prices_cc_dashBtcPrice",
        @"vesPrice" : @"ds_prices_cc_vesPrice",
    };
    NSString *defaultsKey = defaultsKeyByProperty[propertyName];
    NSParameterAssert(defaultsKey);
    return defaultsKey ?: propertyName;
}

@end

#pragma mark - Operation

@interface DSFetchFirstFallbackPricesOperation ()

@property (strong, nonatomic) DSParseDashBtcCCResponseOperation *parseDashBtcCCOperation;
@property (strong, nonatomic) DSParseDashVesCCResponseOperation *parseDashVesCCOperation;
@property (strong, nonatomic) DSParseBitcoinAvgResponseOperation *parseBitcoinAvgOperation;
@property (strong, nonatomic) DSChainedOperation *chainDashBtcCCOperation;
@property (strong, nonatomic) DSChainedOperation *chainDashVesCCOperation;
@property (strong, nonatomic) DSChainedOperation *chainBitcoinAvgOperation;

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
            DSHTTPGETOperation *getOperation = [[DSHTTPGETOperation alloc] initWithRequest:request];
            DSParseDashBtcCCResponseOperation *parseOperation = [[DSParseDashBtcCCResponseOperation alloc] init];
            DSChainedOperation *chainOperation = [DSChainedOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parseDashBtcCCOperation = parseOperation;
            _chainDashBtcCCOperation = chainOperation;
            [self addOperation:chainOperation];
        }
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:DASHVESCC_TICKER_URL]
                                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                 timeoutInterval:30.0];
            DSHTTPGETOperation *getOperation = [[DSHTTPGETOperation alloc] initWithRequest:request];
            DSParseDashVesCCResponseOperation *parseOperation = [[DSParseDashVesCCResponseOperation alloc] init];
            DSChainedOperation *chainOperation = [DSChainedOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parseDashVesCCOperation = parseOperation;
            _chainDashVesCCOperation = chainOperation;
            [self addOperation:chainOperation];
        }
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:BITCOINAVG_TICKER_URL]
                                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                 timeoutInterval:30.0];
            DSHTTPGETOperation *getOperation = [[DSHTTPGETOperation alloc] initWithRequest:request];
            DSParseBitcoinAvgResponseOperation *parseOperation = [[DSParseBitcoinAvgResponseOperation alloc] init];
            DSChainedOperation *chainOperation = [DSChainedOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parseBitcoinAvgOperation = parseOperation;
            _chainBitcoinAvgOperation = chainOperation;
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

    DSFetchFirstFallbackPricesOperationCache *cache = [DSFetchFirstFallbackPricesOperationCache sharedInstance];
    if (operation == self.chainDashBtcCCOperation) {
        NSNumber *dashBtcPrice = self.parseDashBtcCCOperation.dashBtcPrice;
        if (dashBtcPrice) {
            cache.dashBtcPrice = dashBtcPrice;
        }
    }
    else if (operation == self.chainDashVesCCOperation) {
        NSNumber *vesPrice = self.parseDashVesCCOperation.vesPrice;
        if (vesPrice) {
            cache.vesPrice = vesPrice;
        }
    }
    else if (operation == self.chainBitcoinAvgOperation) {
        NSDictionary<NSString *, NSNumber *> *pricesByCode = self.parseBitcoinAvgOperation.pricesByCode;
        if (pricesByCode) {
            cache.pricesByCode = pricesByCode;
        }
    }
}

- (void)finishedWithErrors:(NSArray<NSError *> *)errors {
    if (self.cancelled) {
        return;
    }

    DSFetchFirstFallbackPricesOperationCache *cache = [DSFetchFirstFallbackPricesOperationCache sharedInstance];
    double dashBtcPrice = cache.dashBtcPrice.doubleValue;
    NSNumber *vesPriceNumber = cache.vesPrice;
    NSDictionary<NSString *, NSNumber *> *pricesByCode = cache.pricesByCode;

    if (!pricesByCode || dashBtcPrice < DBL_EPSILON) {
        self.fetchCompletion(nil);

        return;
    }

    double vesPrice = vesPriceNumber.doubleValue * dashBtcPrice;

    NSMutableArray<DSCurrencyPriceObject *> *prices = [NSMutableArray array];
    for (NSString *code in pricesByCode) {
        DSCurrencyPriceObject *priceObject = nil;
        if ([code isEqualToString:@"VES"] && vesPrice > DBL_EPSILON) {
            priceObject = [[DSCurrencyPriceObject alloc] initWithCode:code price:@(vesPrice)];
        }
        else {
            double btcPrice = [pricesByCode[code] doubleValue];
            double price = btcPrice * dashBtcPrice;
            if (price > DBL_EPSILON) {
                priceObject = [[DSCurrencyPriceObject alloc] initWithCode:code price:@(price)];
            }
        }
        if (priceObject) {
            [prices addObject:priceObject];
        }
    }

    self.fetchCompletion([prices copy]);
}

@end

NS_ASSUME_NONNULL_END
