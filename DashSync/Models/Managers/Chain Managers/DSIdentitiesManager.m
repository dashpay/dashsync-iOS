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
#import "NSManagedObjectContext+DSSugar.h"
#import "NSManagedObject+Sugar.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"

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
    [self loadExternalBlockchainIdentities];
    
    return self;
}

// MARK: - Loading

-(void)loadExternalBlockchainIdentities {
    NSManagedObjectContext * context = [NSManagedObjectContext chainContext]; //shouldn't matter what context is used
    
    [context performBlockAndWait:^{
        NSArray <DSBlockchainIdentityEntity*>* externalIdentityEntities = [DSBlockchainIdentityEntity objectsInContext:context matching:@"chain == %@ && isLocal == FALSE",[self.chain chainEntityInContext:context]];
        for (DSBlockchainIdentityEntity * entity in externalIdentityEntities) {
            DSBlockchainIdentity * identity = [[DSBlockchainIdentity alloc] initWithBlockchainIdentityEntity:entity];
            if (identity) {
                self.foreignBlockchainIdentities[uint256_data(identity.uniqueID)] = identity;
            }
        }
    }];
}

// MARK: - Wiping

-(void)clearExternalBlockchainIdentities {
    self.foreignBlockchainIdentities = [NSMutableDictionary dictionary];
}

// MARK: - Identities

-(void)registerForeignBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity {
    NSAssert(!blockchainIdentity.isTransient, @"Blockchain Identity should no longer be transient");
    @synchronized (self.foreignBlockchainIdentities) {
        if (!self.foreignBlockchainIdentities[uint256_data(blockchainIdentity.uniqueID)]) {
            [blockchainIdentity saveInitial];
            self.foreignBlockchainIdentities[uint256_data(blockchainIdentity.uniqueID)] = blockchainIdentity;
        }
    }
}

- (DSBlockchainIdentity*)foreignBlockchainIdentityWithUniqueId:(UInt256)uniqueId {
    return [self foreignBlockchainIdentityWithUniqueId:uniqueId createIfMissing:NO inContext:nil];
}

- (DSBlockchainIdentity*)foreignBlockchainIdentityWithUniqueId:(UInt256)uniqueId createIfMissing:(BOOL)addIfMissing inContext:(NSManagedObjectContext*)context {
    //foreign blockchain identities are for local blockchain identies' contacts, not for search.
    @synchronized (self.foreignBlockchainIdentities) {
        DSBlockchainIdentity * foreignBlockchainIdentity = self.foreignBlockchainIdentities[uint256_data(uniqueId)];
        if (foreignBlockchainIdentity) {
            NSAssert(context?[foreignBlockchainIdentity blockchainIdentityEntityInContext:context]: foreignBlockchainIdentity.blockchainIdentityEntity,@"Blockchain identity entity should exist");
            return foreignBlockchainIdentity;
        } else if (addIfMissing) {
            foreignBlockchainIdentity = [[DSBlockchainIdentity alloc] initWithUniqueId:uniqueId isTransient:FALSE onChain:self.chain];
            [foreignBlockchainIdentity saveInitialInContext:context];
            self.foreignBlockchainIdentities[uint256_data(uniqueId)] = foreignBlockchainIdentity;
            return self.foreignBlockchainIdentities[uint256_data(uniqueId)];
        }
        return nil;
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
            if (!identity.currentDashpayUsername) {
                if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_DPNS)) {
                    [identity fetchUsernamesWithCompletion:^(BOOL success, NSError * error) {
                        
                    }];
                }
            }
        }
    }
}

- (id<DSDAPINetworkServiceRequest>)searchIdentitiesByDashpayUsernamePrefix:(NSString*)namePrefix withCompletion:(IdentitiesCompletionBlock)completion {
    return [self searchIdentitiesByNamePrefix:namePrefix inDomain:@"dash" offset:0 limit:100 withCompletion:completion];
}

- (id<DSDAPINetworkServiceRequest>)searchIdentityByDashpayUsername:(NSString*)name withCompletion:(IdentityCompletionBlock)completion {
    return [self searchIdentityByName:name inDomain:@"dash" withCompletion:completion];
}

- (id<DSDAPINetworkServiceRequest>)searchIdentityByName:(NSString*)name inDomain:(NSString*)domain withCompletion:(IdentityCompletionBlock)completion {
    DSDAPIClient * client = self.chain.chainManager.DAPIClient;
    id<DSDAPINetworkServiceRequest> call = [client.DAPINetworkService getDPNSDocumentsForUsernames:@[name] inDomain:domain success:^(NSArray<NSDictionary *> * _Nonnull documents) {
        __block NSMutableArray * rBlockchainIdentities = [NSMutableArray array];
        for (NSDictionary * document in documents) {
            NSString * userId = document[@"$userId"];
            NSString * normalizedLabel = document[@"normalizedLabel"];
            NSString * domain = document[@"normalizedParentDomainName"];
            DSBlockchainIdentity * identity = [[DSBlockchainIdentity alloc] initWithUniqueId:userId.base58ToData.UInt256 isTransient:TRUE onChain:self.chain];
            [identity addUsername:normalizedLabel inDomain:domain status:DSBlockchainIdentityUsernameStatus_Confirmed save:NO registerOnNetwork:NO];
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

- (id<DSDAPINetworkServiceRequest>)searchIdentitiesByDashpayUsernamePrefix:(NSString*)namePrefix offset:(uint32_t)offset limit:(uint32_t)limit withCompletion:(IdentitiesCompletionBlock)completion {
    return [self searchIdentitiesByNamePrefix:namePrefix inDomain:@"dash" offset:offset limit:limit withCompletion:completion];
}

- (id<DSDAPINetworkServiceRequest>)searchIdentitiesByNamePrefix:(NSString*)namePrefix inDomain:(NSString*)domain offset:(uint32_t)offset limit:(uint32_t)limit withCompletion:(IdentitiesCompletionBlock)completion {
    DSDAPIClient * client = self.chain.chainManager.DAPIClient;
    id<DSDAPINetworkServiceRequest> call = [client.DAPINetworkService searchDPNSDocumentsForUsernamePrefix:namePrefix inDomain:domain offset:offset limit:limit success:^(NSArray<NSDictionary *> * _Nonnull documents) {
        __block NSMutableArray * rBlockchainIdentities = [NSMutableArray array];
        for (NSDictionary * document in documents) {
            NSString * userId = document[@"$ownerId"];
            NSString * label = document[@"label"];
            NSString * domain = document[@"normalizedParentDomainName"];
            UInt256 uniqueId = userId.base58ToData.UInt256;
            DSBlockchainIdentity * identity = [self.chain blockchainIdentityForUniqueId:uniqueId foundInWallet:nil includeForeignBlockchainIdentities:YES];
            if (!identity) {
                identity = [[DSBlockchainIdentity alloc] initWithUniqueId:userId.base58ToData.UInt256 isTransient:TRUE onChain:self.chain];
                [identity addUsername:label inDomain:domain status:DSBlockchainIdentityUsernameStatus_Confirmed save:NO registerOnNetwork:NO];
            } else {
                if (![identity.dashpayUsernames containsObject:label]) {
                    [identity addUsername:label inDomain:domain status:DSBlockchainIdentityUsernameStatus_Confirmed save:YES registerOnNetwork:NO];
                }
            }
            
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
            NSString * domain = document[@"normalizedParentDomainName"];
            DSBlockchainIdentity * identity = [[DSBlockchainIdentity alloc] initWithUniqueId:userId.base58ToData.UInt256 isTransient:TRUE onChain:self.chain];
            [identity addUsername:normalizedLabel inDomain:domain status:DSBlockchainIdentityUsernameStatus_Confirmed save:NO registerOnNetwork:NO];
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
