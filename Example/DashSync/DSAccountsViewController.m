//
//  DSAccountsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/3/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSAccountsViewController.h"
#import "DSAccountTableViewCell.h"
#import "DSAccountsDerivationPathsViewController.h"

@interface DSAccountsViewController ()

@property (nonatomic, strong) NSArray<DSAccount *> *accounts;

@end

@implementation DSAccountsViewController

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
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.wallet.accounts count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSAccountTableViewCell *cell = (DSAccountTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"AccountCellIdentifier" forIndexPath:indexPath];

    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (NSArray *)accounts {
    if (_accounts) return _accounts;
    _accounts = [self.wallet.accounts sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"accountNumber" ascending:TRUE]]];
    return _accounts;
}

- (void)configureCell:(DSAccountTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    DSAccount *account = [[self accounts] objectAtIndex:indexPath.row];
    cell.accountNumberLabel.text = [NSString stringWithFormat:@"%u", account.accountNumber];
    cell.balanceLabel.text = [[DSPriceManager sharedInstance] stringForDashAmount:account.balance];
    [[DSPriceManager sharedInstance] stringForDashAmount:account.balance];
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

- (IBAction)addAccount:(id)sender {
    DSChain *chain = self.wallet.chain;
    uint32_t addAccountNumber = self.wallet.lastAccountNumber + 1;
    NSArray *derivationPaths = [self.wallet.chain standardDerivationPathsForAccountNumber:addAccountNumber];
    DSAccount *addAccount = [DSAccount accountWithAccountNumber:addAccountNumber withDerivationPaths:derivationPaths inContext:self.wallet.chain.chainManagedObjectContext];
    [self.wallet seedPhraseAfterAuthenticationWithPrompt:@"Add account?"
                                              completion:^(NSString *_Nullable seedPhrase) {
                                                  NSData *derivedKeyData = (seedPhrase) ? [[DSBIP39Mnemonic sharedInstance]
                                                                                              deriveKeyFromPhrase:seedPhrase
                                                                                                   withPassphrase:nil] :
                                                                                          nil;
                                                  for (DSDerivationPath *derivationPath in addAccount.fundDerivationPaths) {
                                                      [derivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:self.wallet.uniqueIDString];
                                                  }
                                                  if ([chain isEvolutionEnabled]) {
                                                      [addAccount.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:self.wallet.uniqueIDString];
                                                  }

                                                  [self.wallet addAccount:addAccount];
                                                  [addAccount loadDerivationPaths];
                                                  self.accounts = nil; // It will reload from wallet with Lazy loading.
                                                  [self.tableView reloadData];
                                              }];
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ViewAccountsDerivationPathsSegue"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        DSAccountsDerivationPathsViewController *accountsDerivationPathsViewController = (DSAccountsDerivationPathsViewController *)segue.destinationViewController;
        accountsDerivationPathsViewController.account = [self.accounts objectAtIndex:indexPath.row];
    }
}
@end
