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

#import <DashSync/DSTransition.h>
#import <DashSync/DashSync.h>
#import "DSDAPINetworkService.h"

#import "DSDashPlatform.h"
#import "DSDocumentTransition.h"
#import <arpa/inet.h>

NS_ASSUME_NONNULL_BEGIN

NSErrorDomain const DSDAPIClientErrorDomain = @"DSDAPIClientErrorDomain";

@interface DSDAPIClient()

@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) NSMutableArray<NSString *>* availablePeers;
@property (nonatomic, strong) NSMutableArray<DSDAPINetworkService *>* activeServices;
@property (atomic, strong) dispatch_queue_t dispatchQueue;

@end

@implementation DSDAPIClient

- (instancetype)initWithChain:(DSChain *)chain {
    self = [super init];
    if (self) {
        _chain = chain;
        self.availablePeers = [NSMutableArray array];
        self.activeServices = [NSMutableArray array];
                self.dispatchQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.dapigrpc.%@",self.chain.uniqueID] UTF8String], DISPATCH_QUEUE_SERIAL);

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
             forIdentity:(DSBlockchainIdentity*)blockchainIdentity
            contract:(DPContract *)contract
          completion:(void (^)(NSError *_Nullable error))completion {
    NSParameterAssert(document);
    NSParameterAssert(contract);

    NSArray *documents = @[ document ];

    DSDashPlatform *platform = [DSDashPlatform sharedInstanceForChain:self.chain];
    
    DSDocumentTransition * documentTransition = [[DSDocumentTransition alloc] initWithTransitionVersion:<#(uint16_t)#> blockchainIdentityUniqueId:<#(UInt256)#> onChain:<#(DSChain * _Nonnull)#>]
    
    DSDLog(@"identity %@",uint256_hex(documentTransition.blockchainIdentityUniqueId));
    __weak typeof(self) weakSelf = self;
    [blockchainIdentity signStateTransition:documentTransition
                                  withPrompt:@""
                                  completion:^(BOOL success) {
                                      __strong typeof(weakSelf) strongSelf = weakSelf;
                                      if (!strongSelf) {
                                          return;
                                      }
                                      
                                      if (success) {
                                          [strongSelf publishTransition:documentTransition success:^(NSDictionary * _Nonnull successDictionary) {
                                              
                                          } failure:^(NSError * _Nonnull error) {
                                              
                                          }];
                                      }
                                      else {
                                          if (completion) {
                                              NSError *error = [NSError errorWithDomain:DSDAPIClientErrorDomain
                                                                                   code:DSDAPIClientErrorCodeSignTransitionFailed
                                                                               userInfo:nil];
                                              completion(error);
                                          }
                                      }
                                  }];
}

-(void)getAllStateTransitionsForUser:(DSBlockchainIdentity*)blockchainIdentity completion:(void (^)(NSError *_Nullable error))completion {
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
//                        DSDLog(@"state transition %@",tx);
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

#pragma mark - Peers

- (void)addDAPINodeByAddress:(NSString*)host {
    [self.availablePeers addObject:host];
}

-(DSDAPINetworkService*)DAPINetworkService {
    @synchronized (self) {
        if ([self.activeServices count]) {
            if ([self.activeServices count] == 1) return [self.activeServices objectAtIndex:0]; //iif only 1 service, just use first one
            return [self.activeServices objectAtIndex:arc4random_uniform((uint32_t)[self.activeServices count])]; //use a random service
        } else if ([self.availablePeers count]) {
            NSString * peerHost = [self.availablePeers objectAtIndex:0];
            HTTPLoaderFactory *loaderFactory = [DSNetworkingCoordinator sharedInstance].loaderFactory;
            DSDAPINetworkService * DAPINetworkService = [[DSDAPINetworkService alloc] initWithDAPINodeIPAddress:peerHost httpLoaderFactory:loaderFactory usingGRPCDispatchQueue:self.dispatchQueue onChain:self.chain];
            [self.activeServices addObject:DAPINetworkService];
            return DAPINetworkService;
        }
        return nil;
    }
}

- (void)publishTransition:(DSTransition *)transition
            success:(void (^)(NSDictionary *successDictionary))success
            failure:(void (^)(NSError *error))failure {
    DSDAPINetworkService * service = self.DAPINetworkService;
    if (!service) {
        failure([NSError errorWithDomain:DSDAPIClientErrorDomain
                                       code:DSDAPIClientErrorCodeNoKnownDAPINodes
                                   userInfo:@{NSLocalizedDescriptionKey:@"No known DAPI Nodes"}]);
        return;
    }
    
    [self.DAPINetworkService publishTransition:transition
                                       success:success failure:failure];
}


@end

NS_ASSUME_NONNULL_END
