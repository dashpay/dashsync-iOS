//
//  DSSpecializedDerivationPathsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 3/6/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSSpecializedDerivationPathsViewController.h"
#import "DSAuthenticationKeysDerivationPathsAddressesViewController.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSDerivationPathTableViewCell.h"

@interface DSSpecializedDerivationPathsViewController ()

@property (nonatomic, strong) NSArray<DSDerivationPath *> *derivationPaths;

@end

@implementation DSSpecializedDerivationPathsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.derivationPaths = [[DSDerivationPathFactory sharedInstance] loadedSpecializedDerivationPathsForWallet:self.wallet];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.derivationPaths.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"DerivationPathCellIdentifier";

    DSDerivationPath *derivationPath = self.derivationPaths[indexPath.row];

    DSDerivationPathTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];

    cell.derivationPathLabel.text = derivationPath.stringRepresentation;
    cell.signingMechanismLabel.text = (derivationPath.signingAlgorithm == KeyKind_ECDSA) ? @"ECDSA" : (derivationPath.signingAlgorithm == KeyKind_ED25519) ? @"ED" : @"BLS";
    cell.referenceNameLabel.text = derivationPath.referenceName;

    cell.knownAddressesLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)derivationPath.allAddresses.count];
    cell.usedAddressesLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)derivationPath.usedAddresses.count];
    cell.xPublicKeyLabel.text = derivationPath.extendedPublicKeyData.hexString;

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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    DSDerivationPath *derivationPath = [self.derivationPaths objectAtIndex:indexPath.row];
    if (derivationPath.type == DSDerivationPathType_MultipleUserAuthentication) {
        [self performSegueWithIdentifier:@"ViewDoubleSpecializedAddressesSegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
    } else if (derivationPath.type == DSDerivationPathType_SingleUserAuthentication) {
        [self performSegueWithIdentifier:@"ViewSingleSpecializedAddressesSegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
    }
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ViewSingleSpecializedAddressesSegue"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        DSAuthenticationKeysDerivationPathsAddressesViewController *derivationPathsAddressesViewController = (DSAuthenticationKeysDerivationPathsAddressesViewController *)segue.destinationViewController;
        derivationPathsAddressesViewController.derivationPath = (DSSimpleIndexedDerivationPath *)[self.derivationPaths objectAtIndex:indexPath.row];
    } else if ([segue.identifier isEqualToString:@"ViewDoubleSpecializedAddressesSegue"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        DSAuthenticationKeysDerivationPathsAddressesViewController *derivationPathsAddressesViewController = (DSAuthenticationKeysDerivationPathsAddressesViewController *)segue.destinationViewController;
        derivationPathsAddressesViewController.derivationPath = (DSAuthenticationKeysDerivationPath *)[self.derivationPaths objectAtIndex:indexPath.row];
    }
}


@end
