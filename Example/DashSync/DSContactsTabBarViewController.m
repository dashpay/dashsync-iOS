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

NS_ASSUME_NONNULL_BEGIN


@interface DSContactsTabBarViewController () <UITabBarControllerDelegate>


@property (strong, nonatomic) DSOutgoingContactsTableViewController *outgoingController;

@end

@implementation DSContactsTabBarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.delegate = self;
    
    if (!self.blockchainUser.ownContact) {
        __weak typeof(self) weakSelf = self;
        [self.blockchainUser createProfileWithAboutMeString:[NSString stringWithFormat:@"Hey I'm a demo user %@", self.blockchainUser.username] completion:^(BOOL success) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            
            [strongSelf showAlertTitle:@"Created profile:" result:success];
        }];
    }
    
    DSContactsViewController *contacts = [self.storyboard instantiateViewControllerWithIdentifier:@"ContactsControllerId"];
    contacts.blockchainUser = self.blockchainUser;
    
    DSOutgoingContactsTableViewController *outgoing = [self.storyboard instantiateViewControllerWithIdentifier:@"PendingControllerId"];
    outgoing.blockchainUser = self.blockchainUser;
    self.outgoingController = outgoing;
    
    DSIncomingContactsTableViewController *incoming = [self.storyboard instantiateViewControllerWithIdentifier:@"RequestsControllerId"];
    incoming.blockchainUser = self.blockchainUser;
    
    self.viewControllers = @[contacts, outgoing, incoming];
    
    self.title = contacts.title;
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
        NSParameterAssert(self.blockchainUser);
        DSAccount * account = [self.blockchainUser.wallet accountWithNumber:0];
        NSParameterAssert(account);
        DSPotentialContact *potentialContact = [[DSPotentialContact alloc] initWithUsername:username
                                                                        blockchainUserOwner:self.blockchainUser
                                                                                    account:account];
        
        [self.blockchainUser sendNewContactRequestToPotentialContact:potentialContact completion:^(BOOL success) {
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


- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    self.title = viewController.title;
}

@end

NS_ASSUME_NONNULL_END
