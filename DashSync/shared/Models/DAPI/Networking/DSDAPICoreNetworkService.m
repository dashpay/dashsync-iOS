//
//  Created by Sam Westrich
//  Copyright © 2021 Dash Core Group. All rights reserved.
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

#import "DSDAPICoreNetworkService.h"
#import "DPErrors.h"
#import "DSChain.h"
#import "DSChainLock.h"
#import "DSDAPIGRPCResponseHandler.h"
#import "DSDashPlatform.h"
#import "DSHTTPJSONRPCClient.h"
#import "DSPeer.h"
#import "DSTransactionFactory.h"
#import "NSData+Dash.h"

@interface DSDAPICoreNetworkService ()

@property (strong, nonatomic) DSHTTPJSONRPCClient *httpJSONRPCClient;
@property (strong, nonatomic) Core *gRPCClient;
@property (strong, nonatomic) DSChain *chain;
@property (strong, nonatomic) NSString *ipAddress;
@property (strong, atomic) dispatch_queue_t grpcDispatchQueue;

@end

@implementation DSDAPICoreNetworkService

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

    _gRPCClient = [Core serviceWithHost:dapiGRPCHost callOptions:options];

    return self;
}

- (id<DSDAPINetworkServiceRequest>)getStatusWithCompletionQueue:(dispatch_queue_t)completionQueue success:(void (^)(NSDictionary *status))success
                                                        failure:(void (^)(NSError *error))failure {
    NSParameterAssert(completionQueue);
    GetStatusRequest *statusRequest = [[GetStatusRequest alloc] init];
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.host = [NSString stringWithFormat:@"%@:%d", self.ipAddress, self.chain.standardDapiGRPCPort];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = success;
    responseHandler.errorHandler = failure;
    GRPCUnaryProtoCall *call = [self.gRPCClient getStatusWithMessage:statusRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}

- (id<DSDAPINetworkServiceRequest>)getTransactionWithHash:(UInt256)transactionHash completionQueue:(dispatch_queue_t)completionQueue success:(void (^)(DSTransaction *transaction))success
                                                  failure:(void (^)(NSError *error))failure {
    NSParameterAssert(completionQueue);
    GetTransactionRequest *transactionRequest = [[GetTransactionRequest alloc] init];
    transactionRequest.id_p = uint256_hex(transactionHash);
    DSDAPIGRPCResponseHandler *responseHandler = [[DSDAPIGRPCResponseHandler alloc] init];
    responseHandler.host = [NSString stringWithFormat:@"%@:%d", self.ipAddress, self.chain.standardDapiGRPCPort];
    responseHandler.dispatchQueue = self.grpcDispatchQueue;
    responseHandler.completionQueue = completionQueue;
    responseHandler.successHandler = ^(NSDictionary *successDictionary) {
        DSTransaction *transaction = [DSTransactionFactory transactionWithMessage:successDictionary[@"transactionData"] onChain:self.chain];
        //ToDo: set block height properly
        transaction.blockHeight = self.chain.lastChainLock ? self.chain.lastChainLock.height : self.chain.lastTerminalBlockHeight;
        if (transaction) {
            if (success) {
                success(transaction);
            }
        } else if (failure) {
            failure([NSError errorWithDomain:@"DashSync"
                                        code:404
                                    userInfo:@{NSLocalizedDescriptionKey:
                                                 DSLocalizedString(@"Transaction does not exist", nil)}]);
        }
    };
    responseHandler.errorHandler = failure;
    GRPCUnaryProtoCall *call = [self.gRPCClient getTransactionWithMessage:transactionRequest responseHandler:responseHandler callOptions:nil];
    [call start];
    return (id<DSDAPINetworkServiceRequest>)call;
}


@end
