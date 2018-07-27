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
    DSWallet * wallet = [self.chainPeerManager.chain.wallets objectAtIndex:section];
    return [wallet.blockchainUsers count];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.chainPeerManager.chain.wallets count];
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSBlockchainUserTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BlockchainUserCellIdentifier"];
    
    // Set up the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(void)configureCell:(DSBlockchainUserTableViewCell*)blockchainUserCell atIndexPath:(NSIndexPath *)indexPath {
    @autoreleasepool {
        DSWallet * wallet = [self.chainPeerManager.chain.wallets objectAtIndex:indexPath.section];
        DSBlockchainUser * blockchainUser = [wallet.blockchainUsers objectAtIndex:indexPath.row];
        blockchainUserCell.usernameLabel.text = blockchainUser.username;
        blockchainUserCell.publicKeyLabel.text = blockchainUser.publicKeyHash;
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"CreateBlockchainUserSegue"]) {
        DSCreateBlockchainUserViewController * createBlockchainUserViewController = (DSCreateBlockchainUserViewController*)((UINavigationController*)segue.destinationViewController).topViewController;
        createBlockchainUserViewController.chain = self.chainPeerManager.chain;
    }
}

@end
