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

#import "DSFetchSecondFallbackPricesOperation.h"

#import "DSCurrencyPriceObject.h"
#import "DSHTTPBitPayOperation.h"
#import "DSHTTPVesLocalBitcoinsOperation.h"
#import "DSHTTPDashCentralOperation.h"
#import "DSHTTPPoloniexOperation.h"

NS_ASSUME_NONNULL_BEGIN

#define BITPAY_TICKER_URL @"https://bitpay.com/rates"
#define POLONIEX_TICKER_URL @"https://poloniex.com/public?command=returnOrderBook&currencyPair=BTC_DASH&depth=1"
#define DASHCENTRAL_TICKER_URL @"https://www.dashcentral.org/api/v1/public"
#define LOCALBITCOINS_TICKER_URL @"https://localbitcoins.com/bitcoinaverage/ticker-all-currencies/"

@interface DSFetchSecondFallbackPricesOperation ()

@property (strong, nonatomic) DSHTTPBitPayOperation *bitPayOperation;
@property (strong, nonatomic) DSHTTPPoloniexOperation *poloniexOperation;
@property (strong, nonatomic) DSHTTPDashCentralOperation *dashcentralOperation;
@property (strong, nonatomic) DSHTTPVesLocalBitcoinsOperation *vesLocalBitcoinsOperation;

@property (copy, nonatomic) void (^fetchCompletion)(NSArray<DSCurrencyPriceObject *> *_Nullable, NSString *priceSource);

@end

@implementation DSFetchSecondFallbackPricesOperation

- (DSOperation *)initOperationWithCompletion:(void (^)(NSArray<DSCurrencyPriceObject *> *_Nullable, NSString *priceSource))completion {
    self = [super initWithOperations:nil];
    if (self) {
        {
            HTTPRequest *request = [HTTPRequest requestWithURL:[NSURL URLWithString:BITPAY_TICKER_URL]
                                                        method:HTTPRequestMethod_GET
                                                    parameters:nil];
            request.timeout = 30.0;
            request.cachePolicy = NSURLRequestReloadIgnoringCacheData;

            DSHTTPBitPayOperation *operation = [[DSHTTPBitPayOperation alloc] initWithRequest:request];
            _bitPayOperation = operation;
            [self addOperation:operation];
        }
        {
            HTTPRequest *request = [HTTPRequest requestWithURL:[NSURL URLWithString:POLONIEX_TICKER_URL]
                                                        method:HTTPRequestMethod_GET
                                                    parameters:nil];
            request.timeout = 30.0;
            request.cachePolicy = NSURLRequestReloadIgnoringCacheData;

            DSHTTPPoloniexOperation *operation = [[DSHTTPPoloniexOperation alloc] initWithRequest:request];
            _poloniexOperation = operation;
            [self addOperation:operation];
        }
        {
            HTTPRequest *request = [HTTPRequest requestWithURL:[NSURL URLWithString:DASHCENTRAL_TICKER_URL]
                                                        method:HTTPRequestMethod_GET
                                                    parameters:nil];
            request.timeout = 30.0;
            request.cachePolicy = NSURLRequestReloadIgnoringCacheData;

            DSHTTPDashCentralOperation *operation = [[DSHTTPDashCentralOperation alloc] initWithRequest:request];
            _dashcentralOperation = operation;
            [self addOperation:operation];
        }
        {
            HTTPRequest *request = [HTTPRequest requestWithURL:[NSURL URLWithString:LOCALBITCOINS_TICKER_URL]
                                                        method:HTTPRequestMethod_GET
                                                    parameters:nil];
            request.timeout = 30.0;
            request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
            DSHTTPVesLocalBitcoinsOperation *operation = [[DSHTTPVesLocalBitcoinsOperation alloc] initWithRequest:request];
            _vesLocalBitcoinsOperation = operation;
            [self addOperation:operation];
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
        [self.bitPayOperation cancel];
        [self.poloniexOperation cancel];
        [self.dashcentralOperation cancel];
        [self.vesLocalBitcoinsOperation cancel];
    }
}

- (void)finishedWithErrors:(NSArray<NSError *> *)errors {
    if (self.cancelled) {
        return;
    }

    if (errors.count > 0) {
        self.fetchCompletion(nil, [self.class priceSourceInfo]);

        return;
    }

    NSArray *currencyCodes = self.bitPayOperation.currencyCodes;
    NSArray *currencyPrices = self.bitPayOperation.currencyPrices;
    NSNumber *poloniexPriceNumber = self.poloniexOperation.lastTradePriceNumber;
    NSNumber *dashcentralPriceNumber = self.dashcentralOperation.btcDashPrice;
    NSNumber *vesPrice = self.vesLocalBitcoinsOperation.vesPrice;


    // not enough data to build prices
    if (!currencyCodes ||
        !currencyPrices ||
        !(poloniexPriceNumber || dashcentralPriceNumber) ||
        !vesPrice ||
        currencyCodes.count != currencyPrices.count) {

        self.fetchCompletion(nil, [self.class priceSourceInfo]);

        return;
    }

    double poloniexPrice = poloniexPriceNumber.doubleValue;
    double dashcentralPrice = dashcentralPriceNumber.doubleValue;
    double dashBtcPrice = 0.0;
    if (poloniexPrice > 0.0) {
        if (dashcentralPrice > 0.0) {
            dashBtcPrice = (poloniexPrice + dashcentralPrice) / 2.0;
        }
        else {
            dashBtcPrice = poloniexPrice;
        }
    }
    else if (dashcentralPrice > 0.0) {
        dashBtcPrice = dashcentralPrice;
    }

    if (dashBtcPrice < DBL_EPSILON) {
        self.fetchCompletion(nil, [self.class priceSourceInfo]);

        return;
    }

    NSMutableArray<DSCurrencyPriceObject *> *prices = [NSMutableArray array];
    for (NSString *code in currencyCodes) {
        double price = 0.0;
        if ([code isEqualToString:@"VES"]) {
            price = vesPrice.doubleValue * dashBtcPrice;
        }
        else {
            NSUInteger index = [currencyCodes indexOfObject:code];
            NSNumber *btcPrice = currencyPrices[index];
            price = btcPrice.doubleValue * dashBtcPrice;
        }

        if (price > DBL_EPSILON) {
            DSCurrencyPriceObject *priceObject = [[DSCurrencyPriceObject alloc] initWithCode:code price:@(price)];
            if (priceObject) {
                [prices addObject:priceObject];
            }
        }
    }

    self.fetchCompletion([prices copy], [self.class priceSourceInfo]);
}

+ (NSString *)priceSourceInfo {
    return @"bitpay.com, poloniex.com, dashcentral.org, localbitcoins.com";
}

@end

NS_ASSUME_NONNULL_END
