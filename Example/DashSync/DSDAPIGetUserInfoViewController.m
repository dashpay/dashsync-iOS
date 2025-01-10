//
//  DSDAPIGetUserInfoViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 9/14/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSDAPIGetUserInfoViewController.h"
#import "DSKeyValueTableViewCell.h"

@interface DSDAPIGetUserInfoViewController ()

@property (nonatomic, strong) DSKeyValueTableViewCell *usernameCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *regTxIdCell;

@property (nonatomic, strong) NSDictionary *userInfo;

@end

@implementation DSDAPIGetUserInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.usernameCell = [self.tableView dequeueReusableCellWithIdentifier:@"UsernameCellIdentifier"];
    self.regTxIdCell = [self.tableView dequeueReusableCellWithIdentifier:@"RegTxIdCellIdentifier"];
    self.userInfo = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1 + !!self.userInfo;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return 2;
        case 1:
            return 1;
        default:
            return 1;
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0:
            switch (indexPath.row) {
                case 0:
                    return self.usernameCell;
                case 1:
                    return self.regTxIdCell;
                default:
                    NSAssert(NO, @"Unknown cell");
                    return [[UITableViewCell alloc] init];
            }
        case 1: {
            UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"UsernameCellIdentifier"];
            return cell;
        }
        default:
            NSAssert(NO, @"Unknown cell");
            return [[UITableViewCell alloc] init];
    }
}

- (IBAction)search:(id)sender {
    NSString *username = nil;
    if (self.usernameCell.valueTextField.text && ![self.usernameCell.valueTextField.text isEqualToString:@""]) {
        username = self.usernameCell.valueTextField.text;
    } else if (self.regTxIdCell.valueTextField.text && ![self.regTxIdCell.valueTextField.text isEqualToString:@""]) {
        username = self.regTxIdCell.valueTextField.text;
    }

    if (!username) {
        return;
    }
    
//    spv_identity_

    [self.chainManager.DAPIClient.DAPIPlatformNetworkService getIdentityByName:username
        inDomain:@"dash"
        completionQueue:dispatch_get_main_queue()
        success:^(NSDictionary *_Nonnull identity) {
            NSLog(@"%@", identity);
        }
        failure:^(NSError *_Nonnull error) {
            NSLog(@"%@", error);
        }];
}

@end
