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
#import "DSTransactionFactory.h"

#define ADDRESS_UTXO_PATH @"addrs/utxo"
#define TX_PATH @"rawtx"

#define INSIGHT_URL          @"https://insight.dash.org/insight-api-dash"
#define INSIGHT_FAILOVER_URL @"https://insight.dash.show/api"

#define TESTNET_INSIGHT_URL @"https://testnet-insight.dashevo.org/insight-api-dash"

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

// queries insight.dash.org and calls the completion block with unspent outputs for the given addresses
- (void)utxosForAddresses:(NSArray *)addresses onChain:(DSChain*)chain 
               completion:(void (^)(NSArray *utxos, NSArray *amounts, NSArray *scripts, NSError *error))completion
{
    NSString * insightURL = [chain isMainnet]?INSIGHT_URL:TESTNET_INSIGHT_URL;
    [self utxos:insightURL forAddresses:addresses
     completion:^(NSArray *utxos, NSArray *amounts, NSArray *scripts, NSError *error) {
         if (error) {
             NSString * insightBackupURL = [chain isMainnet]?INSIGHT_FAILOVER_URL:TESTNET_INSIGHT_URL;
             [self utxos:insightBackupURL forAddresses:addresses
              completion:^(NSArray *utxos, NSArray *amounts, NSArray *scripts, NSError *err) {
                  if (err) err = error;
                  completion(utxos, amounts, scripts, err);
              }];
         }
         else completion(utxos, amounts, scripts, error);
     }];
}

-(void)queryInsightForTransactionWithHash:(UInt256)transactionHash onChain:(DSChain*)chain completion:(void (^)(DSTransaction * transaction, NSError *error))completion {
    NSString * insightURL = [chain isMainnet]?INSIGHT_URL:TESTNET_INSIGHT_URL;
    [self queryInsight:insightURL forTransactionWithHash:transactionHash onChain:chain completion:^(DSTransaction *transaction, NSError *error) {
         if (error) {
             NSString * insightBackupURL = [chain isMainnet]?INSIGHT_FAILOVER_URL:TESTNET_INSIGHT_URL;
              [self queryInsight:insightBackupURL forTransactionWithHash:transactionHash onChain:chain completion:^(DSTransaction *transaction, NSError *err) {
                  if (err) err = error;
                  completion(transaction, err);
              }];
         }
         else completion(transaction, error);
     }];
}

-(void)queryInsight:(NSString *)insightURL forTransactionWithHash:(UInt256)transactionHash onChain:(DSChain*)chain completion:(void (^)(DSTransaction * transaction, NSError *error))completion {
    
    NSString * path = [[insightURL stringByAppendingPathComponent:TX_PATH] stringByAppendingPathComponent:uint256_hex(transactionHash)];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]
                                                       cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0];
    req.HTTPMethod = @"GET";
    DSDLog(@"%@ GET: %@", req.URL.absoluteString,
           [[NSString alloc] initWithData:req.HTTPBody encoding:NSUTF8StringEncoding]);
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                         if (error) {
                                             completion(nil, error);
                                             return;
                                         }
                                         
                                         NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                         
                                         if (error) {
                                             DSDLog(@"Error decoding response %@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                             completion(nil,
                                                        [NSError errorWithDomain:@"DashSync" code:417 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                                     [NSString stringWithFormat:DSLocalizedString(@"unexpected response from %@", nil),
                                                                                                                      req.URL.host]}]);
                                             return;
                                         }
                                         NSString * rawTxString = json[@"rawtx"];
                                         NSData * rawTx = [rawTxString hexToData];
                                         DSTransaction * transaction = [DSTransactionFactory transactionWithMessage:rawTx
                                                                              onChain:chain];
                                         
                                         completion(transaction, nil);
                                     }] resume];
}

- (void)utxos:(NSString *)insightURL forAddresses:(NSArray *)addresses
   completion:(void (^)(NSArray *utxos, NSArray *amounts, NSArray *scripts, NSError *error))completion
{
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[insightURL stringByAppendingPathComponent:ADDRESS_UTXO_PATH]]
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
