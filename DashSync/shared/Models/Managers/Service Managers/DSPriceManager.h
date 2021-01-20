//
//  DSPriceManager.h
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define DASH @"DASH"                // capital D with stroke (utf-8)
#define BTC @"\xC9\x83"             // capital B with stroke (utf-8)
#define BITS @"\xC6\x80"            // lowercase b with stroke (utf-8)
#define DITS @"mDASH"               // lowercase d with stroke (utf-8)
#define NARROW_NBSP @"\xE2\x80\xAF" // narrow no-break space (utf-8)
#define LDQUOTE @"\xE2\x80\x9C"     // left double quote (utf-8)
#define RDQUOTE @"\xE2\x80\x9D"     // right double quote (utf-8)
#define DISPLAY_NAME [NSString stringWithFormat:LDQUOTE @"%@" RDQUOTE, \
                               NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"]]

#define FEE_PER_KB_URL 0 //not supported @"https://api.breadwallet.com/fee-per-kb"

@class DSCurrencyPriceObject;

@interface DSPriceManager : NSObject

@property (nonatomic, readonly) NSNumberFormatter *dashFormat;                                      // dash currency formatter
@property (nonatomic, readonly) NSNumberFormatter *dashSignificantFormat;                           // dash currency formatter that shows significant digits
@property (nonatomic, readonly) NSNumberFormatter *bitcoinFormat;                                   // bitcoin currency formatter
@property (nonatomic, readonly) NSNumberFormatter *unknownFormat;                                   // unknown currency formatter
@property (nonatomic, readonly) NSNumberFormatter *localFormat;                                     // local currency formatter
@property (nonatomic, copy) NSString *localCurrencyCode;                                            // local currency ISO code
@property (nonatomic, readonly) NSNumber *bitcoinDashPrice DEPRECATED_ATTRIBUTE;                    // exchange rate in bitcoin per dash
@property (nullable, nonatomic, readonly) NSNumber *localCurrencyBitcoinPrice DEPRECATED_ATTRIBUTE; // exchange rate in local currency units per bitcoin
@property (nullable, nonatomic, readonly) NSNumber *localCurrencyDashPrice;
@property (readonly, copy, nonatomic) NSDictionary<NSString *, NSString *> *currenciesByCode;
@property (nullable, readonly, copy, nonatomic) NSArray<DSCurrencyPriceObject *> *prices;
@property (nullable, readonly, nonatomic, copy) NSString *lastPriceSourceInfo;

+ (instancetype)sharedInstance;

- (void)startExchangeRateFetching;

- (DSCurrencyPriceObject *_Nullable)priceForCurrencyCode:(NSString *)code;

- (int64_t)amountForUnknownCurrencyString:(NSString *)string;
- (int64_t)amountForDashString:(NSString *)string;
- (int64_t)amountForBitcoinString:(NSString *)string DEPRECATED_ATTRIBUTE;
- (NSAttributedString *_Nullable)attributedStringForDashAmount:(int64_t)amount;
- (NSAttributedString *_Nullable)attributedStringForDashAmount:(int64_t)amount withTintColor:(UIColor *)color;
- (NSAttributedString *_Nullable)attributedStringForDashAmount:(int64_t)amount withTintColor:(UIColor *)color useSignificantDigits:(BOOL)useSignificantDigits;
- (NSAttributedString *_Nullable)attributedStringForDashAmount:(int64_t)amount withTintColor:(UIColor *)color dashSymbolSize:(CGSize)dashSymbolSize;
- (NSNumber *)numberForAmount:(int64_t)amount;
- (NSString *_Nullable)stringForBitcoinAmount:(int64_t)amount;
- (NSString *_Nullable)stringForDashAmount:(int64_t)amount;
- (int64_t)amountForBitcoinCurrencyString:(NSString *)string DEPRECATED_ATTRIBUTE;
- (int64_t)amountForLocalCurrencyString:(NSString *)string;
- (NSString *_Nullable)bitcoinCurrencyStringForAmount:(int64_t)amount DEPRECATED_ATTRIBUTE;
- (NSString *_Nullable)localCurrencyStringForDashAmount:(int64_t)amount;
- (NSString *_Nullable)fiatCurrencyString:(NSString *)currencyCode forDashAmount:(int64_t)amount;
- (NSString *_Nullable)localCurrencyStringForBitcoinAmount:(int64_t)amount DEPRECATED_ATTRIBUTE;
- (NSNumber *_Nullable)localCurrencyNumberForDashAmount:(int64_t)amount;

@end

NS_ASSUME_NONNULL_END
