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

#import "DSDAPIClient.h"

#import "DSHTTPJSONRPCClient.h"
//#import <DAPI-GRPC/Core.pbrpc.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const DSDAPIClientErrorDomain = @"dash.dapi-client.error";


@interface DSDAPIClient ()

@property (strong, nonatomic) DSHTTPJSONRPCClient *httpJSONRPCClient;
//@property (strong, nonatomic) Core *gRPCClient;

@end

@implementation DSDAPIClient

- (instancetype)initWithDAPINodeURL:(NSURL *)url httpLoaderFactory:(HTTPLoaderFactory *)httpLoaderFactory {
    NSParameterAssert(url);
    NSParameterAssert(httpLoaderFactory);

    self = [super init];
    if (self) {
        _httpJSONRPCClient = [DSHTTPJSONRPCClient clientWithEndpointURL:url httpLoaderFactory:httpLoaderFactory];
        
//        GRPCMutableCallOptions *options = [[GRPCMutableCallOptions alloc] init];
//        // this example does not use TLS (secure channel); use insecure channel instead
//        options.transport = GRPCDefaultTransportImplList.core_insecure;
//        options.userAgentPrefix = @"HelloWorld/1.0";
        
        //_gRPCClient = [Core serviceWithHost:url.absoluteString];
    }
    return self;
}

#pragma mark - DSDAPIProtocol
#pragma mark Layer 1

- (void)estimateFeeWithNumberOfBlocksToWait:(NSUInteger)numberOfBlocksToWait
                                    success:(void (^)(NSNumber *duffsPerKilobyte))success
                                    failure:(void (^)(NSError *error))failure {
    [self requestWithMethod:@"estimateFee"
                  parameters:@{ @"blocks" : @(numberOfBlocksToWait) }
        validateAgainstClass:NSNumber.class
                     success:success
                     failure:failure];
}

- (void)getAddressSummary:(NSString *)address
                  success:(void (^)(NSDictionary *addressSummary))success
                  failure:(void (^)(NSError *error))failure {
    NSParameterAssert(address);

    [self requestWithMethod:@"getAddressSummary"
                  parameters:@{ @"address" : address }
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)getAddressTotalReceived:(NSString *)address
                        success:(void (^)(NSNumber *duffsReceivedByAddress))success
                        failure:(void (^)(NSError *error))failure {
    NSParameterAssert(address);

    [self requestWithMethod:@"getAddressTotalReceived"
                  parameters:@{ @"address" : address }
        validateAgainstClass:NSNumber.class
                     success:success
                     failure:failure];
}

- (void)getAddressTotalSent:(NSString *)address
                    success:(void (^)(NSNumber *duffsSentByAddress))success
                    failure:(void (^)(NSError *error))failure {
    NSParameterAssert(address);

    [self requestWithMethod:@"getAddressTotalSent"
                  parameters:@{ @"address" : address }
        validateAgainstClass:NSNumber.class
                     success:success
                     failure:failure];
}

- (void)getAddressUnconfirmedBalance:(NSString *)address
                             success:(void (^)(NSNumber *unconfirmedBalance))success
                             failure:(void (^)(NSError *error))failure {
    NSParameterAssert(address);

    [self requestWithMethod:@"getAddressUnconfirmedBalance"
                  parameters:@{ @"address" : address }
        validateAgainstClass:NSNumber.class
                     success:success
                     failure:failure];
}

- (void)getBalanceForAddress:(NSString *)address
                     success:(void (^)(NSNumber *balance))success
                     failure:(void (^)(NSError *error))failure {
    NSParameterAssert(address);

    [self requestWithMethod:@"getBalance"
                  parameters:@{ @"address" : address }
        validateAgainstClass:NSNumber.class
                     success:success
                     failure:failure];
}

- (void)getBestBlockHeightSuccess:(void (^)(NSNumber *blockHeight))success
                          failure:(void (^)(NSError *error))failure {
    [self requestWithMethod:@"getBestBlockHeight"
                  parameters:nil
        validateAgainstClass:NSNumber.class
                     success:success
                     failure:failure];
}

- (void)getBlockHashForHeight:(NSUInteger)height
                      success:(void (^)(NSString *blockHash))success
                      failure:(void (^)(NSError *error))failure {
    [self requestWithMethod:@"getBlockHash"
                  parameters:@{ @"height" : @(height) }
        validateAgainstClass:NSString.class
                     success:success
                     failure:failure];
}

- (void)getBlockHeaderForHash:(NSString *)blockHash
                      success:(void (^)(NSArray<NSDictionary *> *blockHeaders))success
                      failure:(void (^)(NSError *error))failure {
    NSParameterAssert(blockHash);

    [self requestWithMethod:@"getBlockHeader"
                  parameters:@{ @"blockHash" : blockHash }
        validateAgainstClass:NSArray.class
                     success:success
                     failure:failure];
}

- (void)getBlockHeadersFromOffset:(NSUInteger)offset
                            limit:(NSUInteger)limit
                          success:(void (^)(NSArray<NSDictionary *> *blockHeaders))success
                          failure:(void (^)(NSError *error))failure {
    NSAssert(limit <= 25, @"Limit should be <= 25");

    [self requestWithMethod:@"getBlockHeaders"
                  parameters:@{
                      @"offset" : @(offset),
                      @"limit" : @(limit),
                  }
        validateAgainstClass:NSArray.class
                     success:success
                     failure:failure];
}

- (void)getBlocksStartingDate:(NSDate *)date
                        limit:(NSUInteger)limit
                      success:(void (^)(NSArray<NSDictionary *> *blockHeaders))success
                      failure:(void (^)(NSError *error))failure {
    NSParameterAssert(date);

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd";
    NSString *dateString = [dateFormatter stringFromDate:date];

    [self requestWithMethod:@"getBlocks"
                  parameters:@{
                      @"blockDate" : dateString,
                      @"limit" : @(limit),
                  }
        validateAgainstClass:NSArray.class
                     success:success
                     failure:failure];
}

- (void)getHistoricBlockchainDataSyncStatusSuccess:(void (^)(NSDictionary *historicStatus))success
                                           failure:(void (^)(NSError *error))failure {
    [self requestWithMethod:@"getHistoricBlockchainDataSyncStatus"
                  parameters:nil
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)getMNListSuccess:(void (^)(NSArray<NSDictionary *> *mnList))success
                 failure:(void (^)(NSError *error))failure {
    [self requestWithMethod:@"getMNList"
                  parameters:nil
        validateAgainstClass:NSArray.class
                     success:success
                     failure:failure];
}

- (void)getMNListDiffBaseBlockHash:(NSString *)baseBlockHash
                         blockHash:(NSString *)blockHash
                           success:(void (^)(NSArray<NSDictionary *> *mnListDiff))success
                           failure:(void (^)(NSError *error))failure {
    NSParameterAssert(baseBlockHash);
    NSParameterAssert(blockHash);

    [self requestWithMethod:@"getMnListDiff"
                  parameters:@{
                      @"baseBlockHash" : baseBlockHash,
                      @"blockHash" : blockHash,
                  }
        validateAgainstClass:NSArray.class
                     success:success
                     failure:failure];
}

- (void)getPeerDataSyncStatusSuccess:(void (^)(NSDictionary *syncStatus))success
                             failure:(void (^)(NSError *error))failure {
    [self requestWithMethod:@"getPeerDataSyncStatus"
                  parameters:nil
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)getQuorumRegTxId:(NSString *)regTxId
                 success:(void (^)(NSDictionary *rawBlock))success
                 failure:(void (^)(NSError *error))failure {
    NSParameterAssert(regTxId);

    [self requestWithMethod:@"getQuorum"
                  parameters:@{ @"regTxId" : regTxId }
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)getRawBlock:(NSString *)blockHash
            success:(void (^)(NSDictionary *rawBlock))success
            failure:(void (^)(NSError *error))failure {
    NSParameterAssert(blockHash);

    [self requestWithMethod:@"getRawBlock"
                  parameters:@{ @"blockHash" : blockHash }
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)getSpvDataForFilter:(nullable NSString *)filter
                    success:(void (^)(NSDictionary *blockHeaders))success
                    failure:(void (^)(NSError *error))failure {
    if (!filter) {
        filter = @"";
    }

    [self requestWithMethod:@"getSpvData"
                  parameters:@{ @"filter" : filter }
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)getStatus:(DSDAPIClientStatusType)status
          success:(void (^)(id response))success
          failure:(void (^)(NSError *error))failure {
    NSString *statusString = nil;
    switch (status) {
        case DSDAPIClientStatusTypeInfo:
            statusString = @"getInfo";
            break;
        case DSDAPIClientStatusTypeDifficulty:
            statusString = @"getDifficulty";
            break;
        case DSDAPIClientStatusTypeBestBlockHash:
            statusString = @"getBestBlockHash";
            break;
        case DSDAPIClientStatusTypetLastBlockHash:
            statusString = @"getLastBlockHash";
            break;
    }

    [self requestWithMethod:@"getStatus"
                  parameters:@{ @"query" : statusString }
        validateAgainstClass:NSObject.class
                     success:success
                     failure:failure];
}

- (void)getTransactionById:(NSString *)txid
                   success:(void (^)(NSDictionary *tx))success
                   failure:(void (^)(NSError *error))failure {
    NSParameterAssert(txid);

    [self requestWithMethod:@"getTransactionById"
                  parameters:@{ @"txid" : txid }
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)getTransactionsByAddress:(NSString *)address
                         success:(void (^)(NSArray<NSDictionary *> *addressTXs))success
                         failure:(void (^)(NSError *error))failure {
    NSParameterAssert(address);

    [self requestWithMethod:@"getTransactionsByAddress"
                  parameters:@{ @"address" : address }
        validateAgainstClass:NSArray.class
                     success:success
                     failure:failure];
}

- (void)getUTXOForAddress:(NSString *)address
                  success:(void (^)(NSArray<NSDictionary *> *unspentOutputs))success
                  failure:(void (^)(NSError *error))failure {
    NSParameterAssert(address);

    [self requestWithMethod:@"getUTXO"
                  parameters:@{ @"address" : address }
        validateAgainstClass:NSArray.class
                     success:success
                     failure:failure];
}

- (void)sendRawIxTransaction:(NSString *)rawIxTransaction
                     success:(void (^)(NSString *txid))success
                     failure:(void (^)(NSError *error))failure {
    NSParameterAssert(rawIxTransaction);

    [self requestWithMethod:@"sendRawIxTransaction"
                  parameters:@{ @"rawIxTransaction" : rawIxTransaction }
        validateAgainstClass:NSString.class
                     success:success
                     failure:failure];
}

- (void)sendRawTransaction:(NSString *)rawTransaction
                   success:(void (^)(NSString *txid))success
                   failure:(void (^)(NSError *error))failure {
    NSParameterAssert(rawTransaction);

    [self requestWithMethod:@"sendRawTransaction"
                  parameters:@{ @"rawTransaction" : rawTransaction }
        validateAgainstClass:NSString.class
                     success:success
                     failure:failure];
}

- (void)addToBloomFilterWithOriginalFilter:(NSString *)originalFilter
                                   element:(NSString *)element
                                   success:(void (^)(BOOL result))success
                                   failure:(void (^)(NSError *error))failure {
    NSParameterAssert(originalFilter);
    NSParameterAssert(element);

    [self requestWithMethod:@"addToBloomFilter"
                  parameters:@{
                      @"originalFilter" : originalFilter,
                      @"element" : element,
                  }
        validateAgainstClass:NSNumber.class
                     success:^(id _Nonnull responseObject) {
                         if (success) {
                             success([(NSNumber *)responseObject boolValue]);
                         }
                     }
                     failure:failure];
}

- (void)clearBloomFilter:(NSString *)filter
                 success:(void (^)(BOOL result))success
                 failure:(void (^)(NSError *error))failure {
    NSParameterAssert(filter);

    [self requestWithMethod:@"clearBloomFilter"
                  parameters:@{ @"filter" : filter }
        validateAgainstClass:NSNumber.class
                     success:^(id _Nonnull responseObject) {
                         if (success) {
                             success([(NSNumber *)responseObject boolValue]);
                         }
                     }
                     failure:failure];
}

- (void)loadBloomFilter:(NSString *)filter
                success:(void (^)(BOOL result))success
                failure:(void (^)(NSError *error))failure {
    NSParameterAssert(filter);

    [self requestWithMethod:@"loadBloomFilter"
                  parameters:@{ @"filter" : filter }
        validateAgainstClass:NSNumber.class
                     success:^(id _Nonnull responseObject) {
                         if (success) {
                             success([(NSNumber *)responseObject boolValue]);
                         }
                     }
                     failure:failure];
}

#pragma mark Layer 2

- (void)fetchDapContractForId:(NSString *)dapId
                      success:(void (^)(NSDictionary *dapSpace))success
                      failure:(void (^)(NSError *error))failure {
    NSParameterAssert(dapId);

    [self requestWithMethod:@"fetchDapContract"
                  parameters:@{ @"dapId" : dapId }
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)getUserByName:(NSString *)username
              success:(void (^)(NSDictionary *blockchainUser))success
              failure:(void (^)(NSError *error))failure {
    NSParameterAssert(username);

    [self requestWithMethod:@"getUser"
                  parameters:@{ @"username" : username }
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)getUserById:(NSString *)userId
            success:(void (^)(NSDictionary *blockchainUser))success
            failure:(void (^)(NSError *error))failure {
    NSParameterAssert(userId);

    [self requestWithMethod:@"getUser"
                  parameters:@{ @"userId" : userId }
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)searchUsersWithPattern:(NSString *)pattern
                        offset:(NSUInteger)offset
                         limit:(NSUInteger)limit
                       success:(void (^)(NSArray<NSDictionary *> *blockchainUsers, NSUInteger totalCount))success
                       failure:(void (^)(NSError *error))failure {
    NSParameterAssert(pattern);
    NSAssert(limit <= 25, @"Limit should be <= 25");

    [self requestWithMethod:@"searchUsers"
                  parameters:@{
                      @"pattern" : pattern,
                      @"offset" : @(offset),
                      @"limit" : @(limit),
                  }
        validateAgainstClass:NSDictionary.class
                     success:^(id _Nonnull responseObject) {
                         if (success) {
                             NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                             NSArray<NSDictionary *> *blockchainUsers = responseDictionary[@"results"];
                             NSUInteger totalCount = [responseDictionary[@"totalCount"] unsignedIntegerValue];
                             success(blockchainUsers, totalCount);
                         }
                     }
                     failure:failure];
}

- (void)sendRawTransitionWithRawTransitionHeader:(NSString *)rawTransitionHeader
                             rawTransitionPacket:(NSString *)rawTransitionPacket
                                         success:(void (^)(NSString *headerId))success
                                         failure:(void (^)(NSError *error))failure {
    NSParameterAssert(rawTransitionHeader);
    NSParameterAssert(rawTransitionPacket);

    [self requestWithMethod:@"sendRawTransition"
                  parameters:@{ @"rawTransitionHeader" : rawTransitionHeader,
                                @"rawTransitionPacket" : rawTransitionPacket }
        validateAgainstClass:NSString.class
                     success:success
                     failure:failure];
}

- (void)fetchDapObjectsForId:(NSString *)dapId
                 objectsType:(NSString *)objectsType
                     options:(nullable DSDAPIClientFetchDapObjectsOptions *)options
                     success:(void (^)(NSArray<NSDictionary *> *dapObjects))success
                     failure:(void (^)(NSError *error))failure {
    NSParameterAssert(dapId);
    NSParameterAssert(objectsType);

    NSMutableDictionary *optionsDictionary = [NSMutableDictionary dictionary];
    optionsDictionary[@"where"] = options.where;
    optionsDictionary[@"orderBy"] = options.orderBy;
    optionsDictionary[@"limit"] = options.limit;
    optionsDictionary[@"startAt"] = options.startAt;
    optionsDictionary[@"startAfter"] = options.startAfter;

    [self requestWithMethod:@"fetchDapObjects"
                  parameters:@{ @"dapId" : dapId,
                                @"type" : objectsType,
                                @"options" : optionsDictionary }
        validateAgainstClass:NSArray.class
                     success:success
                     failure:failure];
}

#pragma mark - Private

- (void)requestWithMethod:(NSString *)method
              parameters:(nullable NSDictionary *)parameters
    validateAgainstClass:(Class)responseClass
                 success:(void (^)(id responseObject))success
                 failure:(void (^)(NSError *error))failure {
    void (^internalSuccess)(id) = ^(id _Nonnull responseObject) {
        if ([responseObject isKindOfClass:responseClass]) {
            if (success) {
                success(responseObject);
            }
        }
        else {
            if (failure) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey : DSLocalizedString(@"Invalid DAPI Response", nil),
                    NSDebugDescriptionErrorKey : responseObject,
                };
                NSError *error = [NSError errorWithDomain:DSDAPIClientErrorDomain
                                                     code:DSDAPIClientErrorCodeInvalidResponse
                                                 userInfo:userInfo];

                failure(error);
            }
        }
    };

    [self.httpJSONRPCClient invokeMethod:method
                          withParameters:parameters
                                 success:internalSuccess
                                 failure:failure];
}

@end

NS_ASSUME_NONNULL_END
