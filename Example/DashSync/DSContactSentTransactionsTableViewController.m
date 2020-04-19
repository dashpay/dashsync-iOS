//  
//  Created by Sam Westrich
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

#import "DSContactSentTransactionsTableViewController.h"
#import "DSTransactionTableViewCell.h"

@interface DSContactSentTransactionsTableViewController ()

@property (nonatomic,strong) DSAccount * account;

@end

@implementation DSContactSentTransactionsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.direction = DSContactTransactionDirectionSent;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mocDidSaveNotification:)
                                                 name:NSManagedObjectContextDidSaveNotification object:[NSManagedObject context]];
}

-(void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:[NSManagedObject context]];
}

- (void)mocDidSaveNotification:(NSNotification *)notification {
    // Since NSFetchedResultsController doesn't observe relationship changes we have to manully trigger an update
    // http://openradar.appspot.com/radar?id=1754401
    BOOL (^objectsHasChangedContact)(NSArray *, DSDashpayUserEntity *) = ^BOOL(NSArray *objects, DSDashpayUserEntity *contact) {
        BOOL hasRelationshipChanges = NO;
        for (NSManagedObject *mo in objects) {
            if ([mo isKindOfClass:DSFriendRequestEntity.class]) {
                DSFriendRequestEntity *friendRequest = (DSFriendRequestEntity *)mo;
                if (friendRequest.sourceContact == contact ||
                    friendRequest.destinationContact == contact) {
                    hasRelationshipChanges = YES;
                    break;
                }
            }
        }
        
        return hasRelationshipChanges;
    };

    NSArray <NSManagedObject *> *insertedObjects = notification.userInfo[NSInsertedObjectsKey];
    NSArray <NSManagedObject *> *updatedObjects = notification.userInfo[NSUpdatedObjectsKey];
    NSArray <NSManagedObject *> *deletedObjects = notification.userInfo[NSDeletedObjectsKey];
    
    DSDashpayUserEntity *contact = self.blockchainIdentity.matchingDashpayUser;
    if (objectsHasChangedContact(insertedObjects, contact) ||
        objectsHasChangedContact(updatedObjects, contact) ||
        objectsHasChangedContact(deletedObjects, contact)) {
        [self.context mergeChangesFromContextDidSaveNotification:notification];
    }
}

-(void)setBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity {
    _blockchainIdentity = blockchainIdentity;
    if (_friendRequest) {
        self.account = [blockchainIdentity.wallet accountWithNumber:_friendRequest.account.index];
    }
}

-(void)setFriendRequest:(DSFriendRequestEntity *)friendRequest {
    _friendRequest = friendRequest;
    if (_blockchainIdentity) {
        self.account = [_blockchainIdentity.wallet accountWithNumber:_friendRequest.account.index];
    }
}

- (NSString *)entityName {
    return @"DSTxOutputEntity";
}

-(NSPredicate*)predicate {
    return [NSPredicate predicateWithFormat:@"localAddress.derivationPath.friendRequest == %@",self.friendRequest];
}

- (NSArray<NSSortDescriptor *> *)sortDescriptors {
    NSSortDescriptor *usernameSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"transaction.transactionHash.blockHeight" ascending:YES];
    return @[usernameSortDescriptor];
}

@end
