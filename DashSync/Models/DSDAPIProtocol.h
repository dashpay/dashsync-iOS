//
//  DSDAPIProtocol.h
//  DashSync
//
//  Created by Sam Westrich on 9/13/18.
//

#import <Foundation/Foundation.h>
#import "IntTypes.h"

@class DSTransaction,DSMerkleBlock;

@protocol DSDAPIProtocol <NSObject>

// MARK:- Layer 1 General Calls

-(void)getBestBlockHeightWithSuccess:(void (^)(NSNumber *blockHeight))success failure:(void (^)(NSError *error))failure;
-(void)getPeerDataSyncStatus:(void (^)(NSNumber *))success failure:(void (^)(NSError *))failure;

// MARK:- Layer 1 Bloom Filter Calls

-(void)loadBloomFilter:(NSString*)filter withSuccess:(void (^)(BOOL success))success failure:(void (^)(NSError *error))failure;

-(void)clearBloomFilter:(NSString*)filter withSuccess:(void (^)(BOOL success))success failure:(void (^)(NSError *error))failure;

// MARK:- Layer 1 Blocks Calls

-(void)getBlocksFromDate:(NSDate*)date limit:(NSUInteger)limit withSuccess:(void (^)(NSArray * blocks))success failure:(void (^)(NSError *error))failure;

// MARK:- Layer 1 Transaction Calls

-(void)sendRawTransaction:(NSString*)address withSuccess:(void (^)(UInt256 transactionHashId))success failure:(void (^)(NSError *error))failure;
-(void)sendRawInstantSendTransaction:(NSString*)address withSuccess:(void (^)(UInt256 transactionHashId))success failure:(void (^)(NSError *error))failure;

-(void)getTransactionsByAddress:(NSString*)address withSuccess:(void (^)(NSArray * transactions))success failure:(void (^)(NSError *error))failure;

-(void)getTransactionById:(UInt256)transactionId withSuccess:(void (^)(DSTransaction * transaction))success failure:(void (^)(NSError *error))failure;


-(void)getAddressSummary:(NSString*)address withSuccess:(void (^)(NSDictionary *addressInfo))success failure:(void (^)(NSError *error))failure;
-(void)getAddressTotalReceived:(NSString*)address withSuccess:(void (^)(NSNumber *duffs))success failure:(void (^)(NSError *error))failure;

-(void)getAddressTotalSent:(NSString*)address withSuccess:(void (^)(NSNumber *duffs))success failure:(void (^)(NSError *error))failure;


-(void)getAddressUnconfirmedBalance:(NSString*)address withSuccess:(void (^)(NSNumber *duffs))success failure:(void (^)(NSError *error))failure;

-(void)getAddressBalance:(NSString*)address withSuccess:(void (^)(NSNumber *duffs))success failure:(void (^)(NSError *error))failure;

-(void)getAddressUTXOs:(NSString*)address withSuccess:(void (^)(NSArray *addressUTXOs))success failure:(void (^)(NSError *error))failure;

// MARK:- Layer 1/2 Transition Calls

-(void)sendRawTransition:(NSData*)stateTransitionData transitionData:(NSData*)data withSuccess:(void (^)(UInt256 transitionHashId))success failure:(void (^)(NSError *error))failure;

-(void)registerDapContract:(NSData*)dapContractData withStateTransitionData:(NSData*)stateTransitionData withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure;

// MARK:- Layer 2 Schema Calls

-(void)getDapContractsWithSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure;

-(void)getDAPsMatching:(NSString*)matching withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure;

-(void)getDAPsWithSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure;

//fetches Dap Contract (schema definition of specified DAP).
-(void)fetchDapContract:(void (^)(NSDictionary *dapInfo))success failure:(void (^)(NSError *error))failure;


// MARK:- Layer 2 User Daps Calls

-(void)getUserDapSpaceForUser:(NSString*)userId forDap:(NSString*)dapId withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure;

-(void)getUserDapContextForUser:(NSString*)userId forDap:(NSString*)dapId withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure;

// MARK:- Layer 2 User Info Calls

-(void)searchUsers:(NSString*)pattern limit:(NSUInteger)limit offset:(NSUInteger)offset withSuccess:(void (^)(NSArray *users))success failure:(void (^)(NSError *error))failure;

-(void)getUserByUsername:(NSString*)username withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure;
-(void)getUserByRegistrationTransactionId:(UInt256)registrationTransactionId withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure;



@end
