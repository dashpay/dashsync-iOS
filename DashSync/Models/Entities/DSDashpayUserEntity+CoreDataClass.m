//
//  DSdashpayUserEntity+CoreDataClass.m
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


#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSDerivationPathFactory.h"
#import "DSFundsDerivationPath.h"
#import "DSDashPlatform.h"
#import "NSData+Bitcoin.h"
#import "DSPotentialOneWayFriendship.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSIncomingFundsDerivationPath.h"
#import "NSData+Bitcoin.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSDashpayUserEntity

+(void)deleteContactsOnChain:(DSChainEntity*)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray * contactsToDelete = [self objectsMatching:@"(chain == %@)",chainEntity];
        for (DSDashpayUserEntity * contact in contactsToDelete) {
            [chainEntity.managedObjectContext deleteObject:contact];
        }
    }];
}

-(NSString*)username {
    //todo manage when more than 1 username
    DSBlockchainIdentityUsernameEntity * username = [self.associatedBlockchainIdentity.usernames anyObject];
    return username.stringValue;
}

//-(DPDocument*)profileDocument {
//
//}
//
//-(DPDocument*)contactRequestDocument {
//
//}

@end
