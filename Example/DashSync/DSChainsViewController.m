//
//  DSChainsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 5/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSChainsViewController.h"
#import <DashSync/DashSync.h>
#import "DSChainTableViewCell.h"
#import "DSSyncViewController.h"
#import "DSAddDevnetViewController.h"

@interface DSChainsViewController ()

@property (strong, nonatomic) id addChainsObserver;

@end

@implementation DSChainsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.addChainsObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSChainsDidChangeNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           NSLog(@"Added/removed a chain");
                                                           [self.tableView reloadData];
                                                       }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2 + [[[DSChainManager sharedInstance] devnetChains] count];
}

-(DSChain*)chainForIndex:(NSInteger)index {
    if (index == 0) return [DSChain mainnet];
    if (index == 1) return [DSChain testnet];
    NSInteger devnetIndex = index - 2;
    NSArray * devnetChains = [[DSChainManager sharedInstance] devnetChains];
    return [devnetChains objectAtIndex:devnetIndex];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSChainTableViewCell *cell = (DSChainTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"chainTableViewCell" forIndexPath:indexPath];
    DSChain * chain = [self chainForIndex:indexPath.row];
    if (cell) {
        cell.chainNameLabel.text = chain.name;
    }
    
    return cell;
}



// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    if (indexPath.row > 1) {
        return YES;
    } else {
        return NO;
    }
}

-(NSArray*)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewRowAction * deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Delete" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        DSChain * chain = [self chainForIndex:indexPath.row];
        [[DSChainManager sharedInstance] removeDevnetChain:chain];
        
    }];
    UITableViewRowAction * editAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Edit" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self performSegueWithIdentifier:@"AddDevnetSegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
    }];
    return @[deleteAction,editAction];
}



//// Override to support editing the table view.
//- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
//    if (editingStyle == UITableViewCellEditingStyleDelete) {
//        // Delete the row from the data source
//        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
//    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
//        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
//    }
//}


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


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    UITableViewCell * cell = (UITableViewCell*)sender;
    NSInteger index = [self.tableView indexPathForCell:cell].row;
    if ([segue.identifier isEqualToString:@"ChainDetailsSegue"]) {
        DSSyncViewController * syncViewController = (DSSyncViewController *)segue.destinationViewController;
        DSChain * chain = [self chainForIndex:index];
        syncViewController.chainPeerManager = [[DSChainManager sharedInstance] peerManagerForChain:chain];
        syncViewController.title = chain.name;
    } else if ([segue.identifier isEqualToString:@"AddDevnetSegue"]) {
        if ([sender isKindOfClass:[UITableViewCell class]]) {
        DSAddDevnetViewController * addDevnetViewController = (DSAddDevnetViewController *)((UINavigationController*)segue.destinationViewController).topViewController;
        DSChain * chain = [self chainForIndex:index];
        addDevnetViewController.chain = chain;
        }
    }
}


@end
