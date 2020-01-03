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

#import "DSBlockchainIdentityTransitionsViewController.h"
#import "DSTransitionTableViewCell.h"
#import "DSTransition.h"

@interface DSBlockchainIdentityTransitionsViewController ()

@property (nonatomic,strong) NSArray * transitions;


@end

@implementation DSBlockchainIdentityTransitionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.transitions = [self.blockchainIdentity allTransitions];
    
    UIRefreshControl * refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refreshStateTransitions) forControlEvents:UIControlEventValueChanged];
    
    self.tableView.refreshControl = refreshControl;
}

-(void)refreshStateTransitions {
    [self.chainManager.DAPIClient getAllStateTransitionsForUser:self.blockchainIdentity completion:^(NSError * _Nullable error) {
        if (!error) {
            self.transitions = [self.blockchainIdentity allTransitions];
            [self.tableView reloadData];
        }
        [self.tableView.refreshControl endRefreshing];
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.transitions.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * transitionCellIdentifier = @"TransitionCell";
    DSTransitionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:transitionCellIdentifier forIndexPath:indexPath];
    
    DSTransition * transition = [self.transitions objectAtIndex:indexPath.row];
    
    cell.numberLabel.text = [NSString stringWithFormat:@"%ld",(long)indexPath.row];
    //cell.confirmedInBlockLabel.text = [NSString stringWithFormat:@"%u",transition.blockHeight];
    cell.transactionLabel.text = uint256_hex(transition.transitionHash);
    //cell.previousTransitionHashLabel.text = uint256_hex(transition.previousTransitionHash);
    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
