//  
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

#import "DSIdentitiesManager.h"
#import "DSChain.h"
#import "DSWallet.h"
#import "DSChainManager.h"
#import "DSBlockchainIdentity+Protected.h"
#import "NSString+Dash.h"
#import "DSDAPIClient.h"
#import "DSDAPINetworkService.h"
#import "DSOptionsManager.h"

@interface DSIdentitiesManager()

@property (nonatomic, strong) DSChain * chain;

@end

@implementation DSIdentitiesManager

- (instancetype)initWithChain:(DSChain*)chain
{
    NSParameterAssert(chain);
    
    if (! (self = [super init])) return nil;
    
    self.chain = chain;
    
    return self;
}

// MARK: - Identities

-(void)retrieveAllBlockchainIdentitiesChainStates {
    for (DSWallet * wallet in self.chain.wallets) {
        [self retrieveAllBlockchainIdentitiesChainStatesForWallet:wallet];
    }
}

-(void)retrieveAllBlockchainIdentitiesChainStatesForWallet:(DSWallet*)wallet {
    for (DSBlockchainIdentity * identity in [wallet.blockchainIdentities allValues]) {
        if (identity.registrationStatus == DSBlockchainIdentityRegistrationStatus_Unknown) {
            [identity fetchIdentityNetworkStateInformationWithCompletion:^(BOOL success, NSError * error) {
                if (success) {
                    //now lets get dpns info
                    if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_DPNS)) {
                        [identity fetchUsernamesWithCompletion:^(BOOL success, NSError * error) {
                            
                        }];
                    }
                }
            }];
        } else if (identity.registrationStatus == DSBlockchainIdentityRegistrationStatus_Registered) {
            if (!identity.currentUsername) {
                if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_DPNS)) {
                    [identity fetchUsernamesWithCompletion:^(BOOL success, NSError * error) {
                        
                    }];
                }
            }
        }
    }
}

- (void)searchIdentitiesByNamePrefix:(NSString*)namePrefix withCompletion:(IdentitiesCompletionBlock)completion {
    DSDAPIClient * client = self.chain.chainManager.DAPIClient;
     [client.DAPINetworkService searchDPNSDocumentsForUsernamePrefix:namePrefix inDomain:@"" offset:0 limit:100 success:^(NSArray<NSDictionary *> * _Nonnull documents) {
         __block NSMutableArray * rBlockchainIdentities = [NSMutableArray array];
         for (NSDictionary * document in documents) {
             NSString * userId = document[@"$userId"];
             NSString * normalizedLabel = document[@"normalizedLabel"];
             DSBlockchainIdentity * identity = [[DSBlockchainIdentity alloc] initWithUniqueId:userId.base58ToData.UInt256 onChain:self.chain inContext:self.chain.managedObjectContext];
             [identity addUsername:normalizedLabel status:DSBlockchainIdentityUsernameStatus_Confirmed save:NO];
             [rBlockchainIdentities addObject:identity];
         }
         if (completion) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 completion([rBlockchainIdentities copy],nil);
             });
         }
     } failure:^(NSError * _Nonnull error) {
         if (completion) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 completion(nil,error);
             });
         }
         NSLog(@"Failure %@",error);
     }];
 }

- (void)searchIdentitiesByDPNSRegisteredBlockchainIdentityUniqueID:(NSString*)userID withCompletion:(IdentitiesCompletionBlock)completion {
   DSDAPIClient * client = self.chain.chainManager.DAPIClient;
    [client.DAPINetworkService getDPNSDocumentsForIdentityWithUserId:userID success:^(NSArray<NSDictionary *> * _Nonnull documents) {
        __block NSMutableArray * rBlockchainIdentities = [NSMutableArray array];
        for (NSDictionary * document in documents) {
            NSString * userId = document[@"$userId"];
            NSString * normalizedLabel = document[@"normalizedLabel"];
            DSBlockchainIdentity * identity = [[DSBlockchainIdentity alloc] initWithUniqueId:userId.base58ToData.UInt256 onChain:self.chain inContext:self.chain.managedObjectContext];
            [identity addUsername:normalizedLabel status:DSBlockchainIdentityUsernameStatus_Confirmed save:NO];
            [identity fetchIdentityNetworkStateInformationWithCompletion:^(BOOL success, NSError * error) {
                
            }];
            [rBlockchainIdentities addObject:identity];
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([rBlockchainIdentities copy],nil);
            });
        }
    } failure:^(NSError * _Nonnull error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil,error);
            });
        }
        NSLog(@"Failure %@",error);
    }];
}

@end
