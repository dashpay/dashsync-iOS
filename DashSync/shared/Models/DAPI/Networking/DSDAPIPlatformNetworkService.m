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

#import "DSDAPIPlatformNetworkService.h"

#import "DPContract.h"
#import "DPErrors.h"
#import "DSChain.h"
#import "DSDAPIGRPCResponseHandler.h"
#import "DSDashPlatform.h"
#import "DSHTTPJSONRPCClient.h"
#import "DSPeer.h"
#import "DSPlatformDocumentsRequest.h"
#import "DSTransition.h"
#import "NSData+Bitcoin.h"

NSString *const DSDAPINetworkServiceErrorDomain = @"dash.dapi-network-service.error";


@interface DSDAPIPlatformNetworkService ()

@property (strong, nonatomic) DSHTTPJSONRPCClient *httpJSONRPCClient;
@property (strong, nonatomic) Platform *gRPCClient;
@property (strong, nonatomic) DSChain *chain;
@property (strong, nonatomic) NSString *ipAddress;
@property (strong, atomic) dispatch_queue_t grpcDispatchQueue;

@end

@implementation DSDAPIPlatformNetworkService

- (instancetype)initWithDAPINodeIPAddress:(NSString *)ipAddress httpLoaderFactory:(HTTPLoaderFactory *)httpLoaderFactory usingGRPCDispatchQueue:(dispatch_queue_t)grpcDispatchQueue onChain:(DSChain *)chain {
    NSParameterAssert(ipAddress);
    NSParameterAssert(httpLoaderFactory);

    if (!(self = [super init])) return nil;

    self.ipAddress = ipAddress;
    NSURL *dapiNodeURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%d", ipAddress, chain.standardDapiJRPCPort]];
    _httpJSONRPCClient = [DSHTTPJSONRPCClient clientWithEndpointURL:dapiNodeURL httpLoaderFactory:httpLoaderFactory];
    self.chain = chain;
    GRPCMutableCallOptions *options = [[GRPCMutableCallOptions alloc] init];
    // this example does not use TLS (secure channel); use insecure channel instead
    options.transportType = GRPCTransportTypeInsecure;
    options.userAgentPrefix = USER_AGENT;
    options.timeout = 30;
    self.grpcDispatchQueue = grpcDispatchQueue;

    NSString *dapiGRPCHost = [NSString stringWithFormat:@"%@:%d", ipAddress, chain.standardDapiGRPCPort];

    _gRPCClient = [Platform serviceWithHost:dapiGRPCHost callOptions:options];
    return self;
}

#pragma mark - DSDAPIProtocol
#pragma mark Layer 1 Deprecated

- (void)estimateFeeWithNumberOfBlocksToWait:(NSUInteger)numberOfBlocksToWait
                                    success:(void (^)(NSNumber *duffsPerKilobyte))success
                                    failure:(void (^)(NSError *error))failure {
    [self requestWithMethod:@"estimateFee"
                  parameters:@{@"blocks": @(numberOfBlocksToWait)}
        validateAgainstClass:NSNumber.class
                     success:success
                     failure:failure];
}

- (void)getAddressSummary:(NSArray<NSString *> *)addresses
                 noTxList:(BOOL)noTxList
                     from:(NSNumber *)from
                       to:(NSNumber *)to
               fromHeight:(nullable NSNumber *)fromHeight
                 toHeight:(nullable NSNumber *)toHeight
                  success:(void (^)(NSDictionary *addressSummary))success
                  failure:(void (^)(NSError *error))failure {
    NSParameterAssert(addresses);
    NSParameterAssert(from);
    NSParameterAssert(to);
    NSAssert(addresses.count > 0, @"Empty address list is not allowed");

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"address"] = addresses;
    parameters[@"noTxList"] = @(noTxList);
    parameters[@"from"] = from;
    parameters[@"to"] = to;
    parameters[@"fromHeight"] = fromHeight;
    parameters[@"toHeight"] = toHeight;

    [self requestWithMethod:@"getAddressSummary"
                  parameters:parameters
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)getAddressTotalReceived:(NSArray<NSString *> *)addresses
                        success:(void (^)(NSNumber *duffsReceivedByAddress))success
                        failure:(void (^)(NSError *error))failure {
    NSParameterAssert(addresses);
    NSAssert(addresses.count > 0, @"Empty address list is not allowed");

    [self requestWithMethod:@"getAddressTotalReceived"
                  parameters:@{@"address": addresses}
        validateAgainstClass:NSNumber.class
                     success:success
                     failure:failure];
}

- (void)getAddressTotalSent:(NSArray<NSString *> *)addresses
                    success:(void (^)(NSNumber *duffsSentByAddress))success
                    failure:(void (^)(NSError *error))failure {
    NSParameterAssert(addresses);
    NSAssert(addresses.count > 0, @"Empty address list is not allowed");

    [self requestWithMethod:@"getAddressTotalSent"
                  parameters:@{@"address": addresses}
        validateAgainstClass:NSNumber.class
                     success:success
                     failure:failure];
}

- (void)getAddressUnconfirmedBalance:(NSArray<NSString *> *)addresses
                             success:(void (^)(NSNumber *unconfirmedBalance))success
                             failure:(void (^)(NSError *error))failure {
    NSParameterAssert(addresses);
    NSAssert(addresses.count > 0, @"Empty address list is not allowed");

    [self requestWithMethod:@"getAddressUnconfirmedBalance"
                  parameters:@{@"address": addresses}
        validateAgainstClass:NSNumber.class
                     success:success
                     failure:failure];
}

- (void)getBalanceForAddress:(NSArray<NSString *> *)addresses
                     success:(void (^)(NSNumber *balance))success
                     failure:(void (^)(NSError *error))failure {
    NSParameterAssert(addresses);
    NSAssert(addresses.count > 0, @"Empty address list is not allowed");

    [self requestWithMethod:@"getBalance"
                  parameters:@{@"address": addresses}
        validateAgainstClass:NSNumber.class
                     success:success
                     failure:failure];
}

- (void)getBestBlockHashSuccess:(void (^)(NSString *blockHeight))success
                        failure:(void (^)(NSError *error))failure {
    [self requestWithMethod:@"getBestBlockHash"
                  parameters:nil
        validateAgainstClass:NSString.class
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
                  parameters:@{@"height": @(height)}
        validateAgainstClass:NSString.class
                     success:success
                     failure:failure];
}

- (void)getBlockHeaderForHash:(NSString *)blockHash
                      success:(void (^)(NSArray<NSDictionary *> *blockHeaders))success
                      failure:(void (^)(NSError *error))failure {
    NSParameterAssert(blockHash);

    [self requestWithMethod:@"getBlockHeader"
                  parameters:@{@"blockHash": blockHash}
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
                      @"offset": @(offset),
                      @"limit": @(limit),
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
                      @"blockDate": dateString,
                      @"limit": @(limit),
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

- (void)getMempoolInfoSuccess:(void (^)(NSNumber *blockHeight))success
                      failure:(void (^)(NSError *error))failure {
    [self requestWithMethod:@"getMempoolInfo"
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
                           success:(void (^)(NSDictionary *mnListDiff))success
                           failure:(void (^)(NSError *error))failure {
    NSParameterAssert(baseBlockHash);
    NSParameterAssert(blockHash);

    [self requestWithMethod:@"getMnListDiff"
                  parameters:@{
                      @"baseBlockHash": baseBlockHash,
                      @"blockHash": blockHash,
                  }
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)getRawBlock:(NSString *)blockHash
            success:(void (^)(NSDictionary *rawBlock))success
            failure:(void (^)(NSError *error))failure {
    NSParameterAssert(blockHash);

    [self requestWithMethod:@"getRawBlock"
                  parameters:@{@"blockHash": blockHash}
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
                  parameters:@{@"filter": filter}
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)getTransactionById:(NSString *)txid
                   success:(void (^)(NSDictionary *tx))success
                   failure:(void (^)(NSError *error))failure {
    NSParameterAssert(txid);

    [self requestWithMethod:@"getTransactionById"
                  parameters:@{@"txid": txid}
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)getTransactionsByAddress:(NSArray<NSString *> *)addresses
                            from:(NSNumber *)from
                              to:(NSNumber *)to
                      fromHeight:(nullable NSNumber *)fromHeight
                        toHeight:(nullable NSNumber *)toHeight
                         success:(void (^)(NSDictionary *result))success
                         failure:(void (^)(NSError *error))failure {
    NSParameterAssert(addresses);
    NSParameterAssert(from);
    NSParameterAssert(to);
    NSAssert(addresses.count > 0, @"Empty address list is not allowed");

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"address"] = addresses;
    parameters[@"from"] = from;
    parameters[@"to"] = to;
    parameters[@"fromHeight"] = fromHeight;
    parameters[@"toHeight"] = toHeight;

    [self requestWithMethod:@"getTransactionsByAddress"
                  parameters:parameters
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)getUTXOForAddress:(NSArray<NSString *> *)addresses
                     from:(nullable NSNumber *)from
                       to:(nullable NSNumber *)to
               fromHeight:(nullable NSNumber *)fromHeight
                 toHeight:(nullable NSNumber *)toHeight
                  success:(void (^)(NSDictionary *result))success
                  failure:(void (^)(NSError *error))failure {
    NSParameterAssert(addresses);
    NSParameterAssert(from);
    NSParameterAssert(to);
    NSAssert(addresses.count > 0, @"Empty address list is not allowed");

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"address"] = addresses;
    parameters[@"from"] = from;
    parameters[@"to"] = to;
    parameters[@"fromHeight"] = fromHeight;
    parameters[@"toHeight"] = toHeight;

    [self requestWithMethod:@"getUTXO"
                  parameters:parameters
        validateAgainstClass:NSDictionary.class
                     success:success
                     failure:failure];
}

- (void)sendRawIxTransaction:(NSString *)rawIxTransaction
                     success:(void (^)(NSString *txid))success
                     failure:(void (^)(NSError *error))failure {
    NSParameterAssert(rawIxTransaction);

    [self requestWithMethod:@"sendRawIxTransaction"
                  parameters:@{@"rawIxTransaction": rawIxTransaction}
        validateAgainstClass:NSString.class
                     success:success
                     failure:failure];
}

- (void)sendRawTransaction:(NSString *)rawTransaction
                   success:(void (^)(NSString *txid))success
                   failure:(void (^)(NSError *error))failure {
    NSParameterAssert(rawTransaction);

    [self requestWithMethod:@"sendRawTransaction"
                  parameters:@{@"rawTransaction": rawTransaction}
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
                      @"originalFilter": originalFilter,
                      @"element": element,
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
                  parameters:@{@"filter": filter}
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
                  parameters:@{@"filter": filter}
        validateAgainstClass:NSNumber.class
                     success:^(id _Nonnull responseObject) {
                         if (success) {
                             success([(NSNumber *)responseObject boolValue]);
                         }
                     }
                     failure:failure];
}

#pragma mark Layer 2

- (id<DSDAPINetworkServiceRequest>)fetchIdentitiesByKeyHashes:(NSArray<NSData *> *)keyHashesArray
                                              completionQueue:(dispatch_queue_t)completionQueue
                                                      success:(void (^)(NSArray<NSDictionary *> *identityDictionaries))success
                                                      failure:(void (^)(NSError *error))failure {
    NSParameterAssert(keyHashesArray);
    NSParameterAssert(completionQueue);
    GetIdentitiesByPublicKeyHashesRequest *getIdentitiesByPublicKeyHashesRequest = [[GetIdentitiesByPublicKeyHashesRequest alloc] init];
    getIdentitiesByPublicKeyHashesRequest.publicKeyHashesArray = [keyHashesArray mutableCopy];
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.chain = self.chain;
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = success;
    responseHandler.errorHandler = failure;
    GRPCUnaryProtoCall *call = [self.gRPCClient getIdentitiesByPublicKeyHashesWithMessage:getIdentitiesByPublicKeyHashesRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}

- (id<DSDAPINetworkServiceRequest>)fetchContractForId:(NSData *)contractId
                                      completionQueue:(dispatch_queue_t)completionQueue
                                              success:(void (^)(NSDictionary *contract))success
                                              failure:(void (^)(NSError *error))failure {
    NSParameterAssert(contractId);
    NSParameterAssert(completionQueue);
    GetDataContractRequest *getDataContractRequest = [[GetDataContractRequest alloc] init];
    getDataContractRequest.id_p = contractId;
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = success;
    responseHandler.errorHandler = failure;
    GRPCUnaryProtoCall *call = [self.gRPCClient getDataContractWithMessage:getDataContractRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}

- (id<DSDAPINetworkServiceRequest>)getDPNSDocumentsForPreorderSaltedDomainHashes:(NSArray *)saltedDomainHashes
                                                                 completionQueue:(dispatch_queue_t)completionQueue
                                                                         success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                                         failure:(void (^)(NSError *error))failure {
    NSAssert(saltedDomainHashes.count, @"saltedDomainHash must not be empty");
    NSParameterAssert(completionQueue);
    DSPlatformDocumentsRequest *platformDocumentsRequest = [DSPlatformDocumentsRequest dpnsRequestForPreorderSaltedHashes:saltedDomainHashes];
    platformDocumentsRequest.contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = success;
    responseHandler.errorHandler = failure;
    GRPCUnaryProtoCall *call = [self.gRPCClient getDocumentsWithMessage:platformDocumentsRequest.getDocumentsRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}

- (id<DSDAPINetworkServiceRequest>)getDPNSDocumentsForIdentityWithUserId:(NSData *)userId
                                                         completionQueue:(dispatch_queue_t)completionQueue
                                                                 success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                                 failure:(void (^)(NSError *error))failure {
    NSParameterAssert(userId);
    NSParameterAssert(completionQueue);
    DSPlatformDocumentsRequest *platformDocumentsRequest = [DSPlatformDocumentsRequest dpnsRequestForUserId:userId];
    platformDocumentsRequest.contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = success;
    responseHandler.errorHandler = failure;
    GRPCUnaryProtoCall *call = [self.gRPCClient getDocumentsWithMessage:platformDocumentsRequest.getDocumentsRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}

- (id<DSDAPINetworkServiceRequest>)getDPNSDocumentsForUsernames:(NSArray *)usernames
                                                       inDomain:(NSString *)domain
                                                completionQueue:(dispatch_queue_t)completionQueue
                                                        success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                        failure:(void (^)(NSError *error))failure {
    NSAssert(usernames.count, @"usernames must not be empty");
    NSParameterAssert(completionQueue);
    DSPlatformDocumentsRequest *platformDocumentsRequest = [DSPlatformDocumentsRequest dpnsRequestForUsernames:usernames inDomain:domain];
    platformDocumentsRequest.contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = success;
    responseHandler.errorHandler = failure;
    GRPCUnaryProtoCall *call = [self.gRPCClient getDocumentsWithMessage:platformDocumentsRequest.getDocumentsRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}

- (id<DSDAPINetworkServiceRequest>)searchDPNSDocumentsForUsernamePrefix:(NSString *)usernamePrefix
                                                               inDomain:(NSString *)domain
                                                                 offset:(uint32_t)offset
                                                                  limit:(uint32_t)limit
                                                        completionQueue:(dispatch_queue_t)completionQueue
                                                                success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                                failure:(void (^)(NSError *error))failure {
    NSParameterAssert(usernamePrefix);
    NSParameterAssert(completionQueue);
    DSPlatformDocumentsRequest *platformDocumentsRequest = [DSPlatformDocumentsRequest dpnsRequestForUsernameStartsWithSearch:[usernamePrefix lowercaseString] inDomain:domain offset:offset limit:limit];
    platformDocumentsRequest.contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = success;
    responseHandler.errorHandler = failure;
    GRPCUnaryProtoCall *call = [self.gRPCClient getDocumentsWithMessage:platformDocumentsRequest.getDocumentsRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}

- (id<DSDAPINetworkServiceRequest>)getIdentityByName:(NSString *)username
                                            inDomain:(NSString *)domain
                                     completionQueue:(dispatch_queue_t)completionQueue
                                             success:(void (^)(NSDictionary *_Nullable blockchainIdentity))success
                                             failure:(void (^)(NSError *error))failure {
    NSParameterAssert(username);
    NSParameterAssert(completionQueue);
    DSPlatformDocumentsRequest *platformDocumentsRequest = [DSPlatformDocumentsRequest dpnsRequestForUsername:username inDomain:domain];
    if (uint256_is_zero(self.chain.dpnsContractID)) return nil;
    platformDocumentsRequest.contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = ^(NSArray *dpnsDictionaries) {
        if ([dpnsDictionaries count]) {
            NSDictionary *dpnsDictionary = [dpnsDictionaries firstObject];
            NSData *ownerIdData = nil;
            if (!dpnsDictionary || !(ownerIdData = dpnsDictionary[@"$ownerId"])) {
                if (failure) {
                    failure([NSError errorWithDomain:DPErrorDomain
                                                code:DPErrorCode_InvalidDocumentType
                                            userInfo:@{
                                                NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"DPNS returned document is malformed"],
                                            }]);
                }
                return;
            }
            [self getIdentityById:ownerIdData completionQueue:completionQueue success:success failure:failure];
        } else {
            //no identity
            success(nil);
        }
    };
    responseHandler.errorHandler = failure;
    GRPCUnaryProtoCall *call = [self.gRPCClient getDocumentsWithMessage:platformDocumentsRequest.getDocumentsRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}

- (id<DSDAPINetworkServiceRequest>)getIdentityById:(NSData *)userId
                                   completionQueue:(dispatch_queue_t)completionQueue
                                           success:(void (^)(NSDictionary *blockchainIdentity))success
                                           failure:(void (^)(NSError *error))failure {
    NSParameterAssert(userId);
    NSParameterAssert(completionQueue);

    GetIdentityRequest *getIdentityRequest = [[GetIdentityRequest alloc] init];
    getIdentityRequest.id_p = userId;
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = success;
    responseHandler.errorHandler = failure;
    GRPCUnaryProtoCall *call = [self.gRPCClient getIdentityWithMessage:getIdentityRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}

- (id<DSDAPINetworkServiceRequest>)publishTransition:(DSTransition *)stateTransition
                                     completionQueue:(dispatch_queue_t)completionQueue
                                             success:(void (^)(NSDictionary *successDictionary, BOOL added))success
                                             failure:(void (^)(NSError *error))failure {
    NSParameterAssert(stateTransition);
    NSParameterAssert(completionQueue);
    DSLogPrivate(@"Broadcasting state transition to ip %@ with data %@ rawData %@", self.ipAddress, stateTransition.keyValueDictionary, stateTransition.data.hexString);

    WaitForStateTransitionResultRequest *waitForStateTransitionResultRequest = [[WaitForStateTransitionResultRequest alloc] init];
    waitForStateTransitionResultRequest.prove = TRUE;
    waitForStateTransitionResultRequest.stateTransitionHash = uint256_data(stateTransition.transitionHash);

    DSDAPIGRPCResponseHandler *waitResponseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    waitResponseHandler.dispatchQueue = self.grpcDispatchQueue;
    waitResponseHandler.completionQueue = completionQueue;
    waitResponseHandler.successHandler = ^(NSDictionary *successDictionary) {
        NSLog(@"%@", successDictionary);

        //todo : verify proof
        if (success) {
            success(successDictionary, TRUE);
        }
    };
    waitResponseHandler.errorHandler = failure;

    GRPCUnaryProtoCall *waitCall = [self.gRPCClient waitForStateTransitionResultWithMessage:waitForStateTransitionResultRequest responseHandler:waitResponseHandler callOptions:nil];
    [waitCall start];

    BroadcastStateTransitionRequest *broadcastStateRequest = [[BroadcastStateTransitionRequest alloc] init];
    broadcastStateRequest.stateTransition = stateTransition.data;
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = ^(NSDictionary *successDictionary) {
        NSLog(@"%@", successDictionary);
    };
    responseHandler.errorHandler = ^(NSError *error) {

    };
    GRPCUnaryProtoCall *call = [self.gRPCClient broadcastStateTransitionWithMessage:broadcastStateRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}

- (id<DSDAPINetworkServiceRequest>)getDashpayIncomingContactRequestsForUserId:(NSData *)userId since:(NSTimeInterval)timestamp
                                                                       offset:(uint32_t)offset
                                                              completionQueue:(dispatch_queue_t)completionQueue
                                                                      success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                                      failure:(void (^)(NSError *error))failure {
    NSParameterAssert(userId);
    NSParameterAssert(completionQueue);
    DSPlatformDocumentsRequest *platformDocumentsRequest = [DSPlatformDocumentsRequest dashpayRequestForContactRequestsForRecipientUserId:userId since:timestamp offset:offset];
    platformDocumentsRequest.contract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = success;
    responseHandler.errorHandler = failure;
    responseHandler.request = platformDocumentsRequest;
    GRPCUnaryProtoCall *call = [self.gRPCClient getDocumentsWithMessage:platformDocumentsRequest.getDocumentsRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}

- (id<DSDAPINetworkServiceRequest>)getDashpayOutgoingContactRequestsForUserId:(NSData *)userId since:(NSTimeInterval)timestamp offset:(uint32_t)offset
                                                              completionQueue:(dispatch_queue_t)completionQueue
                                                                      success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                                      failure:(void (^)(NSError *error))failure {
    NSParameterAssert(userId);
    NSParameterAssert(completionQueue);
    DSPlatformDocumentsRequest *platformDocumentsRequest = [DSPlatformDocumentsRequest dashpayRequestForContactRequestsForSendingUserId:userId since:timestamp offset:offset];
    platformDocumentsRequest.contract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = success;
    responseHandler.errorHandler = failure;
    responseHandler.request = platformDocumentsRequest;
    GRPCUnaryProtoCall *call = [self.gRPCClient getDocumentsWithMessage:platformDocumentsRequest.getDocumentsRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}

- (id<DSDAPINetworkServiceRequest>)getDashpayProfileForUserId:(NSData *)userId
                                              completionQueue:(dispatch_queue_t)completionQueue
                                                      success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                      failure:(void (^)(NSError *error))failure {
    NSParameterAssert(userId);
    NSParameterAssert(completionQueue);
    DSPlatformDocumentsRequest *platformDocumentsRequest = [DSPlatformDocumentsRequest dashpayRequestForProfileWithUserId:userId];
    platformDocumentsRequest.contract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = success;
    responseHandler.errorHandler = failure;
    GRPCUnaryProtoCall *call = [self.gRPCClient getDocumentsWithMessage:platformDocumentsRequest.getDocumentsRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}

- (id<DSDAPINetworkServiceRequest>)getDashpayProfilesForUserIds:(NSArray<NSData *> *)userIds
                                                completionQueue:(dispatch_queue_t)completionQueue
                                                        success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                        failure:(void (^)(NSError *error))failure {
    NSParameterAssert(userIds);
    NSParameterAssert(completionQueue);
    NSAssert(userIds.count > 0, @"You must query at least 1 userId");
    DSPlatformDocumentsRequest *platformDocumentsRequest = [DSPlatformDocumentsRequest dashpayRequestForProfilesWithUserIds:userIds];
    platformDocumentsRequest.contract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = success;
    responseHandler.errorHandler = failure;
    GRPCUnaryProtoCall *call = [self.gRPCClient getDocumentsWithMessage:platformDocumentsRequest.getDocumentsRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}

- (id<DSDAPINetworkServiceRequest>)fetchDocumentsWithRequest:(DSPlatformDocumentsRequest *)platformDocumentsRequest
                                             completionQueue:(dispatch_queue_t)completionQueue
                                                     success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                     failure:(void (^)(NSError *error))failure {
    NSParameterAssert(platformDocumentsRequest);
    NSParameterAssert(completionQueue);
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = success;
    responseHandler.errorHandler = failure;
    GRPCUnaryProtoCall *call = [self.gRPCClient getDocumentsWithMessage:platformDocumentsRequest.getDocumentsRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
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
        } else {
            if (failure) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: DSLocalizedString(@"Invalid DAPI Response", nil),
                    NSDebugDescriptionErrorKey: responseObject,
                };
                NSError *error = [NSError errorWithDomain:DSDAPINetworkServiceErrorDomain
                                                     code:DSDAPINetworkServiceErrorCodeInvalidResponse
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
