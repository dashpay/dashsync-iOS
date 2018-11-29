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

#import "DSFetchSecondFallbackPricesOperation.h"

#import "DSChainOperation.h"
#import "DSCurrencyPriceObject.h"
#import "DSHTTPGETOperation.h"
#import "DSOperationQueue.h"
#import "DSParseBitPayResponseOperation.h"
#import "DSParseDashCentralResponseOperation.h"
#import "DSParsePoloniexResponseOperation.h"

NS_ASSUME_NONNULL_BEGIN

#define BITPAY_TICKER_URL @"https://bitpay.com/rates"
#define POLONIEX_TICKER_URL @"https://poloniex.com/public?command=returnOrderBook&currencyPair=BTC_DASH&depth=1"
#define DASHCENTRAL_TICKER_URL @"https://www.dashcentral.org/api/v1/public"

#define CURRENCY_CODES_KEY @"CURRENCY_CODES"
#define CURRENCY_PRICES_KEY @"CURRENCY_PRICES"
#define POLONIEX_DASH_BTC_PRICE_KEY @"POLONIEX_DASH_BTC_PRICE"
#define DASHCENTRAL_DASH_BTC_PRICE_KEY @"DASHCENTRAL_DASH_BTC_PRICE"

#pragma mark - Cache

@interface DSFetchSecondFallbackPricesOperationCache : NSObject

@property (nonatomic, copy) NSArray<NSString *> *currencyCodes;
@property (nonatomic, copy) NSArray<NSNumber *> *currencyPrices;

@property (strong, nonatomic) NSNumber *poloniexLastPrice;
@property (strong, nonatomic) NSNumber *dashcentralLastPrice;

@end

@implementation DSFetchSecondFallbackPricesOperationCache

+ (instancetype)sharedInstance {
    static DSFetchSecondFallbackPricesOperationCache *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        _currencyCodes = [defaults arrayForKey:CURRENCY_CODES_KEY];
        _currencyPrices = [defaults arrayForKey:CURRENCY_PRICES_KEY];
        _poloniexLastPrice = [defaults objectForKey:POLONIEX_DASH_BTC_PRICE_KEY];
        _dashcentralLastPrice = [defaults objectForKey:DASHCENTRAL_DASH_BTC_PRICE_KEY];
    }
    return self;
}

- (void)setCurrencyCodes:(NSArray<NSString *> *)currencyCodes {
    _currencyCodes = [currencyCodes copy];
    [[NSUserDefaults standardUserDefaults] setObject:currencyCodes forKey:CURRENCY_CODES_KEY];
}

- (void)setCurrencyPrices:(NSArray<NSNumber *> *)currencyPrices {
    _currencyPrices = [currencyPrices copy];
    [[NSUserDefaults standardUserDefaults] setObject:currencyPrices forKey:CURRENCY_PRICES_KEY];
}

- (void)setPoloniexLastPrice:(NSNumber *)poloniexLastPrice {
    _poloniexLastPrice = poloniexLastPrice;
    [[NSUserDefaults standardUserDefaults] setObject:poloniexLastPrice forKey:POLONIEX_DASH_BTC_PRICE_KEY];
}

- (void)setDashcentralLastPrice:(NSNumber *)dashcentralLastPrice {
    _dashcentralLastPrice = dashcentralLastPrice;
    [[NSUserDefaults standardUserDefaults] setObject:dashcentralLastPrice forKey:DASHCENTRAL_DASH_BTC_PRICE_KEY];
}

@end

#pragma mark - Operation

@interface DSFetchSecondFallbackPricesOperation ()

@property (strong, nonatomic) DSParseBitPayResponseOperation *parseBitPayOperation;
@property (strong, nonatomic) DSParsePoloniexResponseOperation *parsePoloniexOperation;
@property (strong, nonatomic) DSParseDashCentralResponseOperation *parseDashcentralOperation;
@property (strong, nonatomic) DSChainOperation *chainBitPayOperation;
@property (strong, nonatomic) DSChainOperation *chainPoloniexOperation;
@property (strong, nonatomic) DSChainOperation *chainDashcentralOperation;

@property (copy, nonatomic) void (^fetchCompletion)(NSArray<DSCurrencyPriceObject *> *_Nullable);

@end

@implementation DSFetchSecondFallbackPricesOperation

- (DSOperation *)initOperationWithCompletion:(void (^)(NSArray<DSCurrencyPriceObject *> *_Nullable))completion {
    self = [super initWithOperations:nil];
    if (self) {
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:BITPAY_TICKER_URL]
                                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                 timeoutInterval:10.0];
            DSHTTPGETOperation *getOperation = [[DSHTTPGETOperation alloc] initWithRequest:request];
            DSParseBitPayResponseOperation *parseOperation = [[DSParseBitPayResponseOperation alloc] init];
            DSChainOperation *chainOperation = [DSChainOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parseBitPayOperation = parseOperation;
            _chainBitPayOperation = chainOperation;
            [self addOperation:chainOperation];
        }
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:POLONIEX_TICKER_URL]
                                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                 timeoutInterval:30.0];
            DSHTTPGETOperation *getOperation = [[DSHTTPGETOperation alloc] initWithRequest:request];
            DSParsePoloniexResponseOperation *parseOperation = [[DSParsePoloniexResponseOperation alloc] init];
            DSChainOperation *chainOperation = [DSChainOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parsePoloniexOperation = parseOperation;
            _chainPoloniexOperation = chainOperation;
            [self addOperation:chainOperation];
        }
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:DASHCENTRAL_TICKER_URL]
                                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                 timeoutInterval:30.0];
            DSHTTPGETOperation *getOperation = [[DSHTTPGETOperation alloc] initWithRequest:request];
            DSParseDashCentralResponseOperation *parseOperation = [[DSParseDashCentralResponseOperation alloc] init];
            DSChainOperation *chainOperation = [DSChainOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parseDashcentralOperation = parseOperation;
            _chainDashcentralOperation = chainOperation;
            [self addOperation:chainOperation];
        }

        _fetchCompletion = [completion copy];
    }
    return self;
}

- (void)operationDidFinish:(NSOperation *)operation withErrors:(nullable NSArray<NSError *> *)errors {
    if (operation == self.chainBitPayOperation) {
        NSArray *currencyCodes = self.parseBitPayOperation.currencyCodes;
        NSArray *currencyPrices = self.parseBitPayOperation.currencyPrices;
        if (currencyCodes && currencyPrices) {
            DSFetchSecondFallbackPricesOperationCache *cache = [DSFetchSecondFallbackPricesOperationCache sharedInstance];
            cache.currencyCodes = currencyCodes;
            cache.currencyPrices = currencyPrices;
        }
    }
    else if (operation == self.chainPoloniexOperation) {
        NSNumber *poloniexPrice = self.parsePoloniexOperation.lastTradePriceNumber;
        if (poloniexPrice) {
            [DSFetchSecondFallbackPricesOperationCache sharedInstance].poloniexLastPrice = poloniexPrice;
        }
    }
    else if (operation == self.chainDashcentralOperation) {
        NSNumber *dashcentralPrice = self.parseDashcentralOperation.btcDashPrice;
        if (dashcentralPrice) {
            [DSFetchSecondFallbackPricesOperationCache sharedInstance].dashcentralLastPrice = dashcentralPrice;
        }
    }
}

- (void)finishedWithErrors:(NSArray<NSError *> *)errors {
    DSFetchSecondFallbackPricesOperationCache *cache = [DSFetchSecondFallbackPricesOperationCache sharedInstance];
    NSArray<NSString *> *currencyCodes = cache.currencyCodes;
    NSArray<NSNumber *> *currencyPrices = cache.currencyPrices;
    NSNumber *poloniexPriceNumber = cache.poloniexLastPrice;
    NSNumber *dashcentralPriceNumber = cache.dashcentralLastPrice;
    
    // not enough data to build prices
    if (!currencyCodes ||
        !currencyPrices ||
        !(poloniexPriceNumber || dashcentralPriceNumber) ||
        currencyCodes.count != currencyPrices.count) {
        
        self.fetchCompletion(nil);
        
        return;
    }
    
    double poloniexPrice = poloniexPriceNumber.doubleValue;
    double dashcentralPrice = dashcentralPriceNumber.doubleValue;
    double btcDashPrice = 0.0;
    if (poloniexPrice > 0.0) {
        if (dashcentralPrice > 0.0) {
            btcDashPrice = (poloniexPrice + dashcentralPrice) / 2.0;
        }
        else {
            btcDashPrice = poloniexPrice;
        }
    }
    else if (dashcentralPrice > 0.0) {
        btcDashPrice = dashcentralPrice;
    }
    
    if (btcDashPrice < DBL_EPSILON) {
        self.fetchCompletion(nil);
        
        return;
    }
    
    NSMutableArray<DSCurrencyPriceObject *> *prices = [NSMutableArray array];
    for (NSString *code in currencyCodes) {
        NSUInteger index = [currencyCodes indexOfObject:code];
        NSNumber *btcPrice = currencyPrices[index];
        NSNumber *price = @(btcPrice.doubleValue * btcDashPrice);
        DSCurrencyPriceObject *priceObject = [[DSCurrencyPriceObject alloc] initWithCode:code price:price];
        if (priceObject) {
            [prices addObject:priceObject];
        }
    }
    
    self.fetchCompletion([prices copy]);
}

@end

NS_ASSUME_NONNULL_END
