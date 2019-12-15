//
//  DSBlockchainUserActionsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 8/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSBlockchainUserActionsViewController.h"
#import "DSTopupBlockchainUserViewController.h"
#import "DSBlockchainUserTransitionsViewController.h"

#import "DSContactsNavigationController.h"
#import <DashSync/DSDAPIClient+RegisterDashPayContract.h>
#import <SDWebImage/SDWebImage.h>
#import "DSContactProfileViewController.h"

@interface DSBlockchainUserActionsViewController () <DSContactProfileViewControllerDelegate>
@property (strong, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (strong, nonatomic) IBOutlet UILabel *aboutMeLabel;
@property (strong, nonatomic) IBOutlet UILabel *transactionRegistrationHashLabel;

@end

@implementation DSBlockchainUserActionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadProfileInitial];
    [self.blockchainUser fetchProfile:^(BOOL success) {
        [self updateProfile];
    }];
}

-(void)loadProfileInitial {
    self.title = self.blockchainUser.username;
    if (!self.blockchainUser.ownContact) {
        self.aboutMeLabel.text = @"Fetching";
        [self.avatarImageView sd_setImageWithURL:nil];
    }
    else {
        self.aboutMeLabel.text = self.blockchainUser.ownContact.publicMessage;
        [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:self.blockchainUser.ownContact.avatarPath]];
    }
    
    self.transactionRegistrationHashLabel.text = uint256_hex(self.blockchainUser.registrationTransactionHash);
}

-(void)updateProfile {
    self.title = self.blockchainUser.username;
    if (!self.blockchainUser.ownContact) {
        self.aboutMeLabel.text = @"Register Profile";
        [self.avatarImageView sd_setImageWithURL:nil];
    }
    else {
        self.aboutMeLabel.text = self.blockchainUser.ownContact.publicMessage;
        [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:self.blockchainUser.ownContact.avatarPath]];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)raiseIssue:(NSString*)issue message:(NSString*)message {
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:issue message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }]];
    [self presentViewController:alert animated:TRUE completion:^{
        
    }];
}

-(IBAction)reset:(id)sender {
    [self.blockchainUser resetTransactionUsingNewIndex:self.blockchainUser.wallet.unusedBlockchainUserIndex completion:^(DSBlockchainUserResetTransaction *blockchainUserResetTransaction) {
        [self.chainManager.transactionManager publishTransaction:blockchainUserResetTransaction completion:^(NSError * _Nullable error) {
            if (error) {
                [self raiseIssue:@"Error" message:error.localizedDescription];
                
            } else {
                [self.navigationController popViewControllerAnimated:TRUE];
            }
        }];
    }];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 1) { // About me / Register
            DSContactProfileViewController *controller = [[DSContactProfileViewController alloc] initWithBlockchainUser:self.blockchainUser];
            controller.delegate = self;
            UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:controller];
            [self presentViewController:navigationController animated:YES completion:nil];
        }
    }
    else if (indexPath.section == 1) {
        if (indexPath.row == 1) {
            [self reset:self];
        }
        else if (indexPath.row == 2) {
            DSContactsNavigationController *controller = [DSContactsNavigationController controllerWithChainManager:self.chainManager blockchainUser:self.blockchainUser];
            [self presentViewController:controller animated:YES completion:nil];
        }
        else if (indexPath.row == 3) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            
            __weak typeof(self) weakSelf = self;
            [self.chainManager.DAPIClient ds_registerDashPayContractForUser:self.blockchainUser completion:^(NSError * _Nullable error) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                
                if (error) {
                    [strongSelf raiseIssue:@"Error" message:error.localizedDescription];
                }
            }];
        }
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"BlockchainUserTopupSegue"]) {
        DSTopupBlockchainUserViewController * topupBlockchainUserViewController = (DSTopupBlockchainUserViewController*)segue.destinationViewController;
        topupBlockchainUserViewController.chainManager = self.chainManager;
        topupBlockchainUserViewController.blockchainUser = self.blockchainUser;
    } else if ([segue.identifier isEqualToString:@"BlockchainUserTransitionsSegue"]) {
        DSBlockchainUserTransitionsViewController * blockchainUserTransitionsViewController = (DSBlockchainUserTransitionsViewController*)segue.destinationViewController;
        blockchainUserTransitionsViewController.chainManager = self.chainManager;
        blockchainUserTransitionsViewController.blockchainUser = self.blockchainUser;
    }
}

#pragma mark - DSContactProfileViewControllerDelegate

- (void)contactProfileViewControllerDidCancel:(DSContactProfileViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)contactProfileViewControllerDidUpdateProfile:(DSContactProfileViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
    
    [self.blockchainUser fetchProfile:^(BOOL success) {
        [self updateProfile];
    }];
}

@end
