//
//  DSDAPIProtocol.h
//  DashSync
//
//  Created by Sam Westrich on 9/13/18.
//

#import <Foundation/Foundation.h>

@protocol DSDAPIProtocol <NSObject>

-(void)getBestBlockHeightWithSuccess:(void (^)(NSNumber *blockHeight))success failure:(void (^)(NSError *error))failure;

-(void)getAddressSummaryWithSuccess:(void (^)(NSDictionary *addressInfo))success failure:(void (^)(NSError *error))failure;

@end
