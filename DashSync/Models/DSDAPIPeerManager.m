//
//  DSDAPIPeerManager.m
//  DashSync
//
//  Created by Sam Westrich on 9/12/18.
//

#import "DSDAPIPeerManager.h"
#import "AFJSONRPCClient.h"
#import "DSChain.h"
#import "DSDAPIProtocol.h"
#import "NSData+Bitcoin.h"

@interface DSDAPIPeerManager()
@property (nonatomic,readonly) AFJSONRPCClient * client;
@end

@implementation DSDAPIPeerManager

-(instancetype)initWithChainPeerManager:(DSChainPeerManager*)chainPeerManager
{
    if (! (self = [super init])) return nil;
    _chainPeerManager = chainPeerManager;
    return self;
}

-(NSURL*)mainDAPINodeURL {
    return [NSURL URLWithString:@"http://54.169.131.115:3000"];
}

-(AFJSONRPCClient*)client {
    return [AFJSONRPCClient clientWithEndpointURL:[self mainDAPINodeURL]];
}

// MARK:- Layer 1 General Calls

-(void)getBestBlockHeightWithSuccess:(void (^)(NSNumber *))success failure:(void (^)(NSError *))failure {
    [self.client invokeMethod:@"getBestBlockHeight" success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

// MARK:- Layer 1 Address Calls

-(void)getAddressSummary:(NSString*)address withSuccess:(void (^)(NSDictionary *addressInfo))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getAddressSummary" withParameters:@{@"address":address} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getAddressTotalReceived:(NSString*)address withSuccess:(void (^)(NSNumber *duffs))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getAddressTotalReceived" withParameters:@{@"address":address} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getAddressTotalSent:(NSString*)address withSuccess:(void (^)(NSNumber *duffs))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getAddressTotalSent" withParameters:@{@"address":address} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getAddressUnconfirmedBalance:(NSString*)address withSuccess:(void (^)(NSNumber *duffs))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getAddressUnconfirmedBalance" withParameters:@{@"address":address} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getAddressBalance:(NSString*)address withSuccess:(void (^)(NSNumber *duffs))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getBalance" withParameters:@{@"address":address} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

// MARK:- Layer 2 Calls

-(void)getUserByUsername:(NSString*)username withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getUser" withParameters:@{@"username":username} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getUserByRegistrationTransactionId:(UInt256)registrationTransactionId withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getUser" withParameters:@{@"regTxId":[NSData dataWithUInt256:registrationTransactionId].hexString} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getDAPsMatching:(NSString*)matching withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"searchDapContracts" withParameters:@{@"pattern":matching} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

// MARK:- MetaData Calls

@end
