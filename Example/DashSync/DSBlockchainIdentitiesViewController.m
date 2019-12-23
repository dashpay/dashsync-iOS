//
//  DSBlockchainIdentitiesViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/26/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSBlockchainIdentitiesViewController.h"
#import "DSBlockchainIdentityTableViewCell.h"
#import "DSCreateBlockchainIdentityViewController.h"
#import "DSBlockchainIdentityActionsViewController.h"

@interface DSBlockchainIdentitiesViewController ()

@property (nonatomic,strong) id<NSObject> chainBlockchainIdentitiesObserver;

@end

@implementation DSBlockchainIdentitiesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.chainBlockchainIdentitiesObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSChainBlockchainIdentitiesDidChangeNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           [self.tableView reloadData];
                                                       }];
    
    
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    DSWallet * wallet = [self.chainManager.chain.wallets objectAtIndex:section];
    return [wallet.blockchainIdentities count];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.chainManager.chain.wallets count];
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSBlockchainIdentityTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BlockchainIdentityCellIdentifier"];
    
    // Set up the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(void)configureCell:(DSBlockchainIdentityTableViewCell*)blockchainIdentityCell atIndexPath:(NSIndexPath *)indexPath {
    @autoreleasepool {
        DSWallet * wallet = [self.chainManager.chain.wallets objectAtIndex:indexPath.section];
        DSBlockchainIdentity * blockchainIdentity = [[wallet.blockchainIdentities allValues] objectAtIndex:indexPath.row];
        blockchainIdentityCell.usernameLabel.text = blockchainIdentity.username;
        blockchainIdentityCell.creditBalanceLabel.text = [NSString stringWithFormat:@"%llu",blockchainIdentity.creditBalance];
        if (blockchainIdentity.blockchainIdentityRegistrationTransaction) {
            blockchainIdentityCell.confirmationsLabel.text = [NSString stringWithFormat:@"%u",(self.chainManager.chain.lastBlockHeight - blockchainIdentity.blockchainIdentityRegistrationTransaction.blockHeight)];
        }
       // blockchainIdentityCell.publicKeyLabel.text = blockchainIdentity;
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {

    return YES;
}

-(NSArray*)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewRowAction * deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Delete" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        DSWallet * wallet = [self.chainManager.chain.wallets objectAtIndex:indexPath.section];
        DSBlockchainIdentity * blockchainIdentity = [[wallet.blockchainIdentities allValues] objectAtIndex:indexPath.row];
        [wallet unregisterBlockchainIdentity:blockchainIdentity];
    }];
    UITableViewRowAction * editAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Edit" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        //[self performSegueWithIdentifier:@"CreateBlockchainIdentitySegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
    }];
    return @[deleteAction,editAction];
}


-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"CreateBlockchainIdentitySegue"]) {
        DSCreateBlockchainIdentityViewController * createBlockchainIdentityViewController = (DSCreateBlockchainIdentityViewController*)((UINavigationController*)segue.destinationViewController).topViewController;
        createBlockchainIdentityViewController.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"BlockchainIdentityActionsSegue"]) {
        DSBlockchainIdentityActionsViewController * blockchainIdentityActionsViewController = segue.destinationViewController;
        blockchainIdentityActionsViewController.chainManager = self.chainManager;
        NSIndexPath * indexPath = [self.tableView indexPathForSelectedRow];
        DSWallet * wallet = [self.chainManager.chain.wallets objectAtIndex:indexPath.section];
        DSBlockchainIdentity * blockchainIdentity = [[wallet.blockchainIdentities allValues] objectAtIndex:indexPath.row];
        blockchainIdentityActionsViewController.blockchainIdentity = blockchainIdentity;
    }
}

@end
