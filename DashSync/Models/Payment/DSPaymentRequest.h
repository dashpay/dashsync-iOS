//
//  DSPaymentRequest.h
//  DashSync
//
//  Created by Aaron Voisine for BreadWallet on 5/9/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
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

@class DSPaymentProtocolRequest, DSPaymentProtocolPayment, DSPaymentProtocolACK, DSChain, DSBlockchainIdentity, DSAccount;

// BIP21 bitcoin payment request URI https://github.com/bitcoin/bips/blob/master/bip-0021.mediawiki
@interface DSPaymentRequest : NSObject

@property (nonatomic, strong, nullable) NSString *scheme;
@property (nonatomic, strong, nullable) NSString *paymentAddress;
@property (nonatomic, strong, nullable) NSString *label;
@property (nonatomic, strong, nullable) NSString *message;
@property (nonatomic, strong, nullable) NSString *dashpayUsername;
@property (nonatomic, assign) uint64_t amount;
@property (nonatomic, strong, nullable) NSString *r; // BIP72 URI: https://github.com/bitcoin/bips/blob/master/bip-0072.mediawiki
@property (nonatomic, strong, nullable) NSString *string;
@property (nonatomic, strong, nullable) NSString *callbackScheme;
@property (nonatomic, strong, nullable) NSData *data;
@property (nonatomic, strong, nullable) NSURL *url;
@property (nonatomic, strong, nullable) NSString *requestedFiatCurrencyCode;
@property (nonatomic, assign) float requestedFiatCurrencyAmount;
@property (nonatomic, readonly) BOOL isValidAsNonDashpayPaymentRequest;
@property (nonatomic, readonly) BOOL amountValueImmutable;
@property (nonatomic, readonly) DSPaymentProtocolRequest *protocolRequest;
@property (nonatomic, readonly) DSChain *chain;

+ (instancetype)requestWithString:(NSString *)string onChain:(DSChain *)chain;
+ (instancetype)requestWithData:(NSData *)data onChain:(DSChain *)chain;
+ (instancetype)requestWithURL:(NSURL *)url onChain:(DSChain *)chain;

- (instancetype)initWithString:(NSString *)string onChain:(DSChain *)chain;
- (instancetype)initWithData:(NSData *)data onChain:(DSChain *)chain;
- (instancetype)initWithURL:(NSURL *)url onChain:(DSChain *)chain;

- (DSPaymentProtocolRequest *)protocolRequestForBlockchainIdentity:(DSBlockchainIdentity *_Nullable)blockchainIdentity onAccount:(DSAccount *)account inContext:(NSManagedObjectContext *)context;

- (BOOL)isValidAsDashpayPaymentRequestForBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity onAccount:(DSAccount *)account inContext:(NSManagedObjectContext *)context;

- (NSString *)paymentAddressForBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity onAccount:(DSAccount *)account fallbackToPaymentAddressIfIssue:(BOOL)fallbackToPaymentAddressIfIssue inContext:(NSManagedObjectContext *)context;

// fetches a BIP70 request over HTTP and calls completion block
// https://github.com/bitcoin/bips/blob/master/bip-0070.mediawiki
+ (void)fetch:(NSString *)url scheme:(NSString *)scheme onChain:(DSChain *)chain timeout:(NSTimeInterval)timeout
    completion:(void (^)(DSPaymentProtocolRequest *req, NSError *error))completion;

// posts a BIP70 payment object to the specified URL
+ (void)postPayment:(DSPaymentProtocolPayment *)payment scheme:(NSString *)scheme to:(NSString *)paymentURL onChain:(DSChain *)chain
            timeout:(NSTimeInterval)timeout
         completion:(void (^)(DSPaymentProtocolACK *ack, NSError *error))completion;

@end


NS_ASSUME_NONNULL_END
