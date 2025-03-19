//
//  Created by Sam Westrich
//  Copyright © 2018-2019 Dash Core Group. All rights reserved.
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

#import "BigIntTypes.h"
#import "DSDAPIClientFetchDapObjectsOptions.h"
#import "DSDAPINetworkServiceRequest.h"
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, DSPlatformStoredMessage)
{
    /// The item does not exist for the specified key
    DSPlatformStoredMessage_NotPresent = 0,
    /// The version is prepended before all items
    DSPlatformStoredMessage_Version,
    /// An item can be returned if decode is set to true
    DSPlatformStoredMessage_Item,
    /// A data item that can be returned if decode is set to false
    DSPlatformStoredMessage_Data,
};

#define DAPI_DOCUMENT_RESPONSE_COUNT_LIMIT 100

NS_ASSUME_NONNULL_BEGIN

extern NSString *const DSDAPINetworkServiceErrorDomain;

typedef NS_ENUM(NSUInteger, DSDAPINetworkServiceErrorCode)
{
    DSDAPINetworkServiceErrorCodeInvalidResponse = 100,
};

@class DSTransition, DSPlatformDocumentsRequest, DSBlockchainIdentity;

@protocol DSDAPIPlatformNetworkServiceProtocol <NSObject>

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
 Get an address summary given an addresses
 
 @param addresses Dash addresses
 @param noTxList true if a list of all txs should NOT be included in result
 @param from start of range for the tx to be included in the tx list
 @param to end of range for the tx to be included in the tx list
 @param fromHeight which height to start from (optional, overriding from/to)
 @param toHeight on which height to end (optional, overriding from/to)
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getAddressSummary:(NSArray<NSString *> *)addresses
                 noTxList:(BOOL)noTxList
                     from:(NSNumber *)from
                       to:(NSNumber *)to
               fromHeight:(nullable NSNumber *)fromHeight
                 toHeight:(nullable NSNumber *)toHeight
                  success:(void (^)(NSDictionary *addressSummary))success
                  failure:(void (^)(NSError *error))failure;

/**
 Get the total amount of duffs received by an addresses
 
 @param addresses Dash addresses
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getAddressTotalReceived:(NSArray<NSString *> *)addresses
                        success:(void (^)(NSNumber *duffsReceivedByAddress))success
                        failure:(void (^)(NSError *error))failure;

/**
 Get the total amount of duffs sent by an addresses
 
 @param addresses Dash addresses
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getAddressTotalSent:(NSArray<NSString *> *)addresses
                    success:(void (^)(NSNumber *duffsSentByAddress))success
                    failure:(void (^)(NSError *error))failure;

/**
 Get the total unconfirmed balance for the addresses
 
 @param addresses Dash addresses
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getAddressUnconfirmedBalance:(NSArray<NSString *> *)addresses
                             success:(void (^)(NSNumber *unconfirmedBalance))success
                             failure:(void (^)(NSError *error))failure;

/**
 Get the calculated balance for the addresses
 
 @param addresses Dash addresses
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getBalanceForAddress:(NSArray<NSString *> *)addresses
                     success:(void (^)(NSNumber *balance))success
                     failure:(void (^)(NSError *error))failure;

/**
 Returns block hash of chaintip

 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getBestBlockHashSuccess:(void (^)(NSString *blockHeight))success
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
 Returns mempool usage info

 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getMempoolInfoSuccess:(void (^)(NSNumber *blockHeight))success
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
                           success:(void (^)(NSDictionary *mnListDiff))success
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
 Get transaction for the given hash
 
 @param txid The TXID of the transaction
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getTransactionById:(NSString *)txid
                   success:(void (^)(NSDictionary *tx))success
                   failure:(void (^)(NSError *error))failure;

/**
 Get transactions for a given address or multiple addresses
 
 @param addresses Dash addresses
 @param from start of range for the tx to be included in the tx list
 @param to end of range for the tx to be included in the tx list
 @param fromHeight which height to start from (optional, overriding from/to)
 @param toHeight on which height to end (optional, overriding from/to)
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getTransactionsByAddress:(NSArray<NSString *> *)addresses
                            from:(NSNumber *)from
                              to:(NSNumber *)to
                      fromHeight:(nullable NSNumber *)fromHeight
                        toHeight:(nullable NSNumber *)toHeight
                         success:(void (^)(NSDictionary *result))success
                         failure:(void (^)(NSError *error))failure;

/**
 Get UTXO for a given address or multiple addresses (max result 1000)
 
 @param addresses Dash addresses
 @param from start of range in the ordered list of latest UTXO (optional)
 @param to end of range in the ordered list of latest UTXO (optional)
 @param fromHeight which height to start from (optional, overriding from/to)
 @param toHeight on which height to end (optional, overriding from/to)
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (void)getUTXOForAddress:(NSArray<NSString *> *)addresses
                     from:(nullable NSNumber *)from
                       to:(nullable NSNumber *)to
               fromHeight:(nullable NSNumber *)fromHeight
                 toHeight:(nullable NSNumber *)toHeight
                  success:(void (^)(NSDictionary *result))success
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
 Fetch a user's Contract
 
 @param contractId A user's Contract ID
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (id<DSDAPINetworkServiceRequest>)fetchContractForId:(NSData *)contractId
                                      completionQueue:(dispatch_queue_t)completionQueue
                                              success:(void (^)(NSDictionary *contract))success
                                              failure:(void (^)(NSError *error))failure;

/**
 Get a blockchain user by username
 
 @param username Blockchain user's username
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (id<DSDAPINetworkServiceRequest> _Nullable)getIdentityByName:(NSString *)username
                                                      inDomain:(NSString *)domain
                                               completionQueue:(dispatch_queue_t)completionQueue
                                                       success:(void (^)(NSDictionary *_Nullable blockchainIdentity))success
                                                       failure:(void (^)(NSError *error))failure;

/**
 Get a blockchain user by ID
 
 @param userId Blockchain user's ID
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (id<DSDAPINetworkServiceRequest>)getIdentityById:(NSData *)userId
                                   completionQueue:(dispatch_queue_t)completionQueue
                                           success:(void (^)(NSDictionary *_Nullable blockchainIdentity))success
                                           failure:(void (^)(NSError *error))failure;

/**
 Sends raw state transition to the network
 
 @param stateTransition Hex-string representing state transition header
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (id<DSDAPINetworkServiceRequest>)publishTransition:(DSTransition *)stateTransition
                                     completionQueue:(dispatch_queue_t)completionQueue
                                             success:(void (^)(NSDictionary *successDictionary, BOOL added))success
                                             failure:(void (^)(NSError *error))failure;

/**
 Fetches user documents for a given condition
 
 @param platformDocumentsRequest The fetch request
 @param success A block object to be executed when the request operation finishes successfully
 @param failure A block object to be executed when the request operation finishes unsuccessfully
 */
- (id<DSDAPINetworkServiceRequest>)fetchDocumentsWithRequest:(DSPlatformDocumentsRequest *)platformDocumentsRequest
                                             completionQueue:(dispatch_queue_t)completionQueue
                                                     success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                     failure:(void (^)(NSError *error))failure;

- (id<DSDAPINetworkServiceRequest>)getDPNSDocumentsForPreorderSaltedDomainHashes:(NSArray *)saltedDomainHashes
                                                                 completionQueue:(dispatch_queue_t)completionQueue
                                                                         success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                                         failure:(void (^)(NSError *error))failure;

- (id<DSDAPINetworkServiceRequest>)getDPNSDocumentsForUsernames:(NSArray *)usernames
                                                       inDomain:(NSString *)domain
                                                completionQueue:(dispatch_queue_t)completionQueue
                                                        success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                        failure:(void (^)(NSError *error))failure;

- (id<DSDAPINetworkServiceRequest>)getDPNSDocumentsForIdentityWithUserId:(NSData *)userId
                                                         completionQueue:(dispatch_queue_t)completionQueue
                                                                 success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                                 failure:(void (^)(NSError *error))failure;

/**
Get a list of users after matching search criteria

@param usernamePrefix The username prefix that will be searched upon
@param domain The domain in which to search
@param startAfter Starting amount of results to return
@param limit Limit of search results to return
@param success A block object to be executed when the request operation finishes successfully
@param failure A block object to be executed when the request operation finishes unsuccessfully
*/
- (id<DSDAPINetworkServiceRequest>)searchDPNSDocumentsForUsernamePrefix:(NSString *)usernamePrefix
                                                               inDomain:(NSString *)domain
                                                             startAfter:(NSData* _Nullable)startAfter
                                                                  limit:(uint32_t)limit
                                                        completionQueue:(dispatch_queue_t)completionQueue
                                                                success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                                failure:(void (^)(NSError *error))failure;

- (id<DSDAPINetworkServiceRequest>)getDashpayIncomingContactRequestsForUserId:(NSData *)userId
                                                                        since:(NSTimeInterval)timestamp
                                                                   startAfter:(NSData* _Nullable)startAfter
                                                              completionQueue:(dispatch_queue_t)completionQueue
                                                                      success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                                      failure:(void (^)(NSError *error))failure;

- (id<DSDAPINetworkServiceRequest>)getDashpayOutgoingContactRequestsForUserId:(NSData *)userId
                                                                        since:(NSTimeInterval)timestamp
                                                                   startAfter:(NSData* _Nullable)startAfter
                                                              completionQueue:(dispatch_queue_t)completionQueue
                                                                      success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                                      failure:(void (^)(NSError *error))failure;

- (id<DSDAPINetworkServiceRequest>)getDashpayProfileForUserId:(NSData *)userId
                                              completionQueue:(dispatch_queue_t)completionQueue
                                                      success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                      failure:(void (^)(NSError *error))failure;

- (id<DSDAPINetworkServiceRequest>)getDashpayProfilesForUserIds:(NSArray<NSData *> *)userId
                                                completionQueue:(dispatch_queue_t)completionQueue
                                                        success:(void (^)(NSArray<NSDictionary *> *documents))success
                                                        failure:(void (^)(NSError *error))failure;

/**
Get a list of identities knowing only keys they possess

@param keyHashesArray An array of hashes of keys
@param completionQueue The queue in which to return the result on
@param success A block object to be executed when the request operation finishes successfully
@param failure A block object to be executed when the request operation finishes unsuccessfully
*/
- (id<DSDAPINetworkServiceRequest>)fetchIdentitiesByKeyHashes:(NSArray<NSData *> *)keyHashesArray
                                              completionQueue:(dispatch_queue_t)completionQueue
                                                      success:(void (^)(NSArray<NSDictionary *> *identityDictionaries))success
                                                      failure:(void (^)(NSError *error))failure;

/**
Get a list of identity Ids knowing only keys they possess

@param keyHashesArray An array of hashes of keys
@param completionQueue The queue in which to return the result on
@param success A block object to be executed when the request operation finishes successfully
@param failure A block object to be executed when the request operation finishes unsuccessfully
*/
- (id<DSDAPINetworkServiceRequest>)fetchIdentityIdsByKeyHashes:(NSArray<NSData *> *)keyHashesArray
                                               completionQueue:(dispatch_queue_t)completionQueue
                                                       success:(void (^)(NSArray<NSData *> *identityIds))success
                                                       failure:(void (^)(NSError *error))failure;

@end

NS_ASSUME_NONNULL_END
