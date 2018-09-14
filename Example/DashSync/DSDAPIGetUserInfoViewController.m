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

@property (nonatomic,strong) DSKeyValueTableViewCell * usernameCell;
@property (nonatomic,strong) DSKeyValueTableViewCell * regTxIdCell;

@property (nonatomic,strong) NSDictionary * userInfo;

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
                    return nil;
            }
        case 1:
        {
            UITableViewCell * cell = [self.tableView dequeueReusableCellWithIdentifier:@"UsernameCellIdentifier"];
            return cell;
        }
        default:
            return nil;
    }
}

-(IBAction)search:(id)sender {
    if (self.usernameCell.valueTextField.text && ![self.usernameCell.valueTextField.text isEqualToString:@""]) {
        [self.chainPeerManager.DAPIPeerManager getUserByUsername:self.usernameCell.valueTextField.text withSuccess:^(NSDictionary *userInfo) {
            NSLog(@"%@",userInfo);
        } failure:^(NSError *error) {
            NSLog(@"%@",error);
        }];
    } else if (self.regTxIdCell.valueTextField.text && ![self.regTxIdCell.valueTextField.text isEqualToString:@""]) {
        [self.chainPeerManager.DAPIPeerManager getUserByUsername:self.regTxIdCell.valueTextField.text withSuccess:^(NSDictionary *userInfo) {
            NSLog(@"%@",userInfo);
        } failure:^(NSError *error) {
            NSLog(@"%@",error);
        }];
    }
}

@end
