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

#import "DSIdentityKeysViewController.h"
#import "DSIdentityKeyTableViewCell.h"
#import "DSKeyManager.h"

@interface DSIdentityKeysViewController ()

@end

@implementation DSIdentityKeysViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.identity totalKeyCount];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSIdentityKeyTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BlockchainIdentityKeyCellIdentifier" forIndexPath:indexPath];

    DMaybeOpaqueKey *key = [self.identity keyAtIndex:indexPath.row];
    NSData *publicKeyData = [DSKeyManager publicKeyData:key->ok];
    cell.indexLabel.text = [NSString stringWithFormat:@"%ld", (long)indexPath.row];
    cell.publicKeyLabel.text = publicKeyData.base64String;
    cell.statusLabel.text = [self.identity localizedStatusOfKeyAtIndex:indexPath.row];
    cell.typeLabel.text = [DSKeyManager localizedKeyType:key->ok];
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    DSIdentityKeyStatus status = [self.identity statusOfKeyAtIndex:indexPath.row];
    if (status == DSIdentityKeyStatus_NotRegistered) {
        return YES;
    } else {
        return NO;
    }
}

@end
