//
//  DSWalletChooserViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/5/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSWalletChooserViewController.h"
#import "DSWalletTableViewCell.h"

@interface DSWalletChooserViewController ()
@property (strong, nonatomic) IBOutlet UIBarButtonItem *chooseButton;
- (IBAction)choose:(id)sender;

@end

@implementation DSWalletChooserViewController

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
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.chain.wallets count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSWalletTableViewCell *cell = (DSWalletTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"WalletCellIdentifier" forIndexPath:indexPath];
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(void)configureCell:(DSWalletTableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    DSWallet * wallet = [self.chain.wallets objectAtIndex:indexPath.section];
    cell.xPublicKeyLabel.text = wallet.uniqueID;
}

-(NSIndexPath*)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    DSWallet * wallet = [self.chain.wallets objectAtIndex:indexPath.row];
    if (wallet.balance != 0) {
        self.chooseButton.enabled = TRUE;
        return indexPath;
    }
    self.chooseButton.enabled = FALSE;
    return nil;
}

- (IBAction)choose:(id)sender {
    if (self.tableView.indexPathForSelectedRow) {
        DSWallet * wallet = [self.chain.wallets objectAtIndex:self.tableView.indexPathForSelectedRow.row];
        [self.delegate viewController:self didChooseWallet:wallet];
        [self.navigationController popViewControllerAnimated:TRUE];
    }
}

@end
