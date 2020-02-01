//
//  DSBlockchainIdentityActionsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 8/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSBlockchainIdentityActionsViewController.h"
#import "DSTopupBlockchainIdentityViewController.h"
#import "DSBlockchainIdentityTransitionsViewController.h"

#import "DSContactsNavigationController.h"
#import <DashSync/DSDAPIClient+RegisterDashPayContract.h>
#import <SDWebImage/SDWebImage.h>
#import "DSContactProfileViewController.h"

@interface DSBlockchainIdentityActionsViewController () <DSContactProfileViewControllerDelegate>
@property (strong, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (strong, nonatomic) IBOutlet UILabel *aboutMeLabel;
@property (strong, nonatomic) IBOutlet UILabel *uniqueIdLabel;

@end

@implementation DSBlockchainIdentityActionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadProfileInitial];
    [self.blockchainIdentity fetchProfile:^(BOOL success) {
        [self updateProfile];
    }];
}

-(void)loadProfileInitial {
    self.title = self.blockchainIdentity.currentUsername;
    if (!self.blockchainIdentity.ownContact) {
        self.aboutMeLabel.text = @"Fetching";
        [self.avatarImageView sd_setImageWithURL:nil];
    }
    else {
        self.aboutMeLabel.text = self.blockchainIdentity.ownContact.publicMessage;
        [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:self.blockchainIdentity.ownContact.avatarPath]];
    }
    
    self.uniqueIdLabel.text = self.blockchainIdentity.uniqueIdString;
}

-(void)updateProfile {
    self.title = self.blockchainIdentity.currentUsername;
    if (!self.blockchainIdentity.ownContact) {
        self.aboutMeLabel.text = @"Register Profile";
        [self.avatarImageView sd_setImageWithURL:nil];
    }
    else {
        self.aboutMeLabel.text = self.blockchainIdentity.ownContact.publicMessage;
        [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:self.blockchainIdentity.ownContact.avatarPath]];
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

-(IBAction)registerBlockchainIdentity:(id)sender {
    if (self.blockchainIdentity.isRegistered) return;
    [self.blockchainIdentity createAndPublishRegistrationTransitionWithCompletion:^(NSDictionary * _Nullable successInfo, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self raiseIssue:@"Unable to register." message:error.localizedDescription];
            });
        }
    }];
}

-(IBAction)reset:(id)sender {
//    [self.blockchainIdentity resetTransactionUsingNewIndex:self.blockchainIdentity.wallet.unusedBlockchainIdentityIndex completion:^(DSBlockchainIdentityUpdateTransition *blockchainIdentityResetTransaction) {
//        [self.chainManager.transactionManager publishTransaction:blockchainIdentityResetTransaction completion:^(NSError * _Nullable error) {
//            if (error) {
//                [self raiseIssue:@"Error" message:error.localizedDescription];
//                
//            } else {
//                [self.navigationController popViewControllerAnimated:TRUE];
//            }
//        }];
//    }];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 1) { // About me / Register
            DSContactProfileViewController *controller = [[DSContactProfileViewController alloc] initWithBlockchainIdentity:self.blockchainIdentity];
            controller.delegate = self;
            UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:controller];
            [self presentViewController:navigationController animated:YES completion:nil];
        }
    }
    else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            [self registerBlockchainIdentity:self];
        } else if (indexPath.row == 2) {
            [self reset:self];
        }
        else if (indexPath.row == 3) {
            DSContactsNavigationController *controller = [DSContactsNavigationController controllerWithChainManager:self.chainManager blockchainIdentity:self.blockchainIdentity];
            [self presentViewController:controller animated:YES completion:nil];
        }
        else if (indexPath.row == 4) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            
            __weak typeof(self) weakSelf = self;
            [self.chainManager.DAPIClient ds_registerDashPayContractForUser:self.blockchainIdentity forChain:self.chainManager.chain completion:^(NSError * _Nullable error) {
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
    if ([segue.identifier isEqualToString:@"BlockchainIdentityTopupSegue"]) {
        DSTopupBlockchainIdentityViewController * topupBlockchainIdentityViewController = (DSTopupBlockchainIdentityViewController*)segue.destinationViewController;
        topupBlockchainIdentityViewController.chainManager = self.chainManager;
        topupBlockchainIdentityViewController.blockchainIdentity = self.blockchainIdentity;
    } else if ([segue.identifier isEqualToString:@"BlockchainIdentityTransitionsSegue"]) {
        DSBlockchainIdentityTransitionsViewController * blockchainIdentityTransitionsViewController = (DSBlockchainIdentityTransitionsViewController*)segue.destinationViewController;
        blockchainIdentityTransitionsViewController.chainManager = self.chainManager;
        blockchainIdentityTransitionsViewController.blockchainIdentity = self.blockchainIdentity;
    }
}

#pragma mark - DSContactProfileViewControllerDelegate

- (void)contactProfileViewControllerDidCancel:(DSContactProfileViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)contactProfileViewControllerDidUpdateProfile:(DSContactProfileViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
    
    [self.blockchainIdentity fetchProfile:^(BOOL success) {
        [self updateProfile];
    }];
}

@end
