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
#import <SDWebImage/SDWebImage.h>
#import "DSContactProfileViewController.h"
#import "DSRegisterContractsViewController.h"
#import "DSBlockchainIdentityKeysViewController.h"

@interface DSBlockchainIdentityActionsViewController () <DSContactProfileViewControllerDelegate>
@property (strong, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (strong, nonatomic) IBOutlet UILabel *aboutMeLabel;
@property (strong, nonatomic) IBOutlet UILabel *typeLabel;
@property (strong, nonatomic) IBOutlet UILabel *indexLabel;
@property (strong, nonatomic) IBOutlet UILabel *keyCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *usernameStatusLabel;
@property (strong, nonatomic) IBOutlet UILabel *uniqueIdLabel;
@property (strong, nonatomic) id blockchainIdentityNameObserver;
@property (strong, nonatomic) id blockchainIdentityRegistrationStatusObserver;

@end

@implementation DSBlockchainIdentityActionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadProfileInitial];
    if (self.blockchainIdentity.registered && self.blockchainIdentity.currentUsername && [self.blockchainIdentity statusOfUsername:self.blockchainIdentity.currentUsername] == DSBlockchainIdentityUsernameStatus_Confirmed) {
        [self.blockchainIdentity fetchProfile:^(BOOL success) {
            [self updateProfile];
        }];
    }
    
    [self reloadKeyInfo];
    
    __weak typeof(self) weakSelf = self;
    
    self.blockchainIdentityNameObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSBlockchainIdentityDidUpdateUsernameStatusNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           __strong typeof(weakSelf) strongSelf = weakSelf;
                                                           if (!strongSelf) {
                                                               return;
                                                           }
                                                           if ([note.userInfo[DSBlockchainIdentityKey] isEqual:strongSelf.blockchainIdentity]) {
                                                               [strongSelf reloadRegistrationInfo];
                                                           }
                                                       }];
    
    self.blockchainIdentityRegistrationStatusObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSBlockchainIdentityDidUpdateNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           __strong typeof(weakSelf) strongSelf = weakSelf;
                                                           if (!strongSelf) {
                                                               return;
                                                           }
                                                           if ([note.userInfo[DSBlockchainIdentityKey] isEqual:strongSelf.blockchainIdentity]) {
                                                               if ([note.userInfo[DSBlockchainIdentityUpdateEvents] containsObject:DSBlockchainIdentityUpdateEventRegistration]) {
                                                                   [strongSelf reloadRegistrationInfo];
                                                               }
                                                               if ([note.userInfo[DSBlockchainIdentityUpdateEvents] containsObject:DSBlockchainIdentityUpdateEventKeyUpdate]) {
                                                                   [strongSelf reloadKeyInfo];
                                                               }
                                                           }
                                                       }];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.blockchainIdentityNameObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self.blockchainIdentityRegistrationStatusObserver];
}

-(void)reloadRegistrationInfo {
    if (!self.blockchainIdentity.registered) {
        self.aboutMeLabel.text = @"Register Identity";
        self.usernameStatusLabel.text = @"";
    } else if (!self.blockchainIdentity.currentUsername) {
        self.aboutMeLabel.text = @"Set Username";
        self.usernameStatusLabel.text = @"";
    } else if ([self.blockchainIdentity statusOfUsername:self.blockchainIdentity.currentUsername] != DSBlockchainIdentityUsernameStatus_Confirmed) {
        self.aboutMeLabel.text = @"Register Username";
        switch ([self.blockchainIdentity statusOfUsername:self.blockchainIdentity.currentUsername]) {
            case DSBlockchainIdentityUsernameStatus_Initial:
                self.usernameStatusLabel.text = @"Initial";
                break;
            case DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending:
                self.usernameStatusLabel.text = @"Preorder Registration Pending";
                break;
            case DSBlockchainIdentityUsernameStatus_Preordered:
                self.usernameStatusLabel.text = @"Preordered";
                break;
            case DSBlockchainIdentityUsernameStatus_RegistrationPending:
                self.usernameStatusLabel.text = @"Registration Pending";
                break;
            default:
                self.usernameStatusLabel.text = @"";
                break;
        }
        
    } else if (!self.blockchainIdentity.ownContact) {
        self.aboutMeLabel.text = @"Fetching";
        [self.avatarImageView sd_setImageWithURL:nil];
        self.usernameStatusLabel.text = @"";
    }
    else {
        self.aboutMeLabel.text = self.blockchainIdentity.ownContact.publicMessage;
        [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:self.blockchainIdentity.ownContact.avatarPath]];
    }
}

-(void)loadProfileInitial {
    self.title = self.blockchainIdentity.currentUsername;
    [self reloadRegistrationInfo];
    
    self.typeLabel.text = self.blockchainIdentity.localizedBlockchainIdentityTypeString;
    self.indexLabel.text = [NSString stringWithFormat:@"%d",self.blockchainIdentity.index];
    
    self.uniqueIdLabel.text = self.blockchainIdentity.uniqueIdString;
}

-(void)updateProfile {
    self.title = self.blockchainIdentity.currentUsername;
    if (!self.blockchainIdentity.ownContact.isRegistered) {
        self.aboutMeLabel.text = @"Register Profile";
        [self.avatarImageView sd_setImageWithURL:nil];
    }
    else {
        self.aboutMeLabel.text = self.blockchainIdentity.ownContact.publicMessage;
        [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:self.blockchainIdentity.ownContact.avatarPath]];
    }
}

-(void)reloadKeyInfo {
    self.keyCountLabel.text = [NSString stringWithFormat:@"%u/%u",self.blockchainIdentity.activeKeyCount, self.blockchainIdentity.totalKeyCount];
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
    if (self.blockchainIdentity.type == DSBlockchainIdentityType_Unknown) {
        [self raiseIssue:@"Unknown Registration Type" message:@"Please select the type of identity you wish to register"];
        return;
    }
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
        if (indexPath.row == 1 && !self.blockchainIdentity.registered) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Identity Type"
                                                                                     message:nil
                                                                              preferredStyle:UIAlertControllerStyleActionSheet];
            
            [alertController addAction:[UIAlertAction actionWithTitle:@"User"
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction *_Nonnull action) {
                self.typeLabel.text = @"User";
                self.blockchainIdentity.type = DSBlockchainIdentityType_User;
                                                                  }]];
            
            [alertController addAction:[UIAlertAction actionWithTitle:@"Application"
              style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *_Nonnull action) {
                self.typeLabel.text = @"Application";
                self.blockchainIdentity.type = DSBlockchainIdentityType_Application;
            }]];
            
            [self presentViewController:alertController animated:YES completion:nil];
        } else if (indexPath.row == 3) { // About me / Register
            if (!self.blockchainIdentity.registered) {
                [self registerBlockchainIdentity:self];
            } else if (self.blockchainIdentity.currentUsername && [self.blockchainIdentity statusOfUsername:self.blockchainIdentity.currentUsername] != DSBlockchainIdentityUsernameStatus_Confirmed) {
                [self.blockchainIdentity registerUsernames];
            } else {
                DSContactProfileViewController *controller = [[DSContactProfileViewController alloc] initWithBlockchainIdentity:self.blockchainIdentity];
                controller.delegate = self;
                UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:controller];
                [self presentViewController:navigationController animated:YES completion:nil];
            }
        } else if (indexPath.row == 5) { //Keys
            
        }
    }
    else if (indexPath.section == 1) { //Dashpay
        if (indexPath.row == 0) { //Contacts
            DSContactsNavigationController *controller = [DSContactsNavigationController controllerWithChainManager:self.chainManager blockchainIdentity:self.blockchainIdentity];
            [self presentViewController:controller animated:YES completion:nil];
        }
    } else if (indexPath.section == 2) { //Contracts
        if (indexPath.row == 0) { //Register
            [self performSegueWithIdentifier:@"RegisterContractsSegue" sender:self];
        } else if (indexPath.row == 1) { //View
            
        }
    } else if (indexPath.section == 3) { //Actions
        if (indexPath.row == 0) {

        } else if (indexPath.row == 2) {
        }
        else if (indexPath.row == 3) {
            
        } else if (indexPath.row == 4) {
//            [tableView deselectRowAtIndexPath:indexPath animated:YES];
//
//            __weak typeof(self) weakSelf = self;
//            [self.chainManager.DAPIClient ds_registerDashPayContractForUser:self.blockchainIdentity forChain:self.chainManager.chain completion:^(NSError * _Nullable error) {
//                __strong typeof(weakSelf) strongSelf = weakSelf;
//                if (!strongSelf) {
//                    return;
//                }
//
//                if (error) {
//                    [strongSelf raiseIssue:@"Error" message:error.localizedDescription];
//                }
//            }];
        }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
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
    } else if ([segue.identifier isEqualToString:@"RegisterContractsSegue"]) {
        DSRegisterContractsViewController * controller = segue.destinationViewController;
        controller.blockchainIdentity = self.blockchainIdentity;
    } else if ([segue.identifier isEqualToString:@"BlockchainIdentityKeysSegue"]) {
        DSBlockchainIdentityKeysViewController * controller = segue.destinationViewController;
        controller.blockchainIdentity = self.blockchainIdentity;
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
