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
#import "DSChain+Protected.h"
#import "DSWallet.h"
#import "DSChainManager.h"
#import "DSBlockchainIdentity+Protected.h"
#import "NSString+Dash.h"
#import "DSDAPIClient.h"
#import "DSDAPINetworkService.h"
#import "DSOptionsManager.h"
#import "DSCreditFundingTransaction.h"
#import "DSMerkleBlock.h"
#import "DSPeerManager.h"

@interface DSIdentitiesManager()

@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) NSMutableDictionary * foreignBlockchainIdentities;

@end

@implementation DSIdentitiesManager

- (instancetype)initWithChain:(DSChain*)chain
{
    NSParameterAssert(chain);
    
    if (! (self = [super init])) return nil;
    
    self.chain = chain;
    self.foreignBlockchainIdentities = [NSMutableDictionary dictionary];
    
    return self;
}

// MARK: - Identities

- (DSBlockchainIdentity*)foreignBlockchainIdentityWithUniqueId:(UInt256)uniqueId {
    //foreign blockchain identities are for local blockchain identies' contacts, not for search.
    @synchronized (self.foreignBlockchainIdentities) {
        if (self.foreignBlockchainIdentities[uint256_data(uniqueId)]) {
            return self.foreignBlockchainIdentities[uint256_data(uniqueId)];
        } else {
            DSBlockchainIdentity * foreignBlockchainIdentity = [[DSBlockchainIdentity alloc] initWithUniqueId:uniqueId onChain:self.chain inContext:self.chain.chainManagedObjectContext];
            [foreignBlockchainIdentity saveInitial];
            self.foreignBlockchainIdentities[uint256_data(uniqueId)] = foreignBlockchainIdentity;
        }
        return self.foreignBlockchainIdentities[uint256_data(uniqueId)];
    }
}

- (NSArray*)unsyncedBlockchainIdentities {
    NSMutableArray * unsyncedBlockchainIdentities = [NSMutableArray array];
    for (DSBlockchainIdentity * blockchainIdentity in [self.chain localBlockchainIdentities]) {
        if (!blockchainIdentity.registrationCreditFundingTransaction || (blockchainIdentity.registrationCreditFundingTransaction.blockHeight == BLOCK_UNKNOWN_HEIGHT)) {
            [unsyncedBlockchainIdentities addObject:blockchainIdentity];
        } else if (self.chain.lastSyncBlockHeight > blockchainIdentity.dashpaySyncronizationBlockHeight) {
            //If they are equal then the blockchain identity is synced
            //This is because the dashpaySyncronizationBlock represents the last block for the bloom filter used in L1 should be considered valid
            //That's because it is set at the time with the hash of the last
            [unsyncedBlockchainIdentities addObject:blockchainIdentity];
        }
    }
    return unsyncedBlockchainIdentities;
}

-(void)syncBlockchainIdentitiesWithCompletion:(IdentitiesCompletionBlock)completion {
    dispatch_group_t dispatchGroup = dispatch_group_create();
    __block BOOL groupedSuccess = YES;
    __block NSMutableArray * groupedErrors = [NSMutableArray array];
    NSArray <DSBlockchainIdentity *> * blockchainIdentities =  [self unsyncedBlockchainIdentities];
    for (DSBlockchainIdentity * blockchainIdentity in blockchainIdentities) {
        dispatch_group_enter(dispatchGroup);
        [blockchainIdentity fetchAllNetworkStateInformationWithCompletion:^(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * _Nullable errors) {
            groupedSuccess &= !failureStep;
            [groupedErrors addObjectsFromArray:errors];
            dispatch_group_leave(dispatchGroup);
        }];
    }
    

    if (completion) {
        dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
            completion(groupedSuccess,blockchainIdentities,[groupedErrors copy]);
        });
    }
}

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

- (id<DSDAPINetworkServiceRequest>)searchIdentitiesByNamePrefix:(NSString*)namePrefix withCompletion:(IdentitiesCompletionBlock)completion {
    return [self searchIdentitiesByNamePrefix:namePrefix offset:0 limit:100 withCompletion:completion];
}

- (id<DSDAPINetworkServiceRequest>)searchIdentityByName:(NSString*)name withCompletion:(IdentityCompletionBlock)completion {
    DSDAPIClient * client = self.chain.chainManager.DAPIClient;
    id<DSDAPINetworkServiceRequest> call = [client.DAPINetworkService getDPNSDocumentsForUsernames:@[name] inDomain:@"" success:^(NSArray<NSDictionary *> * _Nonnull documents) {
        __block NSMutableArray * rBlockchainIdentities = [NSMutableArray array];
        for (NSDictionary * document in documents) {
            NSString * userId = document[@"$userId"];
            NSString * normalizedLabel = document[@"normalizedLabel"];
            DSBlockchainIdentity * identity = [[DSBlockchainIdentity alloc] initWithUniqueId:userId.base58ToData.UInt256 onChain:self.chain inContext:self.chain.chainManagedObjectContext];
            [identity addUsername:normalizedLabel status:DSBlockchainIdentityUsernameStatus_Confirmed save:NO registerOnNetwork:NO];
            [rBlockchainIdentities addObject:identity];
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(YES,[rBlockchainIdentities firstObject],nil);
            });
        }
    } failure:^(NSError * _Nonnull error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO,nil,error);
            });
        }
        DSDLog(@"Failure in searchIdentityByName %@",error);
    }];
    return call;
}

- (id<DSDAPINetworkServiceRequest>)searchIdentitiesByNamePrefix:(NSString*)namePrefix offset:(uint32_t)offset limit:(uint32_t)limit withCompletion:(IdentitiesCompletionBlock)completion {
    DSDAPIClient * client = self.chain.chainManager.DAPIClient;
    id<DSDAPINetworkServiceRequest> call = [client.DAPINetworkService searchDPNSDocumentsForUsernamePrefix:namePrefix inDomain:@"dash" offset:offset limit:limit success:^(NSArray<NSDictionary *> * _Nonnull documents) {
        __block NSMutableArray * rBlockchainIdentities = [NSMutableArray array];
        for (NSDictionary * document in documents) {
            NSString * userId = document[@"$ownerId"];
            NSString * normalizedLabel = document[@"normalizedLabel"];
            DSBlockchainIdentity * identity = [[DSBlockchainIdentity alloc] initWithUniqueId:userId.base58ToData.UInt256 onChain:self.chain inContext:self.chain.chainManagedObjectContext];
            [identity addUsername:normalizedLabel status:DSBlockchainIdentityUsernameStatus_Confirmed save:NO registerOnNetwork:NO];
            [rBlockchainIdentities addObject:identity];
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(YES,[rBlockchainIdentities copy],@[]);
            });
        }
    } failure:^(NSError * _Nonnull error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil, @[error]);
            });
        }
        DSDLog(@"Failure in searchIdentitiesByNamePrefix %@",error);
    }];
    return call;
}

- (void)searchIdentitiesByDPNSRegisteredBlockchainIdentityUniqueID:(NSString*)userID withCompletion:(IdentitiesCompletionBlock)completion {
    DSDAPIClient * client = self.chain.chainManager.DAPIClient;
    [client.DAPINetworkService getDPNSDocumentsForIdentityWithUserId:userID success:^(NSArray<NSDictionary *> * _Nonnull documents) {
        __block NSMutableArray * rBlockchainIdentities = [NSMutableArray array];
        for (NSDictionary * document in documents) {
            NSString * userId = document[@"$ownerId"];
            NSString * normalizedLabel = document[@"normalizedLabel"];
            DSBlockchainIdentity * identity = [[DSBlockchainIdentity alloc] initWithUniqueId:userId.base58ToData.UInt256 onChain:self.chain inContext:self.chain.chainManagedObjectContext];
            [identity addUsername:normalizedLabel status:DSBlockchainIdentityUsernameStatus_Confirmed save:NO registerOnNetwork:NO];
            [identity fetchIdentityNetworkStateInformationWithCompletion:^(BOOL success, NSError * error) {
                
            }];
            [rBlockchainIdentities addObject:identity];
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(YES,[rBlockchainIdentities copy],@[]);
            });
        }
    } failure:^(NSError * _Nonnull error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil, @[error]);
            });
        }
        DSDLog(@"Failure in searchIdentitiesByDPNSRegisteredBlockchainIdentityUniqueID %@",error);
    }];
}

- (void)checkCreditFundingTransactionForPossibleNewIdentity:(DSCreditFundingTransaction*)creditFundingTransaction {
    uint32_t index;
    DSWallet * wallet = [self.chain walletHavingBlockchainIdentityCreditFundingRegistrationHash:creditFundingTransaction.creditBurnPublicKeyHash foundAtIndex:&index];
    
    if (!wallet) return; //it's a topup or we are funding an external identity
    
    DSBlockchainIdentity * blockchainIdentity = [wallet blockchainIdentityForUniqueId:creditFundingTransaction.creditBurnIdentityIdentifier];
    
    NSAssert(blockchainIdentity, @"We should have already created the blockchain identity at this point in the transaction manager by calling triggerUpdatesForLocalReferences");
    
    
    //DSDLog(@"Paused Sync at block %d to gather identity information on %@",block.height,blockchainIdentity.uniqueIdString);
    [self fetchNeededNetworkStateInformationForBlockchainIdentity:blockchainIdentity];
}

-(void)fetchNeededNetworkStateInformationForBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity {
    [blockchainIdentity fetchNeededNetworkStateInformationWithCompletion:^(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * _Nullable errors) {
        if (!failureStep) {
            [self chain:self.chain didFinishFetchingBlockchainIdentityDAPInformation:blockchainIdentity];
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self fetchNeededNetworkStateInformationForBlockchainIdentity:blockchainIdentity];
            });
        }
    }];
}

// MARK: - DSChainIdentitiesDelegate

-(void)chain:(DSChain*)chain didFinishFetchingBlockchainIdentityDAPInformation:(DSBlockchainIdentity*)blockchainIdentity {
    [self.chain.chainManager chain:chain didFinishFetchingBlockchainIdentityDAPInformation:blockchainIdentity];
}

@end
