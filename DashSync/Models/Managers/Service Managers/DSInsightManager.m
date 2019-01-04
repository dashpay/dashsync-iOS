//
//  DSInsightManager.m
//  DashSync
//
//  Created by Sam Westrich on 7/20/18.
//

#import "DSInsightManager.h"
#import "DSChain.h"
#import "NSString+Dash.h"
#import "NSData+Bitcoin.h"
#import "NSString+Bitcoin.h"

#define UNSPENT_URL          @"http://insight.dash.org/insight-api-dash/addrs/utxo"
#define UNSPENT_FAILOVER_URL @"https://insight.dash.siampm.com/api/addrs/utxo"

@implementation DSInsightManager

+ (instancetype)sharedInstance
{
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });
    
    return singleton;
}

// MARK: - query unspent outputs

// queries api.breadwallet.com and calls the completion block with unspent outputs for the given addresses
- (void)utxosForAddresses:(NSArray *)addresses
               completion:(void (^)(NSArray *utxos, NSArray *amounts, NSArray *scripts, NSError *error))completion
{
    [self utxos:UNSPENT_URL forAddresses:addresses
     completion:^(NSArray *utxos, NSArray *amounts, NSArray *scripts, NSError *error) {
         if (error) {
             [self utxos:UNSPENT_FAILOVER_URL forAddresses:addresses
              completion:^(NSArray *utxos, NSArray *amounts, NSArray *scripts, NSError *err) {
                  if (err) err = error;
                  completion(utxos, amounts, scripts, err);
              }];
         }
         else completion(utxos, amounts, scripts, error);
     }];
}

- (void)utxos:(NSString *)unspentURL forAddresses:(NSArray *)addresses
   completion:(void (^)(NSArray *utxos, NSArray *amounts, NSArray *scripts, NSError *error))completion
{
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:unspentURL]
                                                       cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0];
    NSMutableArray *args = [NSMutableArray array];
    NSMutableCharacterSet *charset = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    
    [charset removeCharactersInString:@"&="];
    [args addObject:[@"addrs=" stringByAppendingString:[[addresses componentsJoinedByString:@","]
                                                        stringByAddingPercentEncodingWithAllowedCharacters:charset]]];
    req.HTTPMethod = @"POST";
    req.HTTPBody = [[args componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
    DSDLog(@"%@ POST: %@", req.URL.absoluteString,
          [[NSString alloc] initWithData:req.HTTPBody encoding:NSUTF8StringEncoding]);
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                         if (error) {
                                             completion(nil, nil, nil, error);
                                             return;
                                         }
                                         
                                         NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                         NSMutableArray *utxos = [NSMutableArray array], *amounts = [NSMutableArray array],
                                         *scripts = [NSMutableArray array];
                                         DSUTXO o;
                                         
                                         if (error || ! [json isKindOfClass:[NSArray class]]) {
                                             DSDLog(@"Error decoding response %@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                             completion(nil, nil, nil,
                                                        [NSError errorWithDomain:@"DashSync" code:417 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                                       [NSString stringWithFormat:DSLocalizedString(@"unexpected response from %@", nil),
                                                                                                                        req.URL.host]}]);
                                             return;
                                         }
                                         
                                         for (NSDictionary *utxo in json) {
                                             
                                             NSDecimalNumber * amount = nil;
                                             if (utxo[@"amount"]) {
                                                 if ([utxo[@"amount"] isKindOfClass:[NSString class]]) {
                                                     amount = [NSDecimalNumber decimalNumberWithString:utxo[@"amount"]];
                                                 } else if ([utxo[@"amount"] isKindOfClass:[NSDecimalNumber class]]) {
                                                     amount = utxo[@"amount"];
                                                 } else if ([utxo[@"amount"] isKindOfClass:[NSNumber class]]) {
                                                     amount = [NSDecimalNumber decimalNumberWithDecimal:[utxo[@"amount"] decimalValue]];
                                                 }
                                             }
                                             if (! [utxo isKindOfClass:[NSDictionary class]] ||
                                                 ! [utxo[@"txid"] isKindOfClass:[NSString class]] ||
                                                 [utxo[@"txid"] hexToData].length != sizeof(UInt256) ||
                                                 ! [utxo[@"vout"] isKindOfClass:[NSNumber class]] ||
                                                 ! [utxo[@"scriptPubKey"] isKindOfClass:[NSString class]] ||
                                                 ! [utxo[@"scriptPubKey"] hexToData] ||
                                                 (! [utxo[@"duffs"] isKindOfClass:[NSNumber class]] && ! [utxo[@"satoshis"] isKindOfClass:[NSNumber class]] && !amount)) {
                                                 completion(nil, nil, nil,
                                                            [NSError errorWithDomain:@"DashSync" code:417 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                                           [NSString stringWithFormat:DSLocalizedString(@"unexpected response from %@", nil),
                                                                                                                            req.URL.host]}]);
                                                 return;
                                             }
                                             
                                             o.hash = *(const UInt256 *)[utxo[@"txid"] hexToData].reverse.bytes;
                                             o.n = [utxo[@"vout"] unsignedIntValue];
                                             [utxos addObject:dsutxo_obj(o)];
                                             if (amount) {
                                                 [amounts addObject:[amount decimalNumberByMultiplyingByPowerOf10:8]];
                                             } else if (utxo[@"duffs"]) {
                                                 [amounts addObject:utxo[@"duffs"]];
                                             }  else if (utxo[@"satoshis"]) {
                                                 [amounts addObject:utxo[@"satoshis"]];
                                             }
                                             [scripts addObject:[utxo[@"scriptPubKey"] hexToData]];
                                         }
                                         
                                         completion(utxos, amounts, scripts, nil);
                                     }] resume];
}


@end
