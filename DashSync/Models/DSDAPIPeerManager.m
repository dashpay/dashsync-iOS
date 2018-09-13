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
    return [NSURL URLWithString:@"54.169.131.115:3000"];
}

-(AFJSONRPCClient*)client {
    return [AFJSONRPCClient clientWithEndpointURL:[self mainDAPINodeURL]];
}

// MARK:- Layer 1 Calls

-(void)getBestBlockHeightWithSuccess:(void (^)(NSNumber *))success failure:(void (^)(NSError *))failure {
    [self.client invokeMethod:@"getBestBlockHeight" success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getAddressSummaryWithSuccess:(void (^)(NSDictionary *addressInfo))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getAddressSummary" success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

// MARK:- Layer 2 Calls

// MARK:- MetaData Calls

@end
