//
//  DSBlockchainUsersViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/26/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSBlockchainUsersViewController.h"
#import "DSBlockchainUserTableViewCell.h"
#import "DSCreateBlockchainUserViewController.h"
#import "DSBlockchainUserActionsViewController.h"

@interface DSBlockchainUsersViewController ()

@property (nonatomic,strong) id<NSObject> chainBlockchainUsersObserver;

@end

@implementation DSBlockchainUsersViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.chainBlockchainUsersObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSChainBlockchainUsersDidChangeNotification object:nil
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
    return [wallet.blockchainUsers count];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.chainManager.chain.wallets count];
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSBlockchainUserTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BlockchainUserCellIdentifier"];
    
    // Set up the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(void)configureCell:(DSBlockchainUserTableViewCell*)blockchainUserCell atIndexPath:(NSIndexPath *)indexPath {
    @autoreleasepool {
        DSWallet * wallet = [self.chainManager.chain.wallets objectAtIndex:indexPath.section];
        DSBlockchainUser * blockchainUser = [wallet.blockchainUsers objectAtIndex:indexPath.row];
        blockchainUserCell.usernameLabel.text = blockchainUser.username;
        blockchainUserCell.creditBalanceLabel.text = [NSString stringWithFormat:@"%llu",blockchainUser.creditBalance];
        if (blockchainUser.blockchainUserRegistrationTransaction) {
            blockchainUserCell.confirmationsLabel.text = [NSString stringWithFormat:@"%u",(self.chainManager.chain.lastBlockHeight - blockchainUser.blockchainUserRegistrationTransaction.blockHeight)];
        }
       // blockchainUserCell.publicKeyLabel.text = blockchainUser;
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {

    return YES;
}

-(NSArray*)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewRowAction * deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Delete" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        DSWallet * wallet = [self.chainManager.chain.wallets objectAtIndex:indexPath.section];
        DSBlockchainUser * blockchainUser = [wallet.blockchainUsers objectAtIndex:indexPath.row];
        [wallet unregisterBlockchainUser:blockchainUser];
    }];
    UITableViewRowAction * editAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Edit" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        //[self performSegueWithIdentifier:@"CreateBlockchainUserSegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
    }];
    return @[deleteAction,editAction];
}


-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"CreateBlockchainUserSegue"]) {
        DSCreateBlockchainUserViewController * createBlockchainUserViewController = (DSCreateBlockchainUserViewController*)((UINavigationController*)segue.destinationViewController).topViewController;
        createBlockchainUserViewController.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"BlockchainUserActionsSegue"]) {
        DSBlockchainUserActionsViewController * blockchainUserActionsViewController = segue.destinationViewController;
        blockchainUserActionsViewController.chainManager = self.chainManager;
        NSIndexPath * indexPath = [self.tableView indexPathForSelectedRow];
        DSWallet * wallet = [self.chainManager.chain.wallets objectAtIndex:indexPath.section];
        DSBlockchainUser * blockchainUser = [wallet.blockchainUsers objectAtIndex:indexPath.row];
        blockchainUserActionsViewController.blockchainUser = blockchainUser;
    }
}

@end
