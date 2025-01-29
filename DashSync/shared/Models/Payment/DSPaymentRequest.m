//
//  DSPaymentRequest.m
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

#import "DSPaymentRequest.h"
#import "DSAccount.h"
#import "DSIdentity.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSChain+Params.h"
#import "DSCurrencyPriceObject.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSKeyManager.h"
#import "DSPaymentProtocol.h"
#import "DSPriceManager.h"
#import "NSError+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"
#import "NSString+Dash.h"

@interface DSPaymentRequest ()

@property (nonatomic, strong) DSChain *chain;

@end

// BIP21 bitcoin URI object https://github.com/bitcoin/bips/blob/master/bip-0021.mediawiki
@implementation DSPaymentRequest

+ (instancetype)requestWithString:(NSString *)string onChain:(DSChain *)chain {
    return [[self alloc] initWithString:string onChain:chain];
}

+ (instancetype)requestWithData:(NSData *)data onChain:(DSChain *)chain {
    return [[self alloc] initWithData:data onChain:chain];
}

+ (instancetype)requestWithURL:(NSURL *)url onChain:(DSChain *)chain {
    return [[self alloc] initWithURL:url onChain:chain];
}

- (instancetype)initWithString:(NSString *)string onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;
    self.chain = chain;
    self.string = string;
    return self;
}

- (instancetype)initWithData:(NSData *)data onChain:(DSChain *)chain {
    return [self initWithString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] onChain:chain];
}

- (instancetype)initWithURL:(NSURL *)url onChain:(DSChain *)chain {
    return [self initWithString:url.absoluteString onChain:chain];
}

- (void)setString:(NSString *)string {
    self.scheme = nil;
    self.paymentAddress = nil;
    self.label = nil;
    self.message = nil;
    self.amount = 0;
    self.callbackScheme = nil;
    self.r = nil;

    if (string.length == 0) return;

    NSString *s = [[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        stringByReplacingOccurrencesOfString:@" "
                                  withString:@"%20"];
    NSURL *url = [NSURL URLWithString:s];

    if (!url || !url.scheme) {
        
        if (dash_spv_crypto_bip_bip38_is_valid_payment_request_address((char *)[s UTF8String], self.chain.chainType)) {
//        if ([DSKeyManager isValidDashAddress:s forChain:self.chain] ||
//            [s isValidDashPrivateKeyOnChain:self.chain] ||
//            [DSKeyManager isValidDashBIP38Key:s]) {
            url = [NSURL URLWithString:[NSString stringWithFormat:@"dash://%@", s]];
            self.scheme = @"dash";
        }
#if SHAPESHIFT_ENABLED
        else if ([s isValidBitcoinAddressOnChain:self.chain] || [s isValidBitcoinPrivateKeyOnChain:self.chain]) {
            url = [NSURL URLWithString:[NSString stringWithFormat:@"bitcoin://%@", s]];
            self.scheme = @"bitcoin";
        }
#endif
    } else if (!url.host && url.resourceSpecifier) {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", url.scheme, url.resourceSpecifier]];
        self.scheme = url.scheme;
    } else if (url.scheme) {
        self.scheme = url.scheme;
    } else {
        self.scheme = @"dash";
    }

    if ([url.scheme isEqualToString:@"dash"] || [url.scheme isEqualToString:@"bitcoin"]) {
        self.paymentAddress = url.host;

        //TODO: correctly handle unknown but required url arguments (by reporting the request invalid)
        for (NSString *arg in [url.query componentsSeparatedByString:@"&"]) {
            NSArray *pair = [arg componentsSeparatedByString:@"="]; // if more than one '=', then pair[1] != value

            if (pair.count < 2) continue;

            NSString *value = [[[arg substringFromIndex:[pair[0] length] + 1]
                stringByReplacingOccurrencesOfString:@"+"
                                          withString:@" "]
                stringByRemovingPercentEncoding];

            BOOL require = FALSE;
            NSString *key = pair[0];
            if ([key hasPrefix:@"req-"] && key.length > 4) {
                key = [key substringFromIndex:4];
                require = TRUE;
            }

            if ([key isEqual:@"amount"]) {
                NSDecimal dec, amount;

                if ([[NSScanner scannerWithString:value] scanDecimal:&dec]) {
                    NSDecimalMultiplyByPowerOf10(&amount, &dec, 8, NSRoundUp);
                    self.amount = [NSDecimalNumber decimalNumberWithDecimal:amount].unsignedLongLongValue;
                }
                if (require)
                    _amountValueImmutable = TRUE;
            } else if ([key isEqual:@"label"]) {
                self.label = value;
            } else if ([key isEqual:@"sender"]) {
                self.callbackScheme = value;
            } else if ([key isEqual:@"message"]) {
                self.message = value;
            } else if ([key isEqual:@"r"]) {
                self.r = value;
            } else if ([key isEqual:@"currency"]) {
                self.requestedFiatCurrencyCode = value;
            } else if ([key isEqual:@"local"]) {
                self.requestedFiatCurrencyAmount = [value floatValue];
            } else if ([key isEqual:@"user"]) {
                self.dashpayUsername = value;
            }
        }
    } else if (url)
        self.r = s; // BIP73 url: https://github.com/bitcoin/bips/blob/master/bip-0073.mediawiki
}

- (NSString *)string {
    if (!([self.scheme isEqual:@"bitcoin"] || [self.scheme isEqual:@"dash"])) return self.r;

    NSMutableString *s = [NSMutableString stringWithFormat:@"%@:", self.scheme];
    NSMutableArray *q = [NSMutableArray array];
    NSMutableCharacterSet *charset = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];

    [charset removeCharactersInString:@"&="];
    if (self.paymentAddress) [s appendString:self.paymentAddress];

    if (self.amount > 0) {
        [q addObject:[@"amount=" stringByAppendingString:[(id)[NSDecimalNumber numberWithUnsignedLongLong:self.amount]
                                                             decimalNumberByMultiplyingByPowerOf10:-8]
                                                             .stringValue]];
    }

    if (self.label.length > 0) {
        [q addObject:[@"label=" stringByAppendingString:[self.label
                                                            stringByAddingPercentEncodingWithAllowedCharacters:charset]]];
    }

    if (self.message.length > 0) {
        [q addObject:[@"message=" stringByAppendingString:[self.message
                                                              stringByAddingPercentEncodingWithAllowedCharacters:charset]]];
    }

    if (self.r.length > 0) {
        [q addObject:[@"r=" stringByAppendingString:[self.r
                                                        stringByAddingPercentEncodingWithAllowedCharacters:charset]]];
    }

    if (self.requestedFiatCurrencyCode.length > 0) {
        [q addObject:[@"currency=" stringByAppendingString:[self.requestedFiatCurrencyCode stringByAddingPercentEncodingWithAllowedCharacters:charset]]];

        if (self.requestedFiatCurrencyAmount > 0) {
            [q addObject:[NSString stringWithFormat:@"local=%.02f", self.requestedFiatCurrencyAmount]];
        }
    }

    if (self.dashpayUsername.length > 0) {
        [q addObject:[@"user=" stringByAppendingString:self.dashpayUsername]];
    }

    if (q.count > 0) {
        [s appendString:@"?"];
        [s appendString:[q componentsJoinedByString:@"&"]];
    }

    return s;
}

- (void)setData:(NSData *)data {
    self.string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSData *)data {
    return [self.string dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)setUrl:(NSURL *)url {
    self.string = url.absoluteString;
}

- (NSURL *)url {
    return [NSURL URLWithString:self.string];
}

- (BOOL)isValidAsNonDashpayPaymentRequest {
    if ([self.scheme isEqualToString:@"dash"]) {
        BOOL valid = [DSKeyManager isValidDashAddress:self.paymentAddress forChain:self.chain] || (self.r && [NSURL URLWithString:self.r]);
        if (!valid) {
            DSLog(@"Not a valid dash request");
        }
        return valid;
    }
#if SHAPESHIFT_ENABLED
    else if ([self.scheme isEqualToString:@"bitcoin"]) {
        BOOL valid = [self.paymentAddress isValidBitcoinAddressOnChain:self.chain] || (self.r && [NSURL URLWithString:self.r]);
        if (!valid) {
            DSLog(@"Not a valid bitcoin request");
        }
        return valid;
    }
#endif
    else {
        return NO;
    }
}

- (BOOL)isValidAsDashpayPaymentRequestForIdentity:(DSIdentity *)identity
                                                  onAccount:(DSAccount *)account
                                                  inContext:(NSManagedObjectContext *)context {
    if ([self.scheme isEqualToString:@"dash"]) {
        __block DSIncomingFundsDerivationPath *friendshipDerivationPath = nil;
        [context performBlockAndWait:^{
            DSDashpayUserEntity *dashpayUserEntity = [identity matchingDashpayUserInContext:context];

            for (DSFriendRequestEntity *friendRequest in dashpayUserEntity.incomingRequests) {
                if ([[friendRequest.sourceContact.associatedBlockchainIdentity.dashpayUsername stringValue] isEqualToString:self.dashpayUsername]) {
                    friendshipDerivationPath = [account derivationPathForFriendshipWithIdentifier:friendRequest.friendshipIdentifier];
                }
            }
        }];
        BOOL valid = [DSKeyManager isValidDashAddress:self.paymentAddress forChain:self.chain] || (self.r && [NSURL URLWithString:self.r]) || friendshipDerivationPath;
        if (!valid) {
            DSLog(@"Not a valid dash request");
        }
        return valid;
    }
#if SHAPESHIFT_ENABLED
    else if ([self.scheme isEqualToString:@"bitcoin"]) {
        BOOL valid = ([self.paymentAddress isValidBitcoinAddressOnChain:self.chain] || (self.r && [NSURL URLWithString:self.r])) ? YES : NO;
        if (!valid) {
            DSLog(@"Not a valid bitcoin request");
        }
        return valid;
    }
#endif
    else {
        return NO;
    }
}

- (NSString *)paymentAddressForIdentity:(DSIdentity *)identity
                                        onAccount:(DSAccount *)account
                  fallbackToPaymentAddressIfIssue:(BOOL)fallbackToPaymentAddressIfIssue
                                        inContext:(NSManagedObjectContext *)context {
    if (!identity || !self.dashpayUsername) {
        if (fallbackToPaymentAddressIfIssue) {
            return [self paymentAddress];
        } else {
            return nil;
        }
    }
    __block DSIncomingFundsDerivationPath *friendshipDerivationPath = nil;
    [context performBlockAndWait:^{
        DSDashpayUserEntity *dashpayUserEntity = [identity matchingDashpayUserInContext:context];

        for (DSFriendRequestEntity *friendRequest in dashpayUserEntity.incomingRequests) {
            if ([[friendRequest.sourceContact.associatedBlockchainIdentity.dashpayUsername stringValue] isEqualToString:self.dashpayUsername]) {
                friendshipDerivationPath = [account derivationPathForFriendshipWithIdentifier:friendRequest.friendshipIdentifier];
            }
        }
    }];


    if (!friendshipDerivationPath) {
        if (fallbackToPaymentAddressIfIssue) {
            return [self paymentAddress];
        } else {
            return nil;
        }
    }
    return friendshipDerivationPath.receiveAddress;
}

- (DSPaymentProtocolRequest *)protocolRequestForIdentity:(DSIdentity *)identity
                                                         onAccount:(DSAccount *)account
                                                         inContext:(NSManagedObjectContext *)context {
    if (!identity || !self.dashpayUsername) {
        return [self protocolRequest];
    }
    __block DSIncomingFundsDerivationPath *friendshipDerivationPath = nil;
    [context performBlockAndWait:^{
        DSDashpayUserEntity *dashpayUserEntity = [identity matchingDashpayUserInContext:context];

        for (DSFriendRequestEntity *friendRequest in dashpayUserEntity.incomingRequests) {
            if ([[friendRequest.sourceContact.associatedBlockchainIdentity.dashpayUsername stringValue] isEqualToString:self.dashpayUsername]) {
                friendshipDerivationPath = [account derivationPathForFriendshipWithIdentifier:friendRequest.friendshipIdentifier];
            }
        }
    }];


    if (!friendshipDerivationPath) {
        return [self protocolRequest];
    }
    NSData *label = [self.label dataUsingEncoding:NSUTF8StringEncoding];
    NSData *script = [DSKeyManager scriptPubKeyForAddress:friendshipDerivationPath.receiveAddress forChain:self.chain];

    if (script.length == 0) return nil;

    uint64_t sendingAmount = 0;
    BOOL useFiatPegging = NO;
    if (self.amount) {
        sendingAmount = self.amount;
    } else if (self.requestedFiatCurrencyCode) {
        DSCurrencyPriceObject *currencyPriceObject = [[DSPriceManager sharedInstance] priceForCurrencyCode:self.requestedFiatCurrencyCode];
        if (currencyPriceObject) {
            useFiatPegging = YES;
            sendingAmount = (uint64_t)[currencyPriceObject.price unsignedLongLongValue] * self.requestedFiatCurrencyAmount;
        }
    }

    DSPaymentProtocolDetails *details =
        [[DSPaymentProtocolDetails alloc] initWithOutputAmounts:@[@(sendingAmount)]
                                                  outputScripts:@[script]
                                                           time:0
                                                        expires:0
                                                           memo:self.message
                                                     paymentURL:nil
                                                   merchantData:nil
                                                        onChain:self.chain];
    DSPaymentProtocolRequest *request =
        [[DSPaymentProtocolRequest alloc] initWithVersion:1
                                                  pkiType:@"none"
                                                    certs:(label ? @[label] : nil)details:details
                                                signature:nil
                                                  onChain:self.chain
                                           callbackScheme:self.callbackScheme];

    return request;
}

// receiver converted to BIP70 request object
- (DSPaymentProtocolRequest *)protocolRequest {
    NSData *name = [self.label dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *script = [NSMutableData data];
    if ([DSKeyManager isValidDashAddress:self.paymentAddress forChain:self.chain]) {
        [script appendData:[DSKeyManager scriptPubKeyForAddress:self.paymentAddress forChain:self.chain]];
    }
#if SHAPESHIFT_ENABLED
    else if ([self.paymentAddress isValidBitcoinAddressOnChain:self.chain]) {
        [script appendBitcoinScriptPubKeyForAddress:self.paymentAddress forChain:self.chain];
    }
#endif
    if (script.length == 0) return nil;

    uint64_t sendingAmount = 0;
    BOOL useFiatPegging = NO;
    if (self.amount) {
        sendingAmount = self.amount;
    } else if (self.requestedFiatCurrencyCode) {
        DSCurrencyPriceObject *currencyPriceObject = [[DSPriceManager sharedInstance] priceForCurrencyCode:self.requestedFiatCurrencyCode];
        if (currencyPriceObject) {
            useFiatPegging = YES;
            sendingAmount = (uint64_t)[currencyPriceObject.price unsignedLongLongValue] * self.requestedFiatCurrencyAmount;
        }
    }

    DSPaymentProtocolDetails *details =
        [[DSPaymentProtocolDetails alloc] initWithOutputAmounts:@[@(sendingAmount)]
                                                  outputScripts:@[script]
                                                           time:0
                                                        expires:0
                                                           memo:self.message
                                                     paymentURL:nil
                                                   merchantData:nil
                                                        onChain:self.chain];
    DSPaymentProtocolRequest *request =
        [[DSPaymentProtocolRequest alloc] initWithVersion:1
                                                  pkiType:@"none"
                                                    certs:(name ? @[name] : nil)details:details
                                                signature:nil
                                                  onChain:self.chain
                                           callbackScheme:self.callbackScheme];

    return request;
}

- (void)fetchBIP70WithTimeout:(NSTimeInterval)timeout
                   completion:(void (^)(DSPaymentProtocolRequest *req, NSError *error))completion {
    [DSPaymentRequest fetch:self.r scheme:self.scheme callbackScheme:self.callbackScheme onChain:self.chain timeout:timeout completion:completion];
}

// fetches the request over HTTP and calls completion block
+ (void)fetch:(NSString *)url scheme:(NSString *)scheme callbackScheme:(NSString *)callbackScheme onChain:(DSChain *)chain timeout:(NSTimeInterval)timeout
        completion:(void (^)(DSPaymentProtocolRequest *req, NSError *error))completion {
    if (!completion) return;

    NSURL *u = [NSURL URLWithString:url];
    NSMutableURLRequest *req = (u) ? [NSMutableURLRequest requestWithURL:u
                                                             cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                         timeoutInterval:timeout] :
                                     nil;

    [req setValue:[NSString stringWithFormat:@"application/%@-paymentrequest", scheme] forHTTPHeaderField:@"Accept"];
    //  [req addValue:@"text/uri-list" forHTTPHeaderField:@"Accept"]; // breaks some BIP72 implementations, notably bitpay's

    if (!req) {
        completion(nil, [NSError errorWithCode:417 localizedDescriptionKey:@"Bad payment request URL"]);
        return;
    }

    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                         if (error) {
                                             completion(nil, error);
                                             return;
                                         }

                                         DSPaymentProtocolRequest *request = nil;

                                         if ([response.MIMEType.lowercaseString isEqual:[NSString stringWithFormat:@"application/%@-paymentrequest", scheme]] && data.length <= 50000) {
                                             request = [DSPaymentProtocolRequest requestWithData:data callbackScheme:callbackScheme onChain:chain];
                                         } else if ([response.MIMEType.lowercaseString isEqual:@"text/uri-list"] && data.length <= 50000) {
                                             for (NSString *url in [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
                                                      componentsSeparatedByString:@"\n"]) {
                                                 if (![url hasPrefix:@"#"]) { // skip comments
                                                     DSPaymentRequest *paymentRequest = [DSPaymentRequest requestWithString:url onChain:chain];
                                                     paymentRequest.callbackScheme = callbackScheme;
                                                     request = paymentRequest.protocolRequest; // use first url and ignore the rest
                                                     break;                                    //we only are looking for one
                                                 }
                                             }
                                         }

                                         if (!request) {
                                             DSLog(@"unexpected response from %@:\n%@", req.URL.host, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                             completion(nil, [NSError errorWithCode:417 descriptionKey:DSLocalizedFormat(@"Unexpected response from %@", nil, req.URL.host)]);
                                         } else if (![request.details.chain isEqual:chain]) {
                                             completion(nil, [NSError errorWithCode:417 descriptionKey:DSLocalizedFormat(@"Requested network \"%@\" not currently in use", nil, request.details.chain.networkName)]);
                                         } else
                                             completion(request, nil);
                                     }] resume];
}

+ (void)postPayment:(DSPaymentProtocolPayment *)payment scheme:(NSString *)scheme to:(NSString *)paymentURL onChain:(DSChain *)chain
            timeout:(NSTimeInterval)timeout
         completion:(void (^)(DSPaymentProtocolACK *ack, NSError *error))completion {
    NSURL *u = [NSURL URLWithString:paymentURL];
    NSMutableURLRequest *req = (u) ? [NSMutableURLRequest requestWithURL:u
                                                             cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                         timeoutInterval:timeout] :
                                     nil;

    if (!req) {
        if (completion) {
            completion(nil, [NSError errorWithCode:417 localizedDescriptionKey:@"Bad payment URL"]);
        }

        return;
    }

    [req setValue:[NSString stringWithFormat:@"application/%@-payment", scheme]
        forHTTPHeaderField:@"Content-Type"];
    [req addValue:[NSString stringWithFormat:@"application/%@-paymentack", scheme] forHTTPHeaderField:@"Accept"];
    req.HTTPMethod = @"POST";
    req.HTTPBody = payment.data;

    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                         if (error) {
                                             if (completion) completion(nil, error);
                                             return;
                                         }

                                         DSPaymentProtocolACK *ack = nil;

                                         if ([response.MIMEType.lowercaseString isEqual:[NSString stringWithFormat:@"application/%@-paymentack", scheme]] && data.length <= 50000) {
                                             ack = [DSPaymentProtocolACK ackWithData:data onChain:chain];
                                         }

                                         if (!ack) {
                                             DSLog(@"unexpected response from %@:\n%@", req.URL.host,
                                                 [[NSString alloc] initWithData:data
                                                                       encoding:NSUTF8StringEncoding]);
                                             if (completion) {
                                                 completion(nil, [NSError errorWithCode:417 descriptionKey:DSLocalizedFormat(@"Unexpected response from %@", nil, req.URL.host)]);
                                             }
                                         } else if (completion)
                                             completion(ack, nil);
                                     }] resume];
}

@end
