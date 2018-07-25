//
//  DSBlockchainUsersViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/26/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSBlockchainUsersViewController.h"

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
    return [self.chainPeerManager.chain.wallets count];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

@end
