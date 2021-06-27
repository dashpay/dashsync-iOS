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

#import "DSContactReceivedTransactionsTableViewController.h"

@interface DSContactReceivedTransactionsTableViewController ()

@property (nonatomic, strong) DSAccount *account;

@end

@implementation DSContactReceivedTransactionsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.direction = DSContactTransactionDirectionReceived;
}

- (void)setBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity {
    _blockchainIdentity = blockchainIdentity;
    if (_friendRequest) {
        self.account = [blockchainIdentity.wallet accountWithNumber:_friendRequest.account.index];
    }
}

- (void)setFriendRequest:(DSFriendRequestEntity *)friendRequest {
    _friendRequest = friendRequest;
    if (_blockchainIdentity) {
        self.account = [_blockchainIdentity.wallet accountWithNumber:_friendRequest.account.index];
    }
}

- (NSString *)entityName {
    return @"DSTxOutputEntity";
}

- (NSPredicate *)predicate {
    return [NSPredicate predicateWithFormat:@"localAddress.derivationPath.friendRequest == %@", self.friendRequest];
}

- (NSArray<NSSortDescriptor *> *)sortDescriptors {
    NSSortDescriptor *usernameSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"transaction.transactionHash.blockHeight" ascending:YES];
    return @[usernameSortDescriptor];
}

@end
