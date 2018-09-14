//
//  DSDAPIProtocol.h
//  DashSync
//
//  Created by Sam Westrich on 9/13/18.
//

#import <Foundation/Foundation.h>
#import "IntTypes.h"

@protocol DSDAPIProtocol <NSObject>

-(void)getBestBlockHeightWithSuccess:(void (^)(NSNumber *blockHeight))success failure:(void (^)(NSError *error))failure;
-(void)getAddressSummary:(NSString*)address withSuccess:(void (^)(NSDictionary *addressInfo))success failure:(void (^)(NSError *error))failure;
-(void)getAddressTotalReceived:(NSString*)address withSuccess:(void (^)(NSNumber *duffs))success failure:(void (^)(NSError *error))failure;

-(void)getAddressTotalSent:(NSString*)address withSuccess:(void (^)(NSNumber *duffs))success failure:(void (^)(NSError *error))failure;


-(void)getAddressUnconfirmedBalance:(NSString*)address withSuccess:(void (^)(NSNumber *duffs))success failure:(void (^)(NSError *error))failure;

-(void)getAddressBalance:(NSString*)address withSuccess:(void (^)(NSNumber *duffs))success failure:(void (^)(NSError *error))failure;

// MARK:- Layer 2 Calls

-(void)getUserByUsername:(NSString*)username withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure;
-(void)getUserByRegistrationTransactionId:(UInt256)registrationTransactionId withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure;

-(void)getDAPsMatching:(NSString*)matching withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure;

@end
