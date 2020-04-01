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

#import "DSRegisterContractsViewController.h"
#import "DSContractTableViewCell.h"

@interface DSRegisterContractsViewController ()

@property (nonatomic,strong) DSDashPlatform * platform;
@property (nonatomic,strong) NSDictionary * contracts;
@property (nonatomic,strong) id contractObserver;

@end

@implementation DSRegisterContractsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.platform = [DSDashPlatform sharedInstanceForChain:self.blockchainIdentity.wallet.chain];
    self.contracts = self.platform.knownContracts;
    self.contractObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DPContractDidUpdateNotification object:nil
                                                                               queue:nil usingBlock:^(NSNotification *note) {
        DPContract * contract = note.userInfo[DSContractUpdateNotificationKey];
        NSUInteger index = [[self.contracts allValues] indexOfObject:contract];
        if (index != NSNotFound) {
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
        }
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return self.platform.knownContracts.count;
        case 1:
            return 1;
    }
    return 0;
}

-(void)configureContractCell:(DSContractTableViewCell *)cell forItemIndex:(NSUInteger)index {
    NSString * identifier = [[self.contracts allKeys] objectAtIndex:index];
    DPContract * contract = self.contracts[identifier];
    cell.contractNameLabel.text = contract.name;
    if (!uint256_is_zero(contract.registeredBlockchainIdentityUniqueID) && [contract.base58ContractID isEqualToString:self.blockchainIdentity.uniqueIdString]) {
        cell.statusLabel.text = [NSString stringWithFormat:@"%@ - self",contract.statusString];
    } else {
        cell.statusLabel.text = contract.statusString;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell * cell;
    
    if (!indexPath.section) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"ContractTableViewCellIdentifier" forIndexPath:indexPath];
        [self configureContractCell:(DSContractTableViewCell *)cell forItemIndex:indexPath.row];
    } else {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = @"Add Contract";
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath.section) {
        NSString * identifier = [[self.platform.knownContracts allKeys] objectAtIndex:indexPath.row];
        DPContract * contract = self.platform.knownContracts[identifier];
        [self.blockchainIdentity fetchAndUpdateContract:contract];
    }
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}


@end
