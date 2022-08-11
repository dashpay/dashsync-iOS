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

#import "DSDAPIClient.h"

#import "DSChain+Protected.h"
#import "DSDAPICoreNetworkService.h"
#import "DSDAPIPlatformNetworkService.h"
#import "DSDashPlatform.h"
#import "DSDocumentTransition.h"
#import "DSIdentitiesManager+Protected.h"
#import "NSError+Dash.h"
#import <DashSync/DSTransition.h>
#import <DashSync/DashSync.h>
#import <arpa/inet.h>

NSErrorDomain const DSDAPIClientErrorDomain = @"DSDAPIClientErrorDomain";

#define DAPI_SINGLE_NODE @"54.191.199.25"
#define DAPI_CONNECT_SINGLE_NODE FALSE
#define DAPI_DEFAULT_PUBLISH_TRANSITION_RETRY_COUNT 10

@interface DSDAPIClient ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) NSMutableSet<NSString *> *availablePeers;
@property (nonatomic, strong) NSMutableSet<NSString *> *usedPeers;
@property (nonatomic, strong) NSMutableArray<DSDAPIPlatformNetworkService *> *activePlatformServices;
@property (nonatomic, strong) NSMutableArray<DSDAPICoreNetworkService *> *activeCoreServices;
@property (atomic, strong) dispatch_queue_t coreNetworkingDispatchQueue;
@property (atomic, strong) dispatch_queue_t platformMetadataDispatchQueue;

@end

@implementation DSDAPIClient

- (instancetype)initWithChain:(DSChain *)chain {
    self = [super init];
    if (self) {
        _chain = chain;
        self.availablePeers = [NSMutableSet set];
        self.activePlatformServices = [NSMutableArray array];
        self.activeCoreServices = [NSMutableArray array];
        self.coreNetworkingDispatchQueue = self.chain.networkingQueue;
        self.platformMetadataDispatchQueue = self.chain.dapiMetadataQueue;
    }
    return self;
}

//- (void)sendDocument:(DPDocument *)document
//             forUser:(DSBlockchainIdentity*)blockchainIdentity
//            contract:(DPContract *)contract
//          completion:(void (^)(NSError *_Nullable error))completion {
//    NSParameterAssert(document);
//    NSParameterAssert(contract);
//
//    NSArray *documents = @[ document ];
//
//    DSDashPlatform *platform = [DSDashPlatform sharedInstanceForChain:self.chain];
//
//    DSDocumentTransition *transition = [blockchainIdentity documentTransition];
//
//    DPSTPacket *stPacket = [platform.stPacketFactory packetWithContractId:contract.identifier documents:documents];
//    [self sendPacket:stPacket forUser:blockchainIdentity completion:completion];
//}

- (void)sendDocument:(DPDocument *)document
         forIdentity:(DSBlockchainIdentity *)blockchainIdentity
            contract:(DPContract *)contract
          completion:(void (^)(NSError *_Nullable error))completion {
    NSParameterAssert(document);
    NSParameterAssert(contract);

    DSDocumentTransition *documentTransition = [[DSDocumentTransition alloc] initForDocuments:@[document] withTransitionVersion:1 blockchainIdentityUniqueId:blockchainIdentity.uniqueID onChain:self.chain];

    __weak typeof(self) weakSelf = self;
    [blockchainIdentity signStateTransition:documentTransition
                                 completion:^(BOOL success) {
                                     __strong typeof(weakSelf) strongSelf = weakSelf;
                                     if (!strongSelf) {
                                         if (completion) {
                                             completion([NSError errorWithCode:500 localizedDescriptionKey:@"Internal memory allocation error"]);
                                         }
                                         return;
                                     }

                                     if (success) {
                                         [strongSelf publishTransition:documentTransition
                                             success:^(NSDictionary *_Nonnull successDictionary, BOOL added) {
                                                 if (completion) {
                                                     completion(nil);
                                                 }
                                             }
                                             failure:^(NSError *_Nonnull error) {
                                                 if (completion) {
                                                     completion(error);
                                                 }
                                             }];
                                     } else {
                                         if (completion) {
                                             NSError *error = [NSError errorWithDomain:DSDAPIClientErrorDomain
                                                                                  code:DSDAPIClientErrorCodeSignTransitionFailed
                                                                              userInfo:nil];
                                             completion(error);
                                         }
                                     }
                                 }];
}

- (void)getAllStateTransitionsForUser:(DSBlockchainIdentity *)blockchainIdentity completion:(void (^)(NSError *_Nullable error))completion {
    //    DSDAPINetworkService * service = self.DAPINetworkService;
    //    if (!service) {
    //        completion([NSError errorWithDomain:DSDAPIClientErrorDomain
    //                                       code:DSDAPIClientErrorCodeNoKnownDAPINodes
    //                                   userInfo:@{NSLocalizedDescriptionKey:@"No known DAPI Nodes"}]);
    //        return;
    //    }
    //    [service getUserById:uint256_reverse_hex(blockchainIdentity.registrationTransitionHash) success:^(NSDictionary * _Nonnull blockchainIdentityDictionary) {
    //        if ([blockchainIdentityDictionary objectForKey:@"subtx"] && [[blockchainIdentityDictionary objectForKey:@"subtx"] isKindOfClass:[NSArray class]]) {
    //            NSArray * subscriptionTransactions = [blockchainIdentityDictionary objectForKey:@"subtx"];
    //            NSMutableArray * oldSubscriptionTransactionHashes = [NSMutableArray array];
    //            for (DSTransaction * transaction in blockchainIdentity.allTransitions) {
    //                [oldSubscriptionTransactionHashes addObject:[NSData dataWithUInt256:transaction.txHash]];
    //            }
    //            NSMutableArray * novelSubscriptionTransactionHashes = [NSMutableArray array];
    //            for (NSString * possiblyNewSubscriptionTransactionHashString in subscriptionTransactions) {
    //                NSData * data = possiblyNewSubscriptionTransactionHashString.hexToData;
    //                if (![oldSubscriptionTransactionHashes containsObject:data]) {
    //                    [novelSubscriptionTransactionHashes addObject:data];
    //                }
    //            }
    //            for (NSData * unknownSubscriptionTransactionHash in novelSubscriptionTransactionHashes) {
    //                //dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    //                [service getTransactionById:unknownSubscriptionTransactionHash.hexString success:^(NSDictionary * _Nonnull tx) {
    //                    if (tx[@"version"] && tx[@"blockheight"] && tx[@"extraPayload"] && tx[@"valueIn"] && tx[@"valueOut"] && ([tx[@"valueIn"] integerValue] + [tx[@"valueOut"] integerValue] == 0)) {
    //                        DSLogPrivate(@"state transition %@",tx);
    //                        //this is a transition
    //                        NSString * extraPayload = tx[@"extraPayload"];
    //                        uint16_t version = [tx[@"version"] shortValue];
    //                        DSTransition * transition = [[DSTransition alloc] initWithVersion:version payloadData:extraPayload.hexToData onChain:blockchainIdentity.wallet.chain];
    //                        transition.blockHeight = [tx[@"blockheight"] unsignedIntValue];
    //                        [blockchainIdentity.wallet.specialTransactionsHolder registerTransaction:transition];
    //                        [blockchainIdentity updateWithTransition:transition save:TRUE];
    //                        if (completion) {
    //                            completion(nil);
    //                        }
    //                    }
    //                    //dispatch_semaphore_signal(sem);
    //                } failure:^(NSError * _Nonnull error) {
    //                    if (completion) {
    //                        completion(error);
    //                    }
    //                    //dispatch_semaphore_signal(sem);
    //                }];
    //                //dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    //            }
    //        }
    //
    //    } failure:^(NSError * _Nonnull error) {
    //        if (completion) {
    //            completion(error);
    //        }
    //    }];
    //
}

//check ping times of all DAPI nodes
- (void)checkPingTimesForMasternodes:(NSArray<DSSimplifiedMasternodeEntry *> *)masternodes completion:(void (^)(NSMutableDictionary<NSData *, NSNumber *> *pingTimes, NSMutableDictionary<NSData *, NSError *> *))completion {
    dispatch_async(self.platformMetadataDispatchQueue, ^{
        HTTPLoaderFactory *loaderFactory = [DSNetworkingCoordinator sharedInstance].loaderFactory;
        __block dispatch_group_t dispatch_group = dispatch_group_create();
        __block NSMutableDictionary<NSData *, NSError *> *errorDictionary = [NSMutableDictionary dictionary];
        __block NSMutableDictionary<NSData *, NSNumber *> *pingTimeDictionary = [NSMutableDictionary dictionary];
        dispatch_semaphore_t dispatchSemaphore = dispatch_semaphore_create(32);

        for (DSSimplifiedMasternodeEntry *masternode in masternodes) {
            if (uint128_is_zero(masternode.address)) continue;
            if (!masternode.isValid) continue;
            dispatch_semaphore_wait(dispatchSemaphore, DISPATCH_TIME_FOREVER);
            dispatch_group_enter(dispatch_group);
            DSDAPICoreNetworkService *coreNetworkService = [[DSDAPICoreNetworkService alloc] initWithDAPINodeIPAddress:masternode.ipAddressString httpLoaderFactory:loaderFactory usingGRPCDispatchQueue:self.coreNetworkingDispatchQueue onChain:self.chain];
            __block NSDate *time = [NSDate date];
            [coreNetworkService
                getStatusWithCompletionQueue:self.platformMetadataDispatchQueue
                success:^(NSDictionary *_Nonnull status) {
                    NSTimeInterval platformPing = -[time timeIntervalSinceNow] * 1000;
                    pingTimeDictionary[uint256_data(masternode.providerRegistrationTransactionHash)] = @(platformPing);
                    [masternode setPlatformPing:platformPing at:[NSDate date]];
                    dispatch_semaphore_signal(dispatchSemaphore);
                    dispatch_group_leave(dispatch_group);
                }
                failure:^(NSError *_Nonnull error) {
                    errorDictionary[uint256_data(masternode.providerRegistrationTransactionHash)] = error;
                    dispatch_semaphore_signal(dispatchSemaphore);
                    dispatch_group_leave(dispatch_group);
                }];
        }

        dispatch_group_notify(dispatch_group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            if (completion) {
                completion(pingTimeDictionary, errorDictionary);
            }
        });
    });
}

#pragma mark - Peers

- (void)addDAPINodeByAddress:(NSString *)host {
#if DAPI_CONNECT_SINGLE_NODE
    return;
#endif
    [self.availablePeers addObject:host];
    DSDAPIPlatformNetworkService *foundNetworkService = nil;
    for (DSDAPIPlatformNetworkService *networkService in self.activePlatformServices) {
        if ([networkService.ipAddress isEqualToString:host]) {
            foundNetworkService = networkService;
            break;
        }
    }
    if (!foundNetworkService) {
        HTTPLoaderFactory *loaderFactory = [DSNetworkingCoordinator sharedInstance].loaderFactory;
        DSDAPIPlatformNetworkService *DAPINetworkService = [[DSDAPIPlatformNetworkService alloc] initWithDAPINodeIPAddress:host httpLoaderFactory:loaderFactory usingGRPCDispatchQueue:self.coreNetworkingDispatchQueue onChain:self.chain];
        [self.activePlatformServices addObject:DAPINetworkService];
    }
}

- (void)removeDAPINodeByAddress:(NSString *)host {
#if DAPI_CONNECT_SINGLE_NODE
    return;
#endif
    @synchronized(self) {
        [self.availablePeers removeObject:host];
        for (DSDAPIPlatformNetworkService *networkService in [self.activePlatformServices copy]) {
            if ([networkService.ipAddress isEqualToString:host]) {
                [self.activePlatformServices removeObject:networkService];
            }
        }
    }
}

- (DSDAPIPlatformNetworkService *)DAPIPlatformNetworkService {
    @synchronized(self) {
        if ([self.activePlatformServices count]) {
            if ([self.activePlatformServices count] == 1) return [self.activePlatformServices objectAtIndex:0];                   //if only 1 service, just use first one
            return [self.activePlatformServices objectAtIndex:arc4random_uniform((uint32_t)[self.activePlatformServices count])]; //use a random service
        } else if ([self.availablePeers count] || DAPI_CONNECT_SINGLE_NODE) {
#if DAPI_CONNECT_SINGLE_NODE
            NSString *peerHost = DAPI_SINGLE_NODE;
#else
            NSString *peerHost = self.availablePeers.anyObject;
#endif
            HTTPLoaderFactory *loaderFactory = [DSNetworkingCoordinator sharedInstance].loaderFactory;
            DSDAPIPlatformNetworkService *DAPINetworkService = [[DSDAPIPlatformNetworkService alloc] initWithDAPINodeIPAddress:peerHost httpLoaderFactory:loaderFactory usingGRPCDispatchQueue:self.coreNetworkingDispatchQueue onChain:self.chain];
            [self.activePlatformServices addObject:DAPINetworkService];
            return DAPINetworkService;
        }
        return nil;
    }
}

- (DSDAPICoreNetworkService *)DAPICoreNetworkService {
    @synchronized(self) {
        if ([self.activeCoreServices count]) {
            if ([self.activeCoreServices count] == 1) return [self.activeCoreServices objectAtIndex:0];                   //if only 1 service, just use first one
            return [self.activeCoreServices objectAtIndex:arc4random_uniform((uint32_t)[self.activeCoreServices count])]; //use a random service
        } else if ([self.availablePeers count]) {
#if DAPI_CONNECT_SINGLE_NODE
            NSString *peerHost = DAPI_SINGLE_NODE;
#else
            NSString *peerHost = [[self.availablePeers allObjects] objectAtIndex:arc4random_uniform((uint32_t)[self.availablePeers count])];
#endif
            HTTPLoaderFactory *loaderFactory = [DSNetworkingCoordinator sharedInstance].loaderFactory;
            DSDAPICoreNetworkService *DAPINetworkService = [[DSDAPICoreNetworkService alloc] initWithDAPINodeIPAddress:peerHost httpLoaderFactory:loaderFactory usingGRPCDispatchQueue:self.coreNetworkingDispatchQueue onChain:self.chain];
            [self.activeCoreServices addObject:DAPINetworkService];
            return DAPINetworkService;
        }
        return nil;
    }
}

- (void)publishTransition:(DSTransition *)stateTransition
                  success:(void (^)(NSDictionary *successDictionary, BOOL added))success
                  failure:(void (^)(NSError *error))failure {
    //default to 10 attempts
    [self publishTransition:stateTransition
            completionQueue:self.chain.chainManager.identitiesManager.identityQueue
                    success:success
                    failure:failure];
}

- (void)publishTransition:(DSTransition *)stateTransition
          completionQueue:(dispatch_queue_t)completionQueue
                  success:(void (^)(NSDictionary *successDictionary, BOOL added))success
                  failure:(void (^)(NSError *error))failure {
    //default to 10 attempts
    [self publishTransition:stateTransition
                 retryCount:DAPI_DEFAULT_PUBLISH_TRANSITION_RETRY_COUNT
                      delay:2
              delayIncrease:1
             currentAttempt:0
              currentErrors:@{}
            completionQueue:completionQueue
                    success:success
                    failure:^(NSDictionary<NSNumber *, NSError *> *_Nonnull errorPerAttempt) {
                        if (failure) {
                            failure(errorPerAttempt[@(4)]);
                        }
                    }];
}

- (void)publishTransition:(DSTransition *)transition
               retryCount:(uint32_t)retryCount
                    delay:(uint32_t)delay
            delayIncrease:(uint32_t)delayIncrease
           currentAttempt:(uint32_t)currentAttempt
            currentErrors:(NSDictionary<NSNumber *, NSError *> *)errorPerAttempt
          completionQueue:(dispatch_queue_t)completionQueue
                  success:(void (^)(NSDictionary *successDictionary, BOOL added))success
                  failure:(void (^)(NSDictionary<NSNumber *, NSError *> *errorPerAttempt))failure {
    DSDAPIPlatformNetworkService *service = self.DAPIPlatformNetworkService;
    if (!service) {
        NSMutableDictionary *mErrorsPerAttempt = [errorPerAttempt mutableCopy];
        NSError *error = [NSError errorWithDomain:DSDAPIClientErrorDomain
                                             code:DSDAPIClientErrorCodeNoKnownDAPINodes
                                         userInfo:@{NSLocalizedDescriptionKey: @"No known DAPI Nodes"}];
        mErrorsPerAttempt[@(currentAttempt)] = error;
        if (retryCount) {
            [self publishTransition:transition retryCount:retryCount - 1 delay:delay + delayIncrease delayIncrease:delayIncrease currentAttempt:currentAttempt + 1 currentErrors:mErrorsPerAttempt completionQueue:completionQueue success:success failure:failure];
        } else if (failure) {
            failure([mErrorsPerAttempt copy]);
        }
        return;
    }

    [service publishTransition:transition
               completionQueue:completionQueue
                       success:success
                       failure:^(NSError *_Nonnull error) {
                           if (error.code == 12) { //UNIMPLEMENTED, this would mean that we are connecting to an old node
                               [self removeDAPINodeByAddress:service.ipAddress];
                           }
                           NSMutableDictionary *mErrorsPerAttempt = [errorPerAttempt mutableCopy];
                           if (error) {
                               mErrorsPerAttempt[@(currentAttempt)] = error;
                           }
                           if (retryCount) {
                               dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), self.coreNetworkingDispatchQueue, ^{
                                   [self publishTransition:transition retryCount:retryCount - 1 delay:delay + delayIncrease delayIncrease:delayIncrease currentAttempt:currentAttempt + 1 currentErrors:mErrorsPerAttempt completionQueue:completionQueue success:success failure:failure];
                               });
                           } else if (failure) {
                               failure([mErrorsPerAttempt copy]);
                           }
                       }];
}


@end
