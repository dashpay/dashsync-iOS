//
//  DSPriceManager.m
//  DashSync
//
//  Created by Aaron Voisine for BreadWallet on 3/2/14.
//  Copyright (c) 2014 Aaron Voisine <voisine@gmail.com>
//  Updated by Quantum Explorer on 05/11/18.
//  Copyright (c) 2018 Quantum Explorer <quantum@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSPriceManager.h"
#import "DSAccount.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "DSBIP39Mnemonic.h"
#import "DSChain.h"
#import "DSChainsManager.h"
#import "DSECDSAKey.h"
#import "DSEventManager.h"
#import "DSKey+BIP38.h"
#import "DSTransaction.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSWallet.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

#import "DSCurrencyPriceObject.h"
#import "DSOperation.h"
#import "DSOperationQueue.h"
#import "DSPriceOperationProvider.h"

#import "DSAuthenticationManager.h"
#import "DSDerivationPath.h"
#import "DSPeerManager.h"
#import "DSReachabilityManager.h"
#import "NSData+Bitcoin.h"
#import "NSDate+Utils.h"
#import "NSString+Dash.h"

#define TICKER_REFRESH_TIME 60.0

#define DEFAULT_CURRENCY_CODE @"USD"
#define DEFAULT_SPENT_LIMIT DUFFS

#define LOCAL_CURRENCY_CODE_KEY @"LOCAL_CURRENCY_CODE"

#define PRICESBYCODE_KEY @"DS_PRICEMANAGER_PRICESBYCODE"

#define USER_ACCOUNT_KEY @"https://api.dashwallet.com"


@interface DSPriceManager ()

@property (nonatomic, strong) DSOperationQueue *operationQueue;
@property (nonatomic, strong) DSReachabilityManager *reachability;

@property (nonatomic, strong) NSNumber *bitcoinDashPrice;                    // exchange rate in bitcoin per dash
@property (nonatomic, strong) NSNumber *_Nullable localCurrencyBitcoinPrice; // exchange rate in local currency units per bitcoin
@property (nonatomic, strong) NSNumber *_Nullable localCurrencyDashPrice;

@property (copy, nonatomic) NSArray<DSCurrencyPriceObject *> *prices;
@property (copy, nonatomic) NSDictionary<NSString *, DSCurrencyPriceObject *> *pricesByCode;
@property (nonatomic, copy) NSString *lastPriceSourceInfo;

@end

@implementation DSPriceManager

+ (instancetype)sharedInstance {
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });

    return singleton;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;

    self.operationQueue = [[DSOperationQueue alloc] init];

    self.reachability = [DSReachabilityManager sharedManager];
    _dashFormat = [NSNumberFormatter new];
    self.dashFormat.lenient = YES;
    self.dashFormat.numberStyle = NSNumberFormatterCurrencyStyle;
    self.dashFormat.generatesDecimalNumbers = YES;
    NSRange positiveFormatRange = [self.dashFormat.positiveFormat rangeOfString:@"#"];
    if (positiveFormatRange.location != NSNotFound) {
        self.dashFormat.negativeFormat = [self.dashFormat.positiveFormat
            stringByReplacingCharactersInRange:positiveFormatRange
                                    withString:@"-#"];
    }
    self.dashFormat.currencyCode = @"DASH";
    if (@available(iOS 13.0, *)) {
        self.dashFormat.currencySymbol = DASH;
    } else {
        self.dashFormat.currencySymbol = DASH NARROW_NBSP;
    }
    self.dashFormat.maximumFractionDigits = 8;
    self.dashFormat.minimumFractionDigits = 0; // iOS 8 bug, minimumFractionDigits now has to be set after currencySymbol
    self.dashFormat.maximum = @(MAX_MONEY / (int64_t)pow(10.0, self.dashFormat.maximumFractionDigits));

    _dashSignificantFormat = [NSNumberFormatter new];
    self.dashSignificantFormat.lenient = YES;
    self.dashSignificantFormat.numberStyle = NSNumberFormatterCurrencyStyle;
    self.dashSignificantFormat.generatesDecimalNumbers = YES;
    if (positiveFormatRange.location != NSNotFound) {
        self.dashSignificantFormat.negativeFormat = [self.dashFormat.positiveFormat
            stringByReplacingCharactersInRange:positiveFormatRange
                                    withString:@"-#"];
    }
    self.dashSignificantFormat.currencyCode = @"DASH";
    if (@available(iOS 13.0, *)) {
        self.dashSignificantFormat.currencySymbol = DASH;
    } else {
        self.dashSignificantFormat.currencySymbol = DASH NARROW_NBSP;
    }
    self.dashSignificantFormat.usesSignificantDigits = TRUE;
    self.dashSignificantFormat.minimumSignificantDigits = 1;
    self.dashSignificantFormat.maximumSignificantDigits = 6;
    self.dashSignificantFormat.maximumFractionDigits = 8;
    self.dashSignificantFormat.minimumFractionDigits = 0; // iOS 8 bug, minimumFractionDigits now has to be set after currencySymbol
    self.dashSignificantFormat.maximum = @(MAX_MONEY / (int64_t)pow(10.0, self.dashFormat.maximumFractionDigits));

    _bitcoinFormat = [NSNumberFormatter new];
    self.bitcoinFormat.lenient = YES;
    self.bitcoinFormat.numberStyle = NSNumberFormatterCurrencyStyle;
    self.bitcoinFormat.generatesDecimalNumbers = YES;
    NSRange bitcoinPositiveFormatRange = [self.bitcoinFormat.positiveFormat rangeOfString:@"#"];
    if (bitcoinPositiveFormatRange.location != NSNotFound) {
        self.bitcoinFormat.negativeFormat = [self.bitcoinFormat.positiveFormat
            stringByReplacingCharactersInRange:bitcoinPositiveFormatRange
                                    withString:@"-#"];
    }
    self.bitcoinFormat.currencyCode = @"BTC";
    if (@available(iOS 13.0, *)) {
        self.bitcoinFormat.currencySymbol = BTC;
    } else {
        self.bitcoinFormat.currencySymbol = BTC NARROW_NBSP;
    }
    self.bitcoinFormat.maximumFractionDigits = 8;
    self.bitcoinFormat.minimumFractionDigits = 0; // iOS 8 bug, minimumFractionDigits now has to be set after currencySymbol
    self.bitcoinFormat.maximum = @(MAX_MONEY / (int64_t)pow(10.0, self.bitcoinFormat.maximumFractionDigits));

    _unknownFormat = [NSNumberFormatter new];
    self.unknownFormat.lenient = YES;
    self.unknownFormat.numberStyle = NSNumberFormatterDecimalStyle;
    self.unknownFormat.generatesDecimalNumbers = YES;
    NSRange unknownPositivieFormatRange = [self.unknownFormat.positiveFormat rangeOfString:@"#"];
    if (unknownPositivieFormatRange.location != NSNotFound) {
        self.unknownFormat.negativeFormat = [self.unknownFormat.positiveFormat
            stringByReplacingCharactersInRange:unknownPositivieFormatRange
                                    withString:@"-#"];
    }
    self.unknownFormat.maximumFractionDigits = 8;
    self.unknownFormat.minimumFractionDigits = 0; // iOS 8 bug, minimumFractionDigits now has to be set after currencySymbol

    _localFormat = [NSNumberFormatter new];
    self.localFormat.lenient = YES;
    self.localFormat.numberStyle = NSNumberFormatterCurrencyStyle;
    self.localFormat.generatesDecimalNumbers = YES;
    self.localFormat.negativeFormat = self.dashFormat.negativeFormat;

    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *path = [bundle pathForResource:@"CurrenciesByCode" ofType:@"plist"];
    _currenciesByCode = [NSDictionary dictionaryWithContentsOfFile:path];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];


    NSMutableDictionary<NSString *, NSNumber *> *plainPricesByCode = [defaults objectForKey:PRICESBYCODE_KEY];
    if (plainPricesByCode) {
        NSMutableDictionary<NSString *, DSCurrencyPriceObject *> *pricesByCode = [NSMutableDictionary dictionary];
        NSMutableArray<DSCurrencyPriceObject *> *prices = [NSMutableArray array];
        for (NSString *code in plainPricesByCode) {
            NSNumber *price = plainPricesByCode[code];
            NSString *name = _currenciesByCode[code];
            DSCurrencyPriceObject *priceObject = [[DSCurrencyPriceObject alloc] initWithCode:code
                                                                                        name:name
                                                                                       price:price];
            if (priceObject) {
                pricesByCode[code] = priceObject;
                [prices addObject:priceObject];
            }
        }

        _prices = [[self.class sortPrices:prices usingDictionary:pricesByCode] copy];
        _pricesByCode = [pricesByCode copy];
    }

    NSString *userCurrencyCode = [defaults stringForKey:LOCAL_CURRENCY_CODE_KEY];

    NSString *systemCurrencyCode = [NSLocale currentLocale].currencyCode;
    if (_pricesByCode[systemCurrencyCode] == nil) {
        // if we don't have currency in our plist fallback to default
        systemCurrencyCode = DEFAULT_CURRENCY_CODE;
    }
    self.localCurrencyCode = (userCurrencyCode) ? userCurrencyCode : systemCurrencyCode;

    return self;
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)startExchangeRateFetching {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updatePrices];
    });
}

// MARK: - exchange rate

// local currency ISO code
- (void)setLocalCurrencyCode:(NSString *)code {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];


    _localCurrencyCode = [code copy];

    if ([self.pricesByCode objectForKey:code] && [DSAuthenticationManager sharedInstance].secureTime + 3 * DAY_TIME_INTERVAL > [NSDate timeIntervalSince1970]) {
        DSCurrencyPriceObject *priceObject = self.pricesByCode[code];
        self.localCurrencyDashPrice = priceObject.price; // don't use exchange rate data more than 72hrs out of date
    } else {
        self.localCurrencyDashPrice = @(0);
    }

    self.localFormat.currencyCode = _localCurrencyCode;
    self.localFormat.maximum =
        [[NSDecimalNumber decimalNumberWithDecimal:self.localCurrencyDashPrice.decimalValue]
            decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithLongLong:MAX_MONEY / DUFFS]];

    if ([self.localCurrencyCode isEqual:[NSLocale currentLocale].currencyCode]) {
        [defs removeObjectForKey:LOCAL_CURRENCY_CODE_KEY];
    } else {
        [defs setObject:self.localCurrencyCode forKey:LOCAL_CURRENCY_CODE_KEY];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil];
    });
}

- (NSNumber *)bitcoinDashPrice {
    NSAssert(NO, @"Deprecated and must not be used");
    return @(0);
}

- (void)updatePrices {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updatePrices) object:nil];
    [self performSelector:@selector(updatePrices) withObject:nil afterDelay:TICKER_REFRESH_TIME];

    __weak typeof(self) weakSelf = self;
    DSOperation *priceOperation = [DSPriceOperationProvider fetchPrices:^(NSArray<DSCurrencyPriceObject *> *_Nullable prices, NSString *priceSource) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        if (prices) {
            NSMutableDictionary<NSString *, DSCurrencyPriceObject *> *pricesByCode = [NSMutableDictionary dictionary];
            NSMutableDictionary<NSString *, NSNumber *> *plainPricesByCode = [NSMutableDictionary dictionary];
            for (DSCurrencyPriceObject *priceObject in prices) {
                pricesByCode[priceObject.code] = priceObject;
                plainPricesByCode[priceObject.code] = priceObject.price;
            }

            strongSelf.lastPriceSourceInfo = priceSource;

            [[NSUserDefaults standardUserDefaults] setObject:plainPricesByCode forKey:PRICESBYCODE_KEY];

            strongSelf.prices = [strongSelf.class sortPrices:prices usingDictionary:pricesByCode];
            strongSelf.pricesByCode = pricesByCode;
            strongSelf.localCurrencyCode = strongSelf->_localCurrencyCode; // update localCurrencyPrice and localFormat.maximum
        }
    }];
    [self.operationQueue addOperation:priceOperation];
}

- (DSCurrencyPriceObject *)priceForCurrencyCode:(NSString *)code {
    NSParameterAssert(code);

    if (!code) {
        return nil;
    }
    return self.pricesByCode[code];
}

// MARK: - string helpers

- (int64_t)amountForUnknownCurrencyString:(NSString *)string {
    NSParameterAssert(string);

    if (!string.length) return 0;
    return [[[NSDecimalNumber decimalNumberWithString:string]
        decimalNumberByMultiplyingByPowerOf10:self.unknownFormat.maximumFractionDigits] longLongValue];
}

- (int64_t)amountForDashString:(NSString *)string {
    NSParameterAssert(string);

    if (!string.length) return 0;
    NSInteger dashCharPos = [string indexOfCharacter:NSAttachmentCharacter];
    if (dashCharPos != NSNotFound) {
        string = [string stringByReplacingCharactersInRange:NSMakeRange(dashCharPos, 1) withString:DASH];
    }
    return [[[NSDecimalNumber decimalNumberWithDecimal:[[self.dashFormat numberFromString:string] decimalValue]]
        decimalNumberByMultiplyingByPowerOf10:self.dashFormat.maximumFractionDigits] longLongValue];
}

- (int64_t)amountForBitcoinString:(NSString *)string {
    NSParameterAssert(string);

    if (!string.length) return 0;
    return [[[NSDecimalNumber decimalNumberWithDecimal:[[self.bitcoinFormat numberFromString:string] decimalValue]]
        decimalNumberByMultiplyingByPowerOf10:self.bitcoinFormat.maximumFractionDigits] longLongValue];
}

- (NSAttributedString *)attributedStringForDashAmount:(int64_t)amount {
    NSString *string = [self.dashFormat stringFromNumber:[(id)[NSDecimalNumber numberWithLongLong:amount]
                                                             decimalNumberByMultiplyingByPowerOf10:-self.dashFormat.maximumFractionDigits]];
    return [string attributedStringForDashSymbol];
}

- (NSAttributedString *)attributedStringForDashAmount:(int64_t)amount withTintColor:(UIColor *)color {
    NSParameterAssert(color);

    NSString *string = [self.dashFormat stringFromNumber:[(id)[NSDecimalNumber numberWithLongLong:amount]
                                                             decimalNumberByMultiplyingByPowerOf10:-self.dashFormat.maximumFractionDigits]];
    return [string attributedStringForDashSymbolWithTintColor:color];
}

- (NSAttributedString *)attributedStringForDashAmount:(int64_t)amount withTintColor:(UIColor *)color useSignificantDigits:(BOOL)useSignificantDigits {
    NSParameterAssert(color);

    NSString *string = [(useSignificantDigits ? self.dashSignificantFormat : self.dashFormat) stringFromNumber:[(id)[NSDecimalNumber numberWithLongLong:amount]
                                                                                                                   decimalNumberByMultiplyingByPowerOf10:-self.dashFormat.maximumFractionDigits]];
    return [string attributedStringForDashSymbolWithTintColor:color];
}

- (NSAttributedString *)attributedStringForDashAmount:(int64_t)amount withTintColor:(UIColor *)color dashSymbolSize:(CGSize)dashSymbolSize {
    NSParameterAssert(color);

    NSString *string = [self.dashFormat stringFromNumber:[(id)[NSDecimalNumber numberWithLongLong:amount]
                                                             decimalNumberByMultiplyingByPowerOf10:-self.dashFormat.maximumFractionDigits]];
    return [string attributedStringForDashSymbolWithTintColor:color dashSymbolSize:dashSymbolSize];
}

- (NSNumber *)numberForAmount:(int64_t)amount {
    return (id)[(id)[NSDecimalNumber numberWithLongLong:amount]
        decimalNumberByMultiplyingByPowerOf10:-self.dashFormat.maximumFractionDigits];
}

- (NSString *)stringForBitcoinAmount:(int64_t)amount {
    return [self.bitcoinFormat stringFromNumber:[(id)[NSDecimalNumber numberWithLongLong:amount]
                                                    decimalNumberByMultiplyingByPowerOf10:-self.bitcoinFormat.maximumFractionDigits]];
}

- (NSString *)stringForDashAmount:(int64_t)amount {
    return [self.dashFormat stringFromNumber:[(id)[NSDecimalNumber numberWithLongLong:amount]
                                                 decimalNumberByMultiplyingByPowerOf10:-self.dashFormat.maximumFractionDigits]];
}

// NOTE: For now these local currency methods assume that a satoshi has a smaller value than the smallest unit of any
// local currency. They will need to be revisited when that is no longer a safe assumption.
- (int64_t)amountForLocalCurrencyString:(NSString *)string {
    NSParameterAssert(string);

    if ([string hasPrefix:@"<"]) string = [string substringFromIndex:1];

    NSNumber *n = [self.localFormat numberFromString:string];
    int64_t price = [[NSDecimalNumber decimalNumberWithDecimal:self.localCurrencyDashPrice.decimalValue]
                decimalNumberByMultiplyingByPowerOf10:self.localFormat.maximumFractionDigits]
                        .longLongValue,
            local = [[NSDecimalNumber decimalNumberWithDecimal:n.decimalValue]
                decimalNumberByMultiplyingByPowerOf10:self.localFormat.maximumFractionDigits]
                        .longLongValue,
            overflowbits = 0, p = 10, min, max, amount;

    if (local == 0 || price < 1) return 0;
    while (llabs(local) + 1 > INT64_MAX / DUFFS) local /= 2, overflowbits++; // make sure we won't overflow an int64_t
    min = llabs(local) * DUFFS / price + 1;                                  // minimum amount that safely matches local currency string
    max = (llabs(local) + 1) * DUFFS / price - 1;                            // maximum amount that safely matches local currency string
    amount = (min + max) / 2;                                                // average min and max
    while (overflowbits > 0) local *= 2, min *= 2, max *= 2, amount *= 2, overflowbits--;

    if (amount >= MAX_MONEY) return (local < 0) ? -MAX_MONEY : MAX_MONEY;
    while ((amount / p) * p >= min && p <= INT64_MAX / 10) p *= 10; // lowest decimal precision matching local currency string
    p /= 10;
    return (local < 0) ? -(amount / p) * p : (amount / p) * p;
}

- (int64_t)amountForBitcoinCurrencyString:(NSString *)string {
    NSParameterAssert(string);

    if (self.bitcoinDashPrice.doubleValue <= DBL_EPSILON) return 0;
    if ([string hasPrefix:@"<"]) string = [string substringFromIndex:1];

    double price = self.bitcoinDashPrice.doubleValue * pow(10.0, self.bitcoinFormat.maximumFractionDigits),
           amt = [[self.bitcoinFormat numberFromString:string] doubleValue] *
                 pow(10.0, self.bitcoinFormat.maximumFractionDigits);
    int64_t local = amt + DBL_EPSILON * amt, overflowbits = 0;

    if (local == 0) return 0;
    while (llabs(local) + 1 > INT64_MAX / DUFFS) local /= 2, overflowbits++; // make sure we won't overflow an int64_t
    int64_t min = llabs(local) * DUFFS / (int64_t)(price + DBL_EPSILON * price) + 1,
            max = (llabs(local) + 1) * DUFFS / (int64_t)(price + DBL_EPSILON * price) - 1,
            amount = (min + max) / 2, p = 10;

    while (overflowbits > 0) local *= 2, min *= 2, max *= 2, amount *= 2, overflowbits--;

    if (amount >= MAX_MONEY) return (local < 0) ? -MAX_MONEY : MAX_MONEY;
    while ((amount / p) * p >= min && p <= INT64_MAX / 10) p *= 10; // lowest decimal precision matching local currency string
    p /= 10;
    return (local < 0) ? -(amount / p) * p : (amount / p) * p;
}

- (NSString *)bitcoinCurrencyStringForAmount:(int64_t)amount {
    if (amount == 0) return [self.bitcoinFormat stringFromNumber:@(0)];


    NSDecimalNumber *n = [[[NSDecimalNumber decimalNumberWithDecimal:self.bitcoinDashPrice.decimalValue]
                        decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithLongLong:llabs(amount)]]
                        decimalNumberByDividingBy:(id)[NSDecimalNumber numberWithLongLong:DUFFS]],
                    *min = [[NSDecimalNumber one]
                        decimalNumberByMultiplyingByPowerOf10:-self.bitcoinFormat.maximumFractionDigits];

    // if the amount is too small to be represented in local currency (but is != 0) then return a string like "$0.01"
    if ([n compare:min] == NSOrderedAscending) n = min;
    if (amount < 0) n = [n decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithInt:-1]];
    return [self.bitcoinFormat stringFromNumber:n];
}

- (NSString *)localCurrencyStringForDashAmount:(int64_t)amount {
    NSNumber *n = [self localCurrencyNumberForDashAmount:amount];
    if (n == nil) {
        return DSLocalizedString(@"Updating Price", @"Updating Price");
    }
    return [self.localFormat stringFromNumber:n];
}

- (NSString *)fiatCurrencyString:(NSString *)currencyCode forDashAmount:(int64_t)amount {
    NSParameterAssert(currencyCode);

    NSNumber *n = [self fiatCurrencyNumber:currencyCode forDashAmount:amount];
    if (n == nil) {
        return DSLocalizedString(@"Updating Price", @"Updating Price");
    }
    return [self.localFormat stringFromNumber:n];
}

- (NSString *)localCurrencyStringForBitcoinAmount:(int64_t)amount {
    if (amount == 0) return [self.localFormat stringFromNumber:@(0)];
    if (self.localCurrencyBitcoinPrice.doubleValue <= DBL_EPSILON) return @""; // no exchange rate data

    NSDecimalNumber *n = [[[NSDecimalNumber decimalNumberWithDecimal:self.localCurrencyBitcoinPrice.decimalValue]
                        decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithLongLong:llabs(amount)]]
                        decimalNumberByDividingBy:(id)[NSDecimalNumber numberWithLongLong:DUFFS]],
                    *min = [[NSDecimalNumber one]
                        decimalNumberByMultiplyingByPowerOf10:-self.localFormat.maximumFractionDigits];

    // if the amount is too small to be represented in local currency (but is != 0) then return a string like "$0.01"
    if ([n compare:min] == NSOrderedAscending) n = min;
    if (amount < 0) n = [n decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithInt:-1]];
    return [self.localFormat stringFromNumber:n];
}

- (NSNumber *_Nullable)localCurrencyNumberForDashAmount:(int64_t)amount {
    if (amount == 0) {
        return @0;
    }

    if (self.localCurrencyDashPrice == nil) {
        return nil;
    }

    NSNumber *local = self.localCurrencyDashPrice;

    NSDecimalNumber *n = [[[NSDecimalNumber decimalNumberWithDecimal:local.decimalValue]
                        decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithLongLong:llabs(amount)]]
                        decimalNumberByDividingBy:(id)[NSDecimalNumber numberWithLongLong:DUFFS]],
                    *min = [[NSDecimalNumber one]
                        decimalNumberByMultiplyingByPowerOf10:-self.localFormat.maximumFractionDigits];

    // if the amount is too small to be represented in local currency (but is != 0) then return a string like "$0.01"
    if ([n compare:min] == NSOrderedAscending) n = min;
    if (amount < 0) n = [n decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithInt:-1]];
    return n;
}

- (NSNumber *_Nullable)fiatCurrencyNumber:(NSString *)currencyCode forDashAmount:(int64_t)amount {
    if (amount == 0) {
        return @0;
    }

    float price;

    if ([self.pricesByCode objectForKey:currencyCode] && [DSAuthenticationManager sharedInstance].secureTime + 3 * DAY_TIME_INTERVAL > [NSDate timeIntervalSince1970]) {
        DSCurrencyPriceObject *priceObject = self.pricesByCode[currencyCode];
        price = [priceObject.price floatValue]; // don't use exchange rate data more than 72hrs out of date
    } else {
        price = 0;
    }

    NSDecimalNumber *n = [[[NSDecimalNumber decimalNumberWithDecimal:@(price).decimalValue]
                        decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithLongLong:llabs(amount)]]
                        decimalNumberByDividingBy:(id)[NSDecimalNumber numberWithLongLong:DUFFS]],
                    *min = [[NSDecimalNumber one]
                        decimalNumberByMultiplyingByPowerOf10:-self.localFormat.maximumFractionDigits];

    // if the amount is too small to be represented in local currency (but is != 0) then return a string like "$0.01"
    if ([n compare:min] == NSOrderedAscending) n = min;
    if (amount < 0) n = [n decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithInt:-1]];
    return n;
}

// MARK: - floating fees

- (void)updateFeePerKb {
    if (self.reachability.networkReachabilityStatus == DSReachabilityStatusNotReachable) return;

#if (!!FEE_PER_KB_URL)

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:FEE_PER_KB_URL]
                                                       cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                   timeoutInterval:10.0];

    //    DSLogPrivate(@"%@", req.URL.absoluteString);

    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                         if (error != nil) {
                                             DSLog(@"unable to fetch fee-per-kb: %@", error);
                                             return;
                                         }

                                         NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

                                         if (error || ![json isKindOfClass:[NSDictionary class]] ||
                                             ![json[@"fee_per_kb"] isKindOfClass:[NSNumber class]]) {
                                             DSLogPrivate(@"unexpected response from %@:\n%@", req.URL.host,
                                                 [[NSString alloc] initWithData:data
                                                                       encoding:NSUTF8StringEncoding]);
                                             return;
                                         }

                                         uint64_t newFee = [json[@"fee_per_kb"] unsignedLongLongValue];
                                         NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

                                         if (newFee >= MIN_FEE_PER_KB && newFee <= MAX_FEE_PER_KB && newFee != [defs doubleForKey:FEE_PER_KB_KEY]) {
                                             DSLog(@"setting new fee-per-kb %lld", newFee);
                                             [defs setDouble:newFee forKey:FEE_PER_KB_KEY]; // use setDouble since setInteger won't hold a uint64_t
                                             _wallet.feePerKb = newFee;
                                         }
                                     }] resume];

#else
    return;
#endif
}

+ (NSArray<DSCurrencyPriceObject *> *)sortPrices:(NSArray<DSCurrencyPriceObject *> *)prices
                                 usingDictionary:(NSMutableDictionary<NSString *, DSCurrencyPriceObject *> *)pricesByCode {
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"code" ascending:YES];
    NSMutableArray<DSCurrencyPriceObject *> *mutablePrices = [[prices sortedArrayUsingDescriptors:@[sortDescriptor]] mutableCopy];
    // move USD and EUR to the top of the prices list
    DSCurrencyPriceObject *eurPriceObject = pricesByCode[@"EUR"];
    if (eurPriceObject) {
        [mutablePrices removeObject:eurPriceObject];
        [mutablePrices insertObject:eurPriceObject atIndex:0];
    }
    DSCurrencyPriceObject *usdPriceObject = pricesByCode[DEFAULT_CURRENCY_CODE];
    if (usdPriceObject) {
        [mutablePrices removeObject:usdPriceObject];
        [mutablePrices insertObject:usdPriceObject atIndex:0];
    }

    return [mutablePrices copy];
}

@end
