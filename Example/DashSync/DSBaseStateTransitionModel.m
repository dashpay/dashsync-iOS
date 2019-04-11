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

#import "DSBaseStateTransitionModel.h"

#import <DashSync/DSTransition.h>
#import <DashSync/DashSync.h>

#import "DashPlatformProtocol+DashSync.h"

NS_ASSUME_NONNULL_BEGIN

NSErrorDomain const DSStateTransitionModelErrorDomain = @"DSStateTransitionModelErrorDomain";

@implementation DSBaseStateTransitionModel

- (instancetype)initWithChainManager:(DSChainManager *)chainManager
                      blockchainUser:(DSBlockchainUser *)blockchainUser {
    self = [super init];
    if (self) {
        _chainManager = chainManager;
        _blockchainUser = blockchainUser;
    }
    return self;
}

- (void)sendDocument:(DPDocument *)document
          contractId:(NSString *)contractId
          completion:(void (^)(NSError *_Nullable error))completion {
    NSParameterAssert(document);
    NSParameterAssert(contractId);

    NSArray *documents = @[ document ];

    DashPlatformProtocol *dpp = [DashPlatformProtocol sharedInstance];
    DPSTPacket *stPacket = [dpp.stPacketFactory packetWithContractId:contractId documents:documents];
    [self sendPacket:stPacket completion:completion];
}

- (void)sendPacket:(DPSTPacket *)stPacket
        completion:(void (^)(NSError *_Nullable error))completion {
    NSParameterAssert(stPacket);
    NSParameterAssert(completion);

    NSData *serializedSTPacketObject = [stPacket serialized];

    // ios-dpp (DAPI) uses direct byte order, but DSTransition needs reversed
    NSData *serializedSTPacketObjectHash = [[stPacket serializedHash] reverse];

    DSTransition *transition = [self.blockchainUser transitionForStateTransitionPacketHash:serializedSTPacketObjectHash.UInt256];

    __weak typeof(self) weakSelf = self;
    [self.blockchainUser signStateTransition:transition
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
                                              NSError *error = [NSError errorWithDomain:DSStateTransitionModelErrorDomain
                                                                                   code:DSStateTransitionModelErrorCodeSignTransitionFailed
                                                                               userInfo:nil];
                                              completion(error);
                                          }
                                      }
                                  }];
}

#pragma mark - Private

- (void)sendTransition:(DSTransition *)transition
        serializedSTPacketObject:(NSData *)serializedSTPacketObject
                      completion:(void (^)(NSError *_Nullable error))completion {
    NSData *transitionData = [transition toData];

    NSString *transitionDataHex = [transitionData hexString];
    NSString *serializedSTPacketObjectHex = [serializedSTPacketObject hexString];

    __weak typeof(self) weakSelf = self;
    [self.chainManager.DAPIClient sendRawTransitionWithRawStateTransition:transitionDataHex
        rawSTPacket:serializedSTPacketObjectHex
        success:^(NSString *_Nonnull headerId) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            NSLog(@"Header ID %@", headerId);

            [strongSelf.chainManager.chain registerSpecialTransaction:transition];
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
