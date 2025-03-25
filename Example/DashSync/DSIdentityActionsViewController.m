//
//  DSIdentityActionsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 8/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSIdentityActionsViewController.h"
#import "DSIdentityTransitionsViewController.h"
#import "DSTopupIdentityViewController.h"

#import "DSIdentityKeysViewController.h"
#import "DSContactProfileViewController.h"
#import "DSContactsNavigationController.h"
#import "DSRegisterContractsViewController.h"
#import "DSRegisterTLDViewController.h"
#import <SDWebImage/SDWebImage.h>

@interface DSIdentityActionsViewController () <DSContactProfileViewControllerDelegate>
@property (strong, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (strong, nonatomic) IBOutlet UILabel *aboutMeLabel;
@property (strong, nonatomic) IBOutlet UILabel *indexLabel;
@property (strong, nonatomic) IBOutlet UILabel *keyCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *contactCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *usernameStatusLabel;
@property (strong, nonatomic) IBOutlet UILabel *uniqueIdLabel;
@property (strong, nonatomic) IBOutlet UILabel *mostActiveContactSentToLabel;
@property (strong, nonatomic) IBOutlet UILabel *mostActiveContactReceivedFromLabel;
@property (strong, nonatomic) id identityNameObserver;
@property (strong, nonatomic) id identityRegistrationStatusObserver;

@end

@implementation DSIdentityActionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadProfileInitial];
    DUsernameStatus *username_status = [self.identity statusOfDashpayUsername:self.identity.currentDashpayUsername];

    if (self.identity.registered && self.identity.currentDashpayUsername && dash_spv_platform_document_usernames_UsernameStatus_is_confirmed(username_status)) {
        [self.identity fetchProfileWithCompletion:^(BOOL success, NSError *error) {
            if (success) {
                [self updateProfile];
            }
        }];
    }
    DUsernameStatusDtor(username_status);

    [self reloadKeyInfo];
    [self reloadContactInfo];

    __weak typeof(self) weakSelf = self;

    self.identityNameObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSIdentityDidUpdateUsernameStatusNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && [note.userInfo[DSIdentityKey] isEqual:strongSelf.identity])
                [strongSelf reloadRegistrationInfo];
        }];

    self.identityRegistrationStatusObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSIdentityDidUpdateNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && [note.userInfo[DSIdentityKey] isEqual:strongSelf.identity]) {
                if ([note.userInfo[DSIdentityUpdateEvents] containsObject:DSIdentityUpdateEventRegistration])
                    [strongSelf reloadRegistrationInfo];
                if ([note.userInfo[DSIdentityUpdateEvents] containsObject:DSIdentityUpdateEventKeyUpdate])
                    [strongSelf reloadKeyInfo];
            }
        }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadKeyInfo];
    [self reloadContactInfo];
    [self reloadRegistrationInfo];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.identityNameObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self.identityRegistrationStatusObserver];
}

- (void)reloadRegistrationInfo {
    DUsernameStatus *username_status = [self.identity statusOfDashpayUsername:self.identity.currentDashpayUsername];
    if (!self.identity.registered) {
        self.aboutMeLabel.text = @"Register Identity";
        self.usernameStatusLabel.text = @"";
    } else if (!self.identity.currentDashpayUsername) {
        self.aboutMeLabel.text = @"Set Username";
        self.usernameStatusLabel.text = @"";
    } else if (!dash_spv_platform_document_usernames_UsernameStatus_is_confirmed(username_status)) {
        self.aboutMeLabel.text = @"Register Username";
        switch (DUsernameStatusIndex(username_status)) {
            case dash_spv_platform_document_usernames_UsernameStatus_Initial:
                self.usernameStatusLabel.text = @"Initial";
                break;
            case dash_spv_platform_document_usernames_UsernameStatus_PreorderRegistrationPending:
                self.usernameStatusLabel.text = @"Preorder Registration Pending";
                break;
            case dash_spv_platform_document_usernames_UsernameStatus_Preordered:
                self.usernameStatusLabel.text = @"Preordered";
                break;
            case dash_spv_platform_document_usernames_UsernameStatus_RegistrationPending:
                self.usernameStatusLabel.text = @"Registration Pending";
                break;
            case dash_spv_platform_document_usernames_UsernameStatus_VotingPeriod:
                self.usernameStatusLabel.text = @"Voting Period";
                break;
            case dash_spv_platform_document_usernames_UsernameStatus_Locked:
                self.usernameStatusLabel.text = @"Locked";
                break;
            default:
                self.usernameStatusLabel.text = @"";
                break;
        }
    } else if (!self.identity.matchingDashpayUserInViewContext.remoteProfileDocumentRevision) {
        self.aboutMeLabel.text = @"Fetching";
        [self.avatarImageView sd_setImageWithURL:nil];
        self.usernameStatusLabel.text = @"";
    } else {
        self.aboutMeLabel.text = self.identity.matchingDashpayUserInViewContext.publicMessage;
        NSLog(@"avatarPath: %@", self.identity.matchingDashpayUserInViewContext.avatarPath);
        [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:self.identity.matchingDashpayUserInViewContext.avatarPath]];
        self.usernameStatusLabel.text = @"";
    }
}

- (void)loadProfileInitial {
    self.title = self.identity.currentDashpayUsername;
    [self reloadRegistrationInfo];
    self.indexLabel.text = [NSString stringWithFormat:@"%d", self.identity.index];
    self.uniqueIdLabel.text = self.identity.uniqueIdString;
}

- (void)updateProfile {
    self.title = self.identity.currentDashpayUsername;
    if (!self.identity.matchingDashpayUserInViewContext.remoteProfileDocumentRevision) {
        self.aboutMeLabel.text = @"Register Profile";
        [self.avatarImageView sd_setImageWithURL:nil];
    } else {
        if (!self.identity.matchingDashpayUserInViewContext.publicMessage) {
            self.aboutMeLabel.text = @"No message set!";
            self.aboutMeLabel.textColor = [UIColor grayColor];
        } else {
            self.aboutMeLabel.text = self.identity.matchingDashpayUserInViewContext.publicMessage;
            self.aboutMeLabel.textColor = [UIColor darkTextColor];
        }
        [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:self.identity.matchingDashpayUserInViewContext.avatarPath]];
    }
}

- (void)reloadKeyInfo {
    self.keyCountLabel.text = [NSString stringWithFormat:@"%lu/%lu", self.identity.activeKeyCount, self.identity.totalKeyCount];
}

- (void)reloadContactInfo {
    DSDashpayUserEntity *dashpayUser = [self.identity matchingDashpayUserInViewContext];
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

- (IBAction)registerIdentity:(id)sender {
    if (self.identity.isRegistered) return;
    [self.identity createFundingPrivateKeyWithPrompt:@""
                                          completion:^(BOOL success, BOOL cancelled) {
        [self.identity createAndPublishRegistrationTransitionWithCompletion:^(BOOL success, NSError *_Nullable error) {
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self raiseIssue:@"Unable to register." message:error.localizedDescription];
                });
            } else if (success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self raiseIssue:@"Identity registered" message:error.localizedDescription];
                });
            }
        }];
    }];
}

- (IBAction)reset:(id)sender {
    //    [self.identity resetTransactionUsingNewIndex:self.identity.wallet.unusedIdentityIndex completion:^(DSIdentityUpdateTransition *identityResetTransaction) {
    //        [self.chainManager.transactionManager publishTransaction:identityResetTransaction completion:^(NSError * _Nullable error) {
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
    DUsernameStatus *username_status = [self.identity statusOfDashpayUsername:self.identity.currentDashpayUsername];
    if (indexPath.section == 0) {
        if (indexPath.row == 2) { // About me / Register
            if (!self.identity.registered) {
                [self registerIdentity:self];
            } else if (self.identity.currentDashpayUsername && dash_spv_platform_document_usernames_UsernameStatus_is_confirmed(username_status)) {
                [self.identity registerUsernamesWithCompletion:^(BOOL success, NSArray<NSError *> *errors) {

                }];
            } else {
                [self performSegueWithIdentifier:@"CreateOrEditProfileSegue" sender:self];
            }
        } else if (indexPath.row == 5) { //Keys
        }
    } else if (indexPath.section == 1) { //Dashpay
        if (indexPath.row == 0) {        //Contacts
            DSContactsNavigationController *controller = [DSContactsNavigationController controllerWithChainManager:self.chainManager identity:self.identity];
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
            //            [self.chainManager.DAPIClient ds_registerDashPayContractForUser:self.identity forChain:self.chainManager.chain completion:^(NSError * _Nullable error) {
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
    DUsernameStatusDtor(username_status);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"BlockchainIdentityTopupSegue"]) {
        DSTopupIdentityViewController *controller = (DSTopupIdentityViewController *)segue.destinationViewController;
        controller.chainManager = self.chainManager;
        controller.identity = self.identity;
    } else if ([segue.identifier isEqualToString:@"BlockchainIdentityTransitionsSegue"]) {
        DSIdentityTransitionsViewController *controller = (DSIdentityTransitionsViewController *)segue.destinationViewController;
        controller.chainManager = self.chainManager;
        controller.identity = self.identity;
    } else if ([segue.identifier isEqualToString:@"RegisterContractsSegue"]) {
        DSRegisterContractsViewController *controller = segue.destinationViewController;
        controller.identity = self.identity;
    } else if ([segue.identifier isEqualToString:@"BlockchainIdentityKeysSegue"]) {
        DSIdentityKeysViewController *controller = segue.destinationViewController;
        controller.identity = self.identity;
    } else if ([segue.identifier isEqualToString:@"BlockchainIdentityRegisterTLDSegue"]) {
        DSRegisterTLDViewController *controller = segue.destinationViewController;
        controller.identity = self.identity;
    } else if ([segue.identifier isEqualToString:@"CreateOrEditProfileSegue"]) {
        UINavigationController *navigationController = segue.destinationViewController;
        DSContactProfileViewController *controller = (DSContactProfileViewController *)navigationController.topViewController;
        controller.identity = self.identity;
        controller.delegate = self;
    }
}

#pragma mark - DSContactProfileViewControllerDelegate

- (void)contactProfileViewControllerDidCancel:(DSContactProfileViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)contactProfileViewControllerDidUpdateProfile:(DSContactProfileViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];

    [self.identity fetchProfileWithCompletion:^(BOOL success, NSError *error) {
        [self updateProfile];
    }];
}

@end
