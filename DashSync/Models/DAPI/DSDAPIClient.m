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

#import "DashPlatformProtocol+DashSync.h"
#import <arpa/inet.h>

NS_ASSUME_NONNULL_BEGIN

NSErrorDomain const DSDAPIClientErrorDomain = @"DSDAPIClientErrorDomain";

@interface DSDAPIClient()

@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) NSMutableArray<NSString *>* availablePeers;
@property (nonatomic, strong) NSMutableArray<DSDAPINetworkService *>* activeServices;

@end

@implementation DSDAPIClient

- (instancetype)initWithChain:(DSChain *)chain {
    self = [super init];
    if (self) {
        _chain = chain;
        self.availablePeers = [NSMutableArray array];
        self.activeServices = [NSMutableArray array];

    }
    return self;
}

- (void)sendDocument:(DPDocument *)document
             forUser:(DSBlockchainIdentity*)blockchainIdentity
            contract:(DPContract *)contract
          completion:(void (^)(NSError *_Nullable error))completion {
    NSParameterAssert(document);
    NSParameterAssert(contract);
    
    NSArray *documents = @[ document ];
    
    DashPlatformProtocol *dpp = [DashPlatformProtocol sharedInstance];
    DPSTPacket *stPacket = [dpp.stPacketFactory packetWithContractId:contract.identifier documents:documents];
    [self sendPacket:stPacket forUser:blockchainIdentity completion:completion];
}

- (void)sendPacket:(DPSTPacket *)stPacket
           forUser:(DSBlockchainIdentity*)blockchainIdentity
        completion:(void (^)(NSError *_Nullable error))completion {
    NSParameterAssert(stPacket);
    NSParameterAssert(completion);
    
    NSData *serializedSTPacketObject = [stPacket serialized];
    
    // ios-dpp (DAPI) uses direct byte order, but DSTransition needs reversed
    NSData *serializedSTPacketObjectHash = [[stPacket serializedHash] reverse];
    
    DSTransition *transition = [blockchainIdentity transitionForStateTransitionPacketHash:serializedSTPacketObjectHash.UInt256];
    DSDLog(@"registrationHash %@ previousTransitionHash %@",uint256_hex(transition.registrationTransactionHash) ,uint256_hex(transition.previousTransitionHash));
    __weak typeof(self) weakSelf = self;
    [blockchainIdentity signStateTransition:transition
                                  withPrompt:@""
                                  completion:^(BOOL success) {
                                      __strong typeof(weakSelf) strongSelf = weakSelf;
                                      if (!strongSelf) {
                                          return;
                                      }
                                      
                                      if (success) {
                                          [strongSelf sendTransition:transition
                                            serializedSTPacketObject:serializedSTPacketObject
                                                          completion:completion];
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
    DSDAPINetworkService * service = self.DAPINetworkService;
    if (!service) {
        completion([NSError errorWithDomain:DSDAPIClientErrorDomain
                                       code:DSDAPIClientErrorCodeNoKnownDAPINodes
                                   userInfo:@{NSLocalizedDescriptionKey:@"No known DAPI Nodes"}]);
        return;
    }
    [service getUserById:uint256_reverse_hex(blockchainIdentity.registrationTransitionHash) success:^(NSDictionary * _Nonnull blockchainIdentityDictionary) {
        if ([blockchainIdentityDictionary objectForKey:@"subtx"] && [[blockchainIdentityDictionary objectForKey:@"subtx"] isKindOfClass:[NSArray class]]) {
            NSArray * subscriptionTransactions = [blockchainIdentityDictionary objectForKey:@"subtx"];
            NSMutableArray * oldSubscriptionTransactionHashes = [NSMutableArray array];
            for (DSTransaction * transaction in blockchainIdentity.allTransitions) {
                [oldSubscriptionTransactionHashes addObject:[NSData dataWithUInt256:transaction.txHash]];
            }
            NSMutableArray * novelSubscriptionTransactionHashes = [NSMutableArray array];
            for (NSString * possiblyNewSubscriptionTransactionHashString in subscriptionTransactions) {
                NSData * data = possiblyNewSubscriptionTransactionHashString.hexToData;
                if (![oldSubscriptionTransactionHashes containsObject:data]) {
                    [novelSubscriptionTransactionHashes addObject:data];
                }
            }
            for (NSData * unknownSubscriptionTransactionHash in novelSubscriptionTransactionHashes) {
                //dispatch_semaphore_t sem = dispatch_semaphore_create(0);
                [service getTransactionById:unknownSubscriptionTransactionHash.hexString success:^(NSDictionary * _Nonnull tx) {
                    if (tx[@"version"] && tx[@"blockheight"] && tx[@"extraPayload"] && tx[@"valueIn"] && tx[@"valueOut"] && ([tx[@"valueIn"] integerValue] + [tx[@"valueOut"] integerValue] == 0)) {
                        DSDLog(@"state transition %@",tx);
                        //this is a transition
                        NSString * extraPayload = tx[@"extraPayload"];
                        uint16_t version = [tx[@"version"] shortValue];
                        DSTransition * transition = [[DSTransition alloc] initWithVersion:version payloadData:extraPayload.hexToData onChain:blockchainIdentity.wallet.chain];
                        transition.blockHeight = [tx[@"blockheight"] unsignedIntValue];
                        [blockchainIdentity.wallet.specialTransactionsHolder registerTransaction:transition];
                        [blockchainIdentity updateWithTransition:transition save:TRUE];
                        if (completion) {
                            completion(nil);
                        }
                    }
                    //dispatch_semaphore_signal(sem);
                } failure:^(NSError * _Nonnull error) {
                    if (completion) {
                        completion(error);
                    }
                    //dispatch_semaphore_signal(sem);
                }];
                //dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
            }
        }
        
    } failure:^(NSError * _Nonnull error) {
        if (completion) {
            completion(error);
        }
    }];
    
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
            NSURL *dapiNodeURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:3000",peerHost]];
            HTTPLoaderFactory *loaderFactory = [DSNetworkingCoordinator sharedInstance].loaderFactory;
            DSDAPINetworkService * DAPINetworkService = [[DSDAPINetworkService alloc] initWithDAPINodeURL:dapiNodeURL httpLoaderFactory:loaderFactory];
            [self.activeServices addObject:DAPINetworkService];
            return DAPINetworkService;
        }
        return nil;
    }
}

#pragma mark - Private

- (void)sendTransition:(DSTransition *)transition
serializedSTPacketObject:(NSData *)serializedSTPacketObject
            completion:(void (^)(NSError *_Nullable error))completion {
    DSDAPINetworkService * service = self.DAPINetworkService;
    if (!service) {
        completion([NSError errorWithDomain:DSDAPIClientErrorDomain
                                       code:DSDAPIClientErrorCodeNoKnownDAPINodes
                                   userInfo:@{NSLocalizedDescriptionKey:@"No known DAPI Nodes"}]);
        return;
    }
    NSData *transitionData = [transition toData];
    
    NSString *transitionDataHex = [transitionData hexString];
    NSString *serializedSTPacketObjectHex = [serializedSTPacketObject hexString];
    
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService sendRawTransitionWithRawStateTransition:transitionDataHex
                                                              rawSTPacket:serializedSTPacketObjectHex
                                                                  success:^(NSString *_Nonnull headerId) {
                                                                      __strong typeof(weakSelf) strongSelf = weakSelf;
                                                                      if (!strongSelf) {
                                                                          return;
                                                                      }
                                                                      
                                                                      NSLog(@"Header ID %@", headerId);
                                                                      
                                                                      [strongSelf.chain registerSpecialTransaction:transition];
                                                                      [transition save];
                                                                      
                                                                      if (completion) {
                                                                          completion(nil);
                                                                      }
                                                                  }
                                                                  failure:^(NSError *_Nonnull error) {
                                                                      NSLog(@"Error: %@", error);
                                                                      if (completion) {
                                                                          completion(error);
                                                                      }
                                                                  }];
}


@end

NS_ASSUME_NONNULL_END
