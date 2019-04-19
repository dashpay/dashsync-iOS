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
             forUser:(DSBlockchainUser*)blockchainUser
            contract:(DPContract *)contract
          completion:(void (^)(NSError *_Nullable error))completion {
    NSParameterAssert(document);
    NSParameterAssert(contract);
    
    NSArray *documents = @[ document ];
    
    DashPlatformProtocol *dpp = [DashPlatformProtocol sharedInstance];
    DPSTPacket *stPacket = [dpp.stPacketFactory packetWithContractId:contract.identifier documents:documents];
    [self sendPacket:stPacket forUser:blockchainUser completion:completion];
}

- (void)sendPacket:(DPSTPacket *)stPacket
           forUser:(DSBlockchainUser*)blockchainUser
        completion:(void (^)(NSError *_Nullable error))completion {
    NSParameterAssert(stPacket);
    NSParameterAssert(completion);
    
    NSData *serializedSTPacketObject = [stPacket serialized];
    
    // ios-dpp (DAPI) uses direct byte order, but DSTransition needs reversed
    NSData *serializedSTPacketObjectHash = [[stPacket serializedHash] reverse];
    
    DSTransition *transition = [blockchainUser transitionForStateTransitionPacketHash:serializedSTPacketObjectHash.UInt256];
    
    __weak typeof(self) weakSelf = self;
    [blockchainUser signStateTransition:transition
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
