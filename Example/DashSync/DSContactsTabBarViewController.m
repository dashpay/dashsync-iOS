//
//  DSContactsTabBarViewController.m
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 08/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSContactsTabBarViewController.h"

#import "DSContactsViewController.h"
#import "DSOutgoingContactsTableViewController.h"
#import "DSIncomingContactsTableViewController.h"

#import "DSContactsModel.h"

NS_ASSUME_NONNULL_BEGIN


@interface DSContactsTabBarViewController ()

@property (strong, nonatomic) DSContactsModel *model;
@property (strong, nonatomic) DSOutgoingContactsTableViewController *outgoingController;

@end

@implementation DSContactsTabBarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.model = [[DSContactsModel alloc] init];
    self.model.chainManager = self.chainManager;
    self.model.blockchainUser = self.blockchainUser;
    
    __weak typeof(self) weakSelf = self;
    [self.model getUser:^(BOOL success) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        [strongSelf showAlertTitle:@"Get current user result:" result:success];
    }];
    
    DSContactsViewController *contacts = [self.storyboard instantiateViewControllerWithIdentifier:@"ContactsControllerId"];
    contacts.model = self.model;
    
    DSOutgoingContactsTableViewController *outgoing = [self.storyboard instantiateViewControllerWithIdentifier:@"PendingControllerId"];
    outgoing.model = self.model;
    self.outgoingController = outgoing;
    
    DSIncomingContactsTableViewController *incoming = [self.storyboard instantiateViewControllerWithIdentifier:@"RequestsControllerId"];
    incoming.model = self.model;
    
    self.viewControllers = @[contacts, outgoing, incoming];
}

#pragma mark - Actions

- (IBAction)doneButtonAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)addContactAction:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Enter username to send contact request" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *username = textField.text;
        
        __weak typeof(self) weakSelf = self;
        [self.model contactRequestUsername:username completion:^(BOOL success) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            if (success) {
                [strongSelf.outgoingController refreshData];
            }
            
            [strongSelf showAlertTitle:@"Contact request result:" result:success];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Private

- (void)showAlertTitle:(NSString *)title result:(BOOL)result {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:result ? @"✅ success" : @"❌ failure" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

NS_ASSUME_NONNULL_END
