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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const DSDAPIClientErrorDomain;

typedef NS_ENUM(NSUInteger, DSDAPIClientErrorCode) {
    DSDAPIClientErrorCodeInvalidResponse = 100,
};


typedef NS_ENUM(NSUInteger, DSDAPIClientStatusType) {
    DSDAPIClientStatusTypeInfo,
    DSDAPIClientStatusTypeDifficulty,
    DSDAPIClientStatusTypeBestBlockHash,
    DSDAPIClientStatusTypetLastBlockHash,
};

@class HTTPLoaderFactory;

@interface DSDAPIClientFetchDapObjectsOptions : NSObject

@property (readonly, nullable, copy, nonatomic) NSDictionary *where;
@property (readonly, nullable, copy, nonatomic) NSDictionary *orderBy;
@property (readonly, nullable, strong, nonatomic) NSNumber *limit;
@property (readonly, nullable, strong, nonatomic) NSNumber *startAt;
@property (readonly, nullable, strong, nonatomic) NSNumber *startAfter;

/**
 DSDAPIClientFetchDapObjectsOptions represents Fetch DAP Objects options

 @param where Mongo-like query  https://docs.mongodb.com/manual/reference/operator/query/
 @param orderBy Mongo-like sort field  https://docs.mongodb.com/manual/reference/method/cursor.sort/
 @param limit How many objects to fetch  https://docs.mongodb.com/manual/reference/method/cursor.limit/
 @param startAt Number of objects to skip  https://docs.mongodb.com/manual/reference/method/cursor.skip/
 @param startAfter Exclusive skip  https://docs.mongodb.com/manual/reference/method/cursor.skip/
 @return An initialized options object
 */
- (instancetype)initWithWhereQuery:(nullable NSDictionary *)where
                           orderBy:(nullable NSDictionary *)orderBy
                             limit:(nullable NSNumber *)limit
                           startAt:(nullable NSNumber *)startAt
                        startAfter:(nullable NSNumber *)startAfter;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface DSDAPIClient : NSObject

- (instancetype)initWithDAPINodeURL:(NSURL *)url httpLoaderFactory:(HTTPLoaderFactory *)httpLoaderFactory NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

///--------------
/// @name Layer 1
///--------------

/**
 Estimates the transaction fee necessary for confirmation to occur within a certain number of blocks
 
 @param numberOfBlocksToWait Number of blocks for fee estimate
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)estimateFeeWithNumberOfBlocksToWait:(NSUInteger)numberOfBlocksToWait
                                    success:(void (^)(NSNumber *duffsPerKilobyte))success
                                    failure:(void (^)(NSError *error))failure;

/**
 Get an address summary given an address
 
 @param address Dash address
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getAddressSummary:(NSString *)address
                  success:(void (^)(NSDictionary *addressSummary))success
                  failure:(void (^)(NSError *error))failure;

/**
 Get the total amount of duffs received by an address
 
 @param address Dash address
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getAddressTotalReceived:(NSString *)address
                        success:(void (^)(NSNumber *duffsReceivedByAddress))success
                        failure:(void (^)(NSError *error))failure;

/**
 Get the total amount of duffs sent by an address
 
 @param address Dash address
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getAddressTotalSent:(NSString *)address
                    success:(void (^)(NSNumber *duffsSentByAddress))success
                    failure:(void (^)(NSError *error))failure;

/**
 Get the total unconfirmed balance for the address
 
 @param address Dash address
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getAddressUnconfirmedBalance:(NSString *)address
                             success:(void (^)(NSNumber *unconfirmedBalance))success
                             failure:(void (^)(NSError *error))failure;

/**
 Get the calculated balance for the address
 
 @param address Dash address
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getBalanceForAddress:(NSString *)address
                     success:(void (^)(NSNumber *balance))success
                     failure:(void (^)(NSError *error))failure;

/**
 Get the best block height
 
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getBestBlockHeightSuccess:(void (^)(NSNumber *blockHeight))success
                          failure:(void (^)(NSError *error))failure;

/**
 Get the block hash for the given height
 
 @param height Block height
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getBlockHashForHeight:(NSUInteger)height
                      success:(void (^)(NSString *blockHash))success
                      failure:(void (^)(NSError *error))failure;


/**
 Get the block header corresponding to the requested block hash
 
 @param blockHash Block hash
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getBlockHeaderForHash:(NSString *)blockHash
                      success:(void (^)(NSArray<NSDictionary *> *blockHeaders))success
                      failure:(void (^)(NSError *error))failure;

/**
 Get the requested number of block headers starting at the requested height
 
 @param offset Lowest block height to include
 @param limit The number of headers to return (0 < limit <=25)
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getBlockHeadersFromOffset:(NSUInteger)offset
                            limit:(NSUInteger)limit
                          success:(void (^)(NSArray<NSDictionary *> *blockHeaders))success
                          failure:(void (^)(NSError *error))failure;

/**
 Get info for blocks meeting the provided criteria
 
 @param date Starting date for blocks to get
 @param limit Number of blocks to return
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getBlocksStartingDate:(NSDate *)date
                        limit:(NSUInteger)limit
                      success:(void (^)(NSArray<NSDictionary *> *blockHeaders))success
                      failure:(void (^)(NSError *error))failure;

/**
 Get historic blockchain data sync status
 
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getHistoricBlockchainDataSyncStatusSuccess:(void (^)(NSDictionary *historicStatus))success
                                           failure:(void (^)(NSError *error))failure;

/**
 Get masternode list
 
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getMNListSuccess:(void (^)(NSArray<NSDictionary *> *mnList))success
                 failure:(void (^)(NSError *error))failure;

/**
 Get masternode list diff for the provided block hashes
 
 @param baseBlockHash Block hash
 @param blockHash Block hash
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getMNListDiffBaseBlockHash:(NSString *)baseBlockHash
                         blockHash:(NSString *)blockHash
                           success:(void (^)(NSArray<NSDictionary *> *mnListDiff))success
                           failure:(void (^)(NSError *error))failure;

/**
 Get peer data sync status
 
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getPeerDataSyncStatusSuccess:(void (^)(NSDictionary *syncStatus))success
                             failure:(void (^)(NSError *error))failure;


/**
 Get a user quorum (LLMQ)
 
 @param regTxId The TXID of the user's registration subscription transaction
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getQuorumRegTxId:(NSString *)regTxId
                 success:(void (^)(NSDictionary *rawBlock))success
                 failure:(void (^)(NSError *error))failure;

/**
 Get the raw block for the provided block hash
 
 @param blockHash Block hash
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getRawBlock:(NSString *)blockHash
            success:(void (^)(NSDictionary *rawBlock))success
            failure:(void (^)(NSError *error))failure;

/**
 Get block headers
 
 @param filter A bloom filter
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getSpvDataForFilter:(nullable NSString *)filter
                    success:(void (^)(NSDictionary *blockHeaders))success
                    failure:(void (^)(NSError *error))failure;

/**
 Get status for provided type
 
 @param status Type of status to get
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getStatus:(DSDAPIClientStatusType)status
          success:(void (^)(id response))success
          failure:(void (^)(NSError *error))failure;

/**
 Get transaction for the given hash
 
 @param txid The TXID of the transaction
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getTransactionById:(NSString *)txid
                   success:(void (^)(NSDictionary *tx))success
                   failure:(void (^)(NSError *error))failure;

/**
 Get all transaction related to the given address
 
 @param address Dash address
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getTransactionsByAddress:(NSString *)address
                         success:(void (^)(NSArray<NSDictionary *> *addressTXs))success
                         failure:(void (^)(NSError *error))failure;

/**
 Get unspent outputs for the given address
 
 @param address Dash address
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getUTXOForAddress:(NSString *)address
                  success:(void (^)(NSArray<NSDictionary *> *unspentOutputs))success
                  failure:(void (^)(NSError *error))failure;

/**
 Sends raw InstantSend transaction and returns the transaction ID
 
 @param rawIxTransaction Hex-serialized InstaSend transaction
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)sendRawIxTransaction:(NSString *)rawIxTransaction
                     success:(void (^)(NSString *txid))success
                     failure:(void (^)(NSError *error))failure;


/**
 Sends raw transaction and returns the transaction ID
 
 @param rawTransaction Hex-serialized transaction
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)sendRawTransaction:(NSString *)rawTransaction
                   success:(void (^)(NSString *txid))success
                   failure:(void (^)(NSError *error))failure;

/**
 Adds an element to an existing bloom filter
 
 @param originalFilter Original filter
 @param element Element to add to filter
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)addToBloomFilterWithOriginalFilter:(NSString *)originalFilter
                                   element:(NSString *)element
                                   success:(void (^)(BOOL result))success
                                   failure:(void (^)(NSError *error))failure;

/**
 Clear the bloom filter
 
 @param filter Original filter
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)clearBloomFilter:(NSString *)filter
                 success:(void (^)(BOOL result))success
                 failure:(void (^)(NSError *error))failure;

/**
 Load a bloom filter
 
 @param filter Filter to load
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)loadBloomFilter:(NSString *)filter
                success:(void (^)(BOOL result))success
                failure:(void (^)(NSError *error))failure;

///--------------
/// @name Layer 2
///--------------

/**
 Fetch a user's DAP space
 
 @param dapId A user's DAP ID
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)fetchDapContractForId:(NSString *)dapId
                      success:(void (^)(NSDictionary *dapSpace))success
                      failure:(void (^)(NSError *error))failure;

/**
 Get a blockchain user by username
 
 @param username Blockchain user's username
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getUserByName:(NSString *)username
              success:(void (^)(NSDictionary *blockchainUser))success
              failure:(void (^)(NSError *error))failure;

/**
 Get a blockchain user by ID
 
 @param userId Blockchain user's ID
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getUserById:(NSString *)userId
            success:(void (^)(NSDictionary *blockchainUser))success
            failure:(void (^)(NSError *error))failure;

/**
 Get a list of users after matching search criteria
 
 @param pattern Search pattern
 @param offset Starting amount of results to return
 @param limit Limit of search results to return
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)searchUsersWithPattern:(NSString *)pattern
                        offset:(NSUInteger)offset
                         limit:(NSUInteger)limit
                       success:(void (^)(NSArray<NSDictionary *> *blockchainUsers, NSUInteger totalCount))success
                       failure:(void (^)(NSError *error))failure;

/**
 Sends raw state transition to the network
 
 @param rawTransitionHeader Hex-string representing state transition header
 @param rawTransitionPacket Hex-string representing state transition data
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)sendRawTransitionWithRawTransitionHeader:(NSString *)rawTransitionHeader
                             rawTransitionPacket:(NSString *)rawTransitionPacket
                                         success:(void (^)(NSString *headerId))success
                                         failure:(void (^)(NSError *error))failure;

/**
 Fetches user objects for a given condition
 
 @param dapId A user's DAP ID
 @param objectsType DAP object type to fetch
 @param options Fetch options
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)fetchDapObjectsForId:(NSString *)dapId
                 objectsType:(NSString *)objectsType
                     options:(nullable DSDAPIClientFetchDapObjectsOptions *)options
                     success:(void (^)(NSArray<NSDictionary *> *dapObjects))success
                     failure:(void (^)(NSError *error))failure;

@end

NS_ASSUME_NONNULL_END
