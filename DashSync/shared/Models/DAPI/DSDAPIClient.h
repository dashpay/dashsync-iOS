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

#import "BigIntTypes.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const DSDAPIClientErrorDomain;

typedef NS_ENUM(NSUInteger, DSDAPIClientErrorCode)
{
    DSDAPIClientErrorCodeSignTransitionFailed = 1,
    DSDAPIClientErrorCodeNoKnownDAPINodes = 2,
};

@class DSChain, DSBlockchainIdentity, DPDocument, DSTransition, DPSTPacket, DPContract, DSDAPIPlatformNetworkService, DSDAPICoreNetworkService, DSPeer, DSSimplifiedMasternodeEntry;

@interface DSDAPIClient : NSObject

@property (readonly, nonatomic) DSChain *chain;
@property (nonatomic, nullable, readonly) DSDAPIPlatformNetworkService *DAPIPlatformNetworkService;
@property (nonatomic, nullable, readonly) DSDAPICoreNetworkService *DAPICoreNetworkService;
@property (nonatomic, readonly) NSMutableSet<NSString *> *availablePeers;
@property (nonatomic, readonly) NSMutableSet<NSString *> *trustedPeers;
@property (nonatomic, readwrite) NSMutableSet<NSString *> *whiteList;
@property (atomic, readonly) dispatch_queue_t coreNetworkingDispatchQueue;
@property (atomic, readonly) dispatch_queue_t platformMetadataDispatchQueue;

- (instancetype)initWithChain:(DSChain *)chain NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)addDAPINodeByAddress:(NSString *)host;

- (void)removeDAPINodeByAddress:(NSString *)host;

- (void)getAllStateTransitionsForUser:(DSBlockchainIdentity *)blockchainIdentity completion:(void (^)(NSError *_Nullable error))completion;

- (void)sendDocument:(DPDocument *)document
         forIdentity:(DSBlockchainIdentity *)blockchainIdentity
            contract:(DPContract *)contract
          completion:(void (^)(NSError *_Nullable error))completion;

- (void)publishTransition:(DSTransition *)stateTransition
          completionQueue:(dispatch_queue_t)completionQueue
                  success:(void (^)(NSDictionary *successDictionary, BOOL added))success
                  failure:(void (^)(NSError *error))failure;

- (void)publishTransition:(DSTransition *)stateTransition
                  success:(void (^)(NSDictionary *successDictionary, BOOL added))success
                  failure:(void (^)(NSError *error))failure;

- (void)checkPingTimesForMasternodes:(NSArray<DSSimplifiedMasternodeEntry *> *)masternodes completion:(void (^)(NSMutableDictionary<NSData *, NSNumber *> *pingTimes, NSMutableDictionary<NSData *, NSError *> *))completion;
@end

NS_ASSUME_NONNULL_END
