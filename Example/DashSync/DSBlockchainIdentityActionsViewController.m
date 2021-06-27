//
//  DSBlockchainIdentityActionsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 8/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSBlockchainIdentityActionsViewController.h"
#import "DSBlockchainIdentityTransitionsViewController.h"
#import "DSTopupBlockchainIdentityViewController.h"

#import "DSBlockchainIdentityKeysViewController.h"
#import "DSContactProfileViewController.h"
#import "DSContactsNavigationController.h"
#import "DSRegisterContractsViewController.h"
#import "DSRegisterTLDViewController.h"
#import <SDWebImage/SDWebImage.h>

@interface DSBlockchainIdentityActionsViewController () <DSContactProfileViewControllerDelegate>
@property (strong, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (strong, nonatomic) IBOutlet UILabel *aboutMeLabel;
@property (strong, nonatomic) IBOutlet UILabel *indexLabel;
@property (strong, nonatomic) IBOutlet UILabel *keyCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *contactCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *usernameStatusLabel;
@property (strong, nonatomic) IBOutlet UILabel *uniqueIdLabel;
@property (strong, nonatomic) IBOutlet UILabel *mostActiveContactSentToLabel;
@property (strong, nonatomic) IBOutlet UILabel *mostActiveContactReceivedFromLabel;
@property (strong, nonatomic) id blockchainIdentityNameObserver;
@property (strong, nonatomic) id blockchainIdentityRegistrationStatusObserver;

@end

@implementation DSBlockchainIdentityActionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadProfileInitial];
    if (self.blockchainIdentity.registered && self.blockchainIdentity.currentDashpayUsername && [self.blockchainIdentity statusOfDashpayUsername:self.blockchainIdentity.currentDashpayUsername] == DSBlockchainIdentityUsernameStatus_Confirmed) {
        [self.blockchainIdentity fetchProfileWithCompletion:^(BOOL success, NSError *error) {
            if (success) {
                [self updateProfile];
            }
        }];
    }

    [self reloadKeyInfo];
    [self reloadContactInfo];

    __weak typeof(self) weakSelf = self;

    self.blockchainIdentityNameObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSBlockchainIdentityDidUpdateUsernameStatusNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          __strong typeof(weakSelf) strongSelf = weakSelf;
                                                          if (!strongSelf) {
                                                              return;
                                                          }
                                                          if ([note.userInfo[DSBlockchainIdentityKey] isEqual:strongSelf.blockchainIdentity]) {
                                                              [strongSelf reloadRegistrationInfo];
                                                          }
                                                      }];

    self.blockchainIdentityRegistrationStatusObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSBlockchainIdentityDidUpdateNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.blockchainIdentityNameObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self.blockchainIdentityRegistrationStatusObserver];
}

- (void)reloadRegistrationInfo {
    if (!self.blockchainIdentity.registered) {
        self.aboutMeLabel.text = @"Register Identity";
        self.usernameStatusLabel.text = @"";
    } else if (!self.blockchainIdentity.currentDashpayUsername) {
        self.aboutMeLabel.text = @"Set Username";
        self.usernameStatusLabel.text = @"";
    } else if ([self.blockchainIdentity statusOfDashpayUsername:self.blockchainIdentity.currentDashpayUsername] != DSBlockchainIdentityUsernameStatus_Confirmed) {
        self.aboutMeLabel.text = @"Register Username";
        switch ([self.blockchainIdentity statusOfDashpayUsername:self.blockchainIdentity.currentDashpayUsername]) {
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
    } else if (!self.blockchainIdentity.matchingDashpayUserInViewContext.remoteProfileDocumentRevision) {
        self.aboutMeLabel.text = @"Fetching";
        [self.avatarImageView sd_setImageWithURL:nil];
        self.usernameStatusLabel.text = @"";
    } else {
        self.aboutMeLabel.text = self.blockchainIdentity.matchingDashpayUserInViewContext.publicMessage;
        [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:self.blockchainIdentity.matchingDashpayUserInViewContext.avatarPath]];
        self.usernameStatusLabel.text = @"";
    }
}

- (void)loadProfileInitial {
    self.title = self.blockchainIdentity.currentDashpayUsername;
    [self reloadRegistrationInfo];

    self.indexLabel.text = [NSString stringWithFormat:@"%d", self.blockchainIdentity.index];

    self.uniqueIdLabel.text = self.blockchainIdentity.uniqueIdString;
}

- (void)updateProfile {
    self.title = self.blockchainIdentity.currentDashpayUsername;
    if (!self.blockchainIdentity.matchingDashpayUserInViewContext.remoteProfileDocumentRevision) {
        self.aboutMeLabel.text = @"Register Profile";
        [self.avatarImageView sd_setImageWithURL:nil];
    } else {
        if (!self.blockchainIdentity.matchingDashpayUserInViewContext.publicMessage) {
            self.aboutMeLabel.text = @"No message set!";
            self.aboutMeLabel.textColor = [UIColor grayColor];
        } else {
            self.aboutMeLabel.text = self.blockchainIdentity.matchingDashpayUserInViewContext.publicMessage;
            self.aboutMeLabel.textColor = [UIColor darkTextColor];
        }
        [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:self.blockchainIdentity.matchingDashpayUserInViewContext.avatarPath]];
    }
}

- (void)reloadKeyInfo {
    self.keyCountLabel.text = [NSString stringWithFormat:@"%u/%u", self.blockchainIdentity.activeKeyCount, self.blockchainIdentity.totalKeyCount];
}

- (void)reloadContactInfo {
    DSDashpayUserEntity *dashpayUser = [self.blockchainIdentity matchingDashpayUserInViewContext];
    DSDashpayUserEntity *activeSentToFriend = [[dashpayUser mostActiveFriends:DSDashpayUserEntityFriendActivityType_OutgoingTransactions count:1 ascending:NO] firstObject];
    DSDashpayUserEntity *activeReceivedFromFriend = [[dashpayUser mostActiveFriends:DSDashpayUserEntityFriendActivityType_IncomingTransactions count:1 ascending:NO] firstObject];
    self.mostActiveContactSentToLabel.text = activeSentToFriend ? [NSString stringWithFormat:@"%@", activeSentToFriend.username] : @"No Txs on Contacts";
    self.mostActiveContactReceivedFromLabel.text = activeReceivedFromFriend ? [NSString stringWithFormat:@"%@", activeReceivedFromFriend.username] : @"No Txs on Contacts";
    self.contactCountLabel.text = [NSString stringWithFormat:@"%lu/%lu/%lu", (unsigned long)dashpayUser.friends.count, (unsigned long)dashpayUser.outgoingRequests.count - dashpayUser.friends.count, (unsigned long)dashpayUser.incomingRequests.count - dashpayUser.friends.count];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)raiseIssue:(NSString *)issue message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:issue message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ok"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *_Nonnull action){

                                            }]];
    [self presentViewController:alert
                       animated:TRUE
                     completion:^{

                     }];
}

- (IBAction)registerBlockchainIdentity:(id)sender {
    if (self.blockchainIdentity.isRegistered) return;
    [self.blockchainIdentity createFundingPrivateKeyWithPrompt:@""
                                                    completion:^(BOOL success, BOOL cancelled) {
                                                        [self.blockchainIdentity createAndPublishRegistrationTransitionWithCompletion:^(NSDictionary *_Nullable successInfo, NSError *_Nullable error) {
                                                            if (error) {
                                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                                    [self raiseIssue:@"Unable to register." message:error.localizedDescription];
                                                                });
                                                            }
                                                        }];
                                                    }];
}

- (IBAction)reset:(id)sender {
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 2) { // About me / Register
            if (!self.blockchainIdentity.registered) {
                [self registerBlockchainIdentity:self];
            } else if (self.blockchainIdentity.currentDashpayUsername && [self.blockchainIdentity statusOfDashpayUsername:self.blockchainIdentity.currentDashpayUsername] != DSBlockchainIdentityUsernameStatus_Confirmed) {
                [self.blockchainIdentity registerUsernamesWithCompletion:^(BOOL success, NSError *_Nonnull error){

                }];
            } else {
                [self performSegueWithIdentifier:@"CreateOrEditProfileSegue" sender:self];
            }
        } else if (indexPath.row == 5) { //Keys
        }
    } else if (indexPath.section == 1) { //Dashpay
        if (indexPath.row == 0) {        //Contacts
            DSContactsNavigationController *controller = [DSContactsNavigationController controllerWithChainManager:self.chainManager blockchainIdentity:self.blockchainIdentity];
            [self presentViewController:controller animated:YES completion:nil];
        }
    } else if (indexPath.section == 2) { //Contracts
        if (indexPath.row == 0) {        //Register
            [self performSegueWithIdentifier:@"RegisterContractsSegue" sender:self];
        } else if (indexPath.row == 1) { //View
        }
    } else if (indexPath.section == 3) { //Actions
        if (indexPath.row == 0) {
        } else if (indexPath.row == 2) {
        } else if (indexPath.row == 3) {
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"BlockchainIdentityTopupSegue"]) {
        DSTopupBlockchainIdentityViewController *topupBlockchainIdentityViewController = (DSTopupBlockchainIdentityViewController *)segue.destinationViewController;
        topupBlockchainIdentityViewController.chainManager = self.chainManager;
        topupBlockchainIdentityViewController.blockchainIdentity = self.blockchainIdentity;
    } else if ([segue.identifier isEqualToString:@"BlockchainIdentityTransitionsSegue"]) {
        DSBlockchainIdentityTransitionsViewController *blockchainIdentityTransitionsViewController = (DSBlockchainIdentityTransitionsViewController *)segue.destinationViewController;
        blockchainIdentityTransitionsViewController.chainManager = self.chainManager;
        blockchainIdentityTransitionsViewController.blockchainIdentity = self.blockchainIdentity;
    } else if ([segue.identifier isEqualToString:@"RegisterContractsSegue"]) {
        DSRegisterContractsViewController *controller = segue.destinationViewController;
        controller.blockchainIdentity = self.blockchainIdentity;
    } else if ([segue.identifier isEqualToString:@"BlockchainIdentityKeysSegue"]) {
        DSBlockchainIdentityKeysViewController *controller = segue.destinationViewController;
        controller.blockchainIdentity = self.blockchainIdentity;
    } else if ([segue.identifier isEqualToString:@"BlockchainIdentityRegisterTLDSegue"]) {
        DSRegisterTLDViewController *controller = segue.destinationViewController;
        controller.blockchainIdentity = self.blockchainIdentity;
    } else if ([segue.identifier isEqualToString:@"CreateOrEditProfileSegue"]) {
        UINavigationController *navigationController = segue.destinationViewController;
        DSContactProfileViewController *controller = (DSContactProfileViewController *)navigationController.topViewController;
        controller.blockchainIdentity = self.blockchainIdentity;
        controller.delegate = self;
    }
}

#pragma mark - DSContactProfileViewControllerDelegate

- (void)contactProfileViewControllerDidCancel:(DSContactProfileViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)contactProfileViewControllerDidUpdateProfile:(DSContactProfileViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];

    [self.blockchainIdentity fetchProfileWithCompletion:^(BOOL success, NSError *error) {
        [self updateProfile];
    }];
}

@end
