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
#import <DashSync/DSCreditFundingTransaction.h>
#import "DSMerkleBlock.h"

@interface DSBlockchainIdentitiesViewController ()

@property (nonatomic,strong) id<NSObject> chainBlockchainIdentitiesObserver;
@property (nonatomic,strong) NSArray <NSArray*>* orderedBlockchainIdentities;

@end

@implementation DSBlockchainIdentitiesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.chainBlockchainIdentitiesObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSChainBlockchainIdentitiesDidChangeNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           [self.tableView reloadData];
                                                       }];
    

    NSMutableArray * mOrderedBlockchainIdentities = [NSMutableArray array];
    for (DSWallet * wallet in self.chainManager.chain.wallets) {
        if ([wallet.blockchainIdentities count]) {
            [mOrderedBlockchainIdentities addObject:[[wallet.blockchainIdentities allValues] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"registrationCreditFundingTransaction.blockHeight" ascending:NO]]]];
        }
    }
    
    self.orderedBlockchainIdentities = [mOrderedBlockchainIdentities copy];
    
    
    // Do any additional setup after loading the view.
}

-(DSWallet*)walletAtIndex:(NSUInteger)index {
    NSUInteger currentIndex = 0;
    for (DSWallet * wallet in self.chainManager.chain.wallets) {
        if ([wallet.blockchainIdentities count]) {
            if (currentIndex == index) {
                return wallet;
            }
            currentIndex++;
        }
    }
    return nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self.orderedBlockchainIdentities[section] count];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.orderedBlockchainIdentities count];
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSBlockchainIdentityTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BlockchainIdentityCellIdentifier"];
    
    // Set up the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(void)configureCell:(DSBlockchainIdentityTableViewCell*)blockchainIdentityCell atIndexPath:(NSIndexPath *)indexPath {
    @autoreleasepool {
        DSBlockchainIdentity * blockchainIdentity = self.orderedBlockchainIdentities[indexPath.section][indexPath.row];
        blockchainIdentityCell.usernameLabel.text = blockchainIdentity.currentUsername?blockchainIdentity.currentUsername:@"Not yet set";
        blockchainIdentityCell.creditBalanceLabel.text = [NSString stringWithFormat:@"%llu",blockchainIdentity.creditBalance];
        if (blockchainIdentity.registrationCreditFundingTransaction) {
            if (blockchainIdentity.registrationCreditFundingTransaction.blockHeight == BLOCK_UNKNOWN_HEIGHT) {
                blockchainIdentityCell.confirmationsLabel.text = @"unconfirmed";
            } else {
            blockchainIdentityCell.confirmationsLabel.text = [NSString stringWithFormat:@"%u",(self.chainManager.chain.lastBlockHeight - blockchainIdentity.registrationCreditFundingTransaction.blockHeight + 1)];
            }
        }
        blockchainIdentityCell.registrationL2StatusLabel.text = blockchainIdentity.registrationStatusString;
        blockchainIdentityCell.publicKeysLabel.text = [NSString stringWithFormat:@"%u",blockchainIdentity.activeKeys];
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {

    return YES;
}

-(NSArray*)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewRowAction * deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Delete" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        DSWallet * wallet = [self walletAtIndex:indexPath.section];
        DSBlockchainIdentity * blockchainIdentity = self.orderedBlockchainIdentities[indexPath.section][indexPath.row];
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
        DSBlockchainIdentity * blockchainIdentity = self.orderedBlockchainIdentities[indexPath.section][indexPath.row];
        blockchainIdentityActionsViewController.blockchainIdentity = blockchainIdentity;
    }
}

@end
