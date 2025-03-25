//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import "DSIdentitiesManager+CoreData.h"
#import "DSIdentity+Protected.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "NSManagedObjectContext+DSSugar.h"

@interface DSIdentitiesManager ()
@property (nonatomic, strong) NSMutableDictionary *foreignIdentities;
@end

@implementation DSIdentitiesManager (CoreData)

- (void)clearExternalIdentities {
    self.foreignIdentities = [NSMutableDictionary dictionary];
}

- (void)setup {
    [self clearExternalIdentities];
    [self loadExternalIdentities];
}


- (void)loadExternalIdentities {
    NSManagedObjectContext *context = [NSManagedObjectContext chainContext]; //shouldn't matter what context is used
    
    [context performBlockAndWait:^{
        NSArray<DSBlockchainIdentityEntity *> *externalIdentityEntities = [DSBlockchainIdentityEntity objectsInContext:context matching:@"chain == %@ && isLocal == FALSE", [self.chain chainEntityInContext:context]];
        for (DSBlockchainIdentityEntity *entity in externalIdentityEntities) {
            DSIdentity *identity = [[DSIdentity alloc] initWithIdentityEntity:entity];
            if (identity) {
                self.foreignIdentities[uint256_data(identity.uniqueID)] = identity;
            }
        }
    }];
}

- (void)registerForeignIdentity:(DSIdentity *)identity {
    NSAssert(!identity.isTransient, @"Dash Identity should no longer be transient");
    @synchronized(self.foreignIdentities) {
        if (!self.foreignIdentities[uint256_data(identity.uniqueID)]) {
            [identity saveInitial];
            self.foreignIdentities[uint256_data(identity.uniqueID)] = identity;
        }
    }
}
- (DSIdentity *)foreignIdentityWithUniqueId:(UInt256)uniqueId {
    return [self foreignIdentityWithUniqueId:uniqueId createIfMissing:NO inContext:nil];
}

- (DSIdentity *)foreignIdentityWithUniqueId:(UInt256)uniqueId
                            createIfMissing:(BOOL)addIfMissing
                                  inContext:(NSManagedObjectContext *_Nullable)context {
    //foreign blockchain identities are for local blockchain identies' contacts, not for search.
    @synchronized(self.foreignIdentities) {
        DSIdentity *foreignIdentity = self.foreignIdentities[uint256_data(uniqueId)];
        if (foreignIdentity) {
            NSAssert(context ? [foreignIdentity identityEntityInContext:context] : foreignIdentity.identityEntity, @"Blockchain identity entity should exist");
            return foreignIdentity;
        } else if (addIfMissing) {
            foreignIdentity = [[DSIdentity alloc] initWithUniqueId:uniqueId isTransient:FALSE onChain:self.chain];
            [foreignIdentity saveInitialInContext:context];
            self.foreignIdentities[uint256_data(uniqueId)] = foreignIdentity;
            return self.foreignIdentities[uint256_data(uniqueId)];
        }
        return nil;
    }
}


@end
