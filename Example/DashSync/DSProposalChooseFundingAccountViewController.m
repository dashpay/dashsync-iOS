//
//  DSProposalChooseFundingAccountViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/5/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSProposalChooseFundingAccountViewController.h"
#import "DSAccountTableViewCell.h"

@interface DSProposalChooseFundingAccountViewController ()
@property (strong, nonatomic) IBOutlet UIBarButtonItem *chooseButton;
- (IBAction)choose:(id)sender;

@end

@implementation DSProposalChooseFundingAccountViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.chooseButton.enabled = FALSE;
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
    return [self.chain.wallets count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[self.chain.wallets objectAtIndex:section] accounts] count];
}

-(NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    DSWallet * wallet = [self.chain.wallets objectAtIndex:section];
    return wallet.uniqueID;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSAccountTableViewCell *cell = (DSAccountTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"AccountCellIdentifier" forIndexPath:indexPath];
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(void)configureCell:(DSAccountTableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    DSWallet * wallet = [self.chain.wallets objectAtIndex:indexPath.section];
    DSAccount * account = [[wallet accounts] objectAtIndex:indexPath.row];
    cell.accountNumberLabel.text = [NSString stringWithFormat:@"%u",account.accountNumber];
    cell.balanceLabel.text = [[DSPriceManager sharedInstance] stringForDashAmount:account.balance];
    [[DSPriceManager sharedInstance] stringForDashAmount:account.balance];
}

-(NSIndexPath*)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    DSWallet * wallet = [self.chain.wallets objectAtIndex:indexPath.section];
    DSAccount * account = [[wallet accounts] objectAtIndex:indexPath.row];
    if (account.balance > PROPOSAL_COST) {
        self.chooseButton.enabled = TRUE;
        return indexPath;
    }
    self.chooseButton.enabled = FALSE;
    return nil;
}

- (IBAction)choose:(id)sender {
    if (self.tableView.indexPathForSelectedRow) {
        DSWallet * wallet = [self.chain.wallets objectAtIndex:self.tableView.indexPathForSelectedRow.section];
        DSAccount * account = [[wallet accounts] objectAtIndex:self.tableView.indexPathForSelectedRow.row];
        if (account.balance > PROPOSAL_COST) {
            [self.delegate viewController:self didChooseAccount:account];
            [self.navigationController popViewControllerAnimated:TRUE];
        }
    }
}

@end
