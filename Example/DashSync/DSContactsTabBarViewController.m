//
//  DSContactsTabBarViewController.m
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 08/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSContactsTabBarViewController.h"

#import "DSContactsViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSContactsTabBarViewController ()

@end

@implementation DSContactsTabBarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    DSContactsViewController *contacts = [self.storyboard instantiateViewControllerWithIdentifier:@"ContactsControllerId"];
    contacts.chainManager = self.chainManager;
    contacts.blockchainUser = self.blockchainUser;
    
    self.viewControllers = @[contacts];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

- (IBAction)doneButtonAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end

NS_ASSUME_NONNULL_END
