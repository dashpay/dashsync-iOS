//
//  DSAccountsDerivationPathsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/3/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSAccountsDerivationPathsViewController.h"
#import "DSDerivationPathTableViewCell.h"
#import "DSDoubleDerivationPathsAddressesViewController.h"
#import "DSSendAmountViewController.h"

@interface DSAccountsDerivationPathsViewController ()

@end

@implementation DSAccountsDerivationPathsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return [self.account.fundDerivationPaths count];
    } else {
        return [self.account.outgoingFundDerivationPaths count];
    }
}


-(NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Funds";
    } else {
        return @"Friends";
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        return 237;
    } else {
        DSDerivationPath * derivationPath = (DSDerivationPath *)[self.account.fundDerivationPaths objectAtIndex:indexPath.row];
        if ([derivationPath isKindOfClass:[DSFundsDerivationPath class]]) {
            return 299;
        } else {
            return 237;
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        DSDerivationPathTableViewCell *cell = (DSDerivationPathTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"IncomingDerivationPathCellIdentifier" forIndexPath:indexPath];
        [self configureCell:cell atIndexPath:indexPath];
        return cell;
    } else {
        DSDerivationPath * derivationPath = (DSDerivationPath *)[self.account.fundDerivationPaths objectAtIndex:indexPath.row];
        if ([derivationPath isKindOfClass:[DSFundsDerivationPath class]]) {
            DSDerivationPathTableViewCell *cell = (DSDerivationPathTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"DerivationPathCellIdentifier" forIndexPath:indexPath];
            [self configureCell:cell atIndexPath:indexPath];
            return cell;
        } else {
            DSDerivationPathTableViewCell *cell = (DSDerivationPathTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"IncomingDerivationPathCellIdentifier" forIndexPath:indexPath];
            [self configureCell:cell atIndexPath:indexPath];
            return cell;
        }
    }
    
}


-(void)configureCell:(DSDerivationPathTableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    DSDerivationPath * derivationPath;
    if (indexPath.section == 1) {
        derivationPath = (DSDerivationPath *)[self.account.outgoingFundDerivationPaths objectAtIndex:indexPath.row];
    } else {
        derivationPath = (DSDerivationPath *)[self.account.fundDerivationPaths objectAtIndex:indexPath.row];
    }
    cell.xPublicKeyLabel.text = derivationPath.serializedExtendedPublicKey;
    cell.derivationPathLabel.text = derivationPath.stringRepresentation;
    cell.balanceLabel.text = [[DSPriceManager sharedInstance] stringForDashAmount:derivationPath.balance];
    cell.referenceNameLabel.text = derivationPath.referenceName;
    if ([derivationPath isKindOfClass:[DSFundsDerivationPath class]]) {
        DSFundsDerivationPath * fundsDerivationPath = (DSFundsDerivationPath *)derivationPath;
        cell.knownAddressesLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)fundsDerivationPath.allReceiveAddresses.count];
        cell.usedAddressesLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)fundsDerivationPath.usedReceiveAddresses.count];
        cell.knownInternalAddressesLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)fundsDerivationPath.allChangeAddresses.count];
        cell.usedInternalAddressesLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)fundsDerivationPath.usedChangeAddresses.count];
    } else if ([derivationPath isKindOfClass:[DSIncomingFundsDerivationPath class]]) {
        DSIncomingFundsDerivationPath * incomingFundsDerivationPath = (DSIncomingFundsDerivationPath *)derivationPath;
        cell.knownAddressesLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)incomingFundsDerivationPath.allReceiveAddresses.count];
        cell.usedAddressesLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)incomingFundsDerivationPath.usedReceiveAddresses.count];
    }
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

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ViewAddressesSegue"] || [segue.identifier isEqualToString:@"ViewAddressesSegue2"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        DSDoubleDerivationPathsAddressesViewController * derivationPathsAddressesViewController = (DSDoubleDerivationPathsAddressesViewController*)segue.destinationViewController;
        if (indexPath.section == 0) {
            derivationPathsAddressesViewController.derivationPath = (DSFundsDerivationPath*)[self.account.fundDerivationPaths objectAtIndex:indexPath.row];
        } else {
            derivationPathsAddressesViewController.derivationPath = (DSFundsDerivationPath*)[self.account.outgoingFundDerivationPaths objectAtIndex:indexPath.row];
        }
    } else if ([segue.identifier isEqualToString:@"SendAmountSegue"]) {
        DSSendAmountViewController * sendAmountViewController = (DSSendAmountViewController*)(((UINavigationController*)segue.destinationViewController).topViewController);
        sendAmountViewController.account = self.account;
    }
}


@end
