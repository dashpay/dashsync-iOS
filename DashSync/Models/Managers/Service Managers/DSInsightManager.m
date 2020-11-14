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
#import "DSBlock.h"
#import "DSMerkleBlock.h"

#define ADDRESS_UTXO_PATH @"addrs/utxo"
#define ADDRESS_TXS_PATH @"addrs/txs"
#define TX_PATH @"rawtx"
#define BLOCK_PATH @"block"

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
    NSParameterAssert(addresses);
    NSParameterAssert(chain);
    
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

- (void)findExistingAddresses:(NSArray *)addresses onChain:(DSChain *)chain
                   completion:(void (^)(NSArray *addresses, NSError *error))completion {
    NSParameterAssert(addresses);
    NSParameterAssert(chain);
    
    NSString * insightURL = [chain isMainnet]?INSIGHT_URL:TESTNET_INSIGHT_URL;
    [self findExistingAddresses:addresses forInsightURL:insightURL completion:completion];
}

- (void)blockHeightsForBlockHashes:(NSArray*)blockHashes onChain:(DSChain*)chain completion:(void (^)(NSDictionary * blockHeightDictionary,
                                                                                                      NSError * _Null_unspecified error))completion {
    NSParameterAssert(blockHashes);
    NSParameterAssert(chain);
    NSString * insightURL = [chain isMainnet]?INSIGHT_URL:TESTNET_INSIGHT_URL;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        __block NSMutableDictionary * blockHeightDictionary = [NSMutableDictionary dictionary];
        dispatch_group_t dispatchGroup = dispatch_group_create();
        __block NSError *mainError = nil;
        for (NSData* blockHash in blockHashes) {
            dispatch_group_enter(dispatchGroup);
            [self queryInsight:insightURL forBlockWithHash:blockHash.UInt256 onChain:chain completion:^(DSBlock *block, NSError *error) {
                if (error) {
                    mainError = [error copy];
                } else {
                    [blockHeightDictionary setObject:@(block.height) forKey:blockHash];
                }
                dispatch_group_leave(dispatchGroup);
            }];
        }
        dispatch_group_notify(dispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            completion(blockHeightDictionary,mainError);
        });
    });
}

-(void)blockForBlockHash:(UInt256)blockHash onChain:(DSChain*)chain completion:(void (^)(DSBlock * block, NSError *error))completion {
    NSAssert(!uint256_is_zero(blockHash), @"blockHash must be set");
    NSParameterAssert(chain);
    NSString * insightURL = [chain isMainnet]?INSIGHT_URL:TESTNET_INSIGHT_URL;
    [self queryInsight:insightURL forBlockWithHash:blockHash onChain:chain completion:completion];
    
}

-(void)queryInsight:(NSString *)insightURL forBlockWithHash:(UInt256)blockHash onChain:(DSChain*)chain completion:(void (^)(DSBlock * block, NSError *error))completion {
    NSParameterAssert(insightURL);
    
    NSString * path = [[insightURL stringByAppendingPathComponent:BLOCK_PATH] stringByAppendingPathComponent:uint256_hex(blockHash)];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]
                                                       cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0];
    req.HTTPMethod = @"GET";
    DSLogPrivate(@"%@ GET: %@", req.URL.absoluteString,
           [[NSString alloc] initWithData:req.HTTPBody encoding:NSUTF8StringEncoding]);
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        
        if (error) {
            DSLogPrivate(@"Error decoding response %@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            completion(nil,
                       [NSError errorWithDomain:@"DashSync" code:417 userInfo:@{NSLocalizedDescriptionKey:
                                                                                    [NSString stringWithFormat:DSLocalizedString(@"Unexpected response from %@", nil),
                                                                                     req.URL.host]}]);
            return;
        }
        NSNumber * version = json[@"version"];
        NSData * blockHash = [json[@"hash"] hexToData];
        NSData * previousBlockHash = [json[@"previousblockhash"] hexToData];
        NSData * merkleRoot = [json[@"merkleroot"] hexToData];
        NSNumber * timestamp = json[@"time"];
        NSString * targetString = json[@"bits"];
        NSData * chainWork = [json[@"chainwork"] hexToData];
        NSNumber * height = json[@"height"];
        DSBlock * block = [[DSBlock alloc] initWithVersion:[version unsignedIntValue] blockHash:blockHash.reverse.UInt256 prevBlock:previousBlockHash.reverse.UInt256 timestamp:timestamp.unsignedIntValue merkleRoot:merkleRoot.reverse.UInt256 target:[targetString.hexToData UInt32AtOffset:0] chainWork:chainWork.reverse.UInt256 height:height.unsignedIntValue onChain:chain];
        
        completion(block, nil);
    }] resume];
}

-(void)queryInsightForTransactionWithHash:(UInt256)transactionHash onChain:(DSChain*)chain completion:(void (^)(DSTransaction * transaction, NSError *error))completion {
    NSParameterAssert(chain);
    
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
    NSParameterAssert(insightURL);
    
    NSString * path = [[insightURL stringByAppendingPathComponent:TX_PATH] stringByAppendingPathComponent:uint256_hex(transactionHash)];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]
                                                       cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0];
    req.HTTPMethod = @"GET";
    DSLogPrivate(@"%@ GET: %@", req.URL.absoluteString,
           [[NSString alloc] initWithData:req.HTTPBody encoding:NSUTF8StringEncoding]);
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        
        if (error) {
            DSLogPrivate(@"Error decoding response %@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            completion(nil,
                       [NSError errorWithDomain:@"DashSync" code:417 userInfo:@{NSLocalizedDescriptionKey:
                                                                                    [NSString stringWithFormat:DSLocalizedString(@"Unexpected response from %@", nil),
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

- (void)findExistingAddresses:(NSArray *)addresses forInsightURL:(NSString *)insightURL
                   completion:(void (^)(NSArray *addresses, NSError *error))completion {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[insightURL stringByAppendingPathComponent:ADDRESS_TXS_PATH]]
                                                       cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0];
    NSMutableArray *args = [NSMutableArray array];
    NSMutableCharacterSet *charset = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    
    [charset removeCharactersInString:@"&="];
    [args addObject:[@"addrs=" stringByAppendingString:[[addresses componentsJoinedByString:@","]
                                                        stringByAddingPercentEncodingWithAllowedCharacters:charset]]];
    req.HTTPMethod = @"POST";
    req.HTTPBody = [[args componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
    DSLogPrivate(@"%@ POST: %@", req.URL.absoluteString,
           [[NSString alloc] initWithData:req.HTTPBody encoding:NSUTF8StringEncoding]);
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        
        if (error || ! [json isKindOfClass:[NSDictionary class]] || ! [json objectForKey:@"items"]) {
            DSLogPrivate(@"Error decoding response %@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            completion(nil,[NSError errorWithDomain:@"DashSync" code:417 userInfo:@{NSLocalizedDescriptionKey:
                                                                                    [NSString stringWithFormat:DSLocalizedString(@"Unexpected response from %@", nil),
                                                                                     req.URL.host]}]);
            return;
        }
        NSMutableSet * existingAddresses = [NSMutableSet set];
        
        for (NSDictionary *item in json[@"items"]) {
            for (NSDictionary *vin in item[@"vin"]) {
                if ([addresses containsObject:vin[@"addr"]]) {
                    [existingAddresses addObject:vin[@"addr"]];
                }
            }
            for (NSDictionary *vout in item[@"vout"]) {
                NSArray * voutAddresses = vout[@"scriptPubKey"][@"addresses"];
                for (NSString * address in voutAddresses) {
                    if ([addresses containsObject:address]) {
                        [existingAddresses addObject:address];
                    }
                }
            }
        }
        
        completion([existingAddresses allObjects], nil);
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
    DSLogPrivate(@"%@ POST: %@", req.URL.absoluteString,
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
            DSLogPrivate(@"Error decoding response %@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            completion(nil, nil, nil,
                       [NSError errorWithDomain:@"DashSync" code:417 userInfo:@{NSLocalizedDescriptionKey:
                                                                                    [NSString stringWithFormat:DSLocalizedString(@"Unexpected response from %@", nil),
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
                                                                                        [NSString stringWithFormat:DSLocalizedString(@"Unexpected response from %@", nil),
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
