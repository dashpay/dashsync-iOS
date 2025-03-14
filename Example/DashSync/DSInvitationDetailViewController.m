//
//  Created by Samuel Westrich
//  Copyright © 2564 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSInvitationDetailViewController.h"
#import <SDWebImage/SDWebImage.h>

@interface DSInvitationDetailViewController ()

@property (strong, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (strong, nonatomic) IBOutlet UILabel *aboutMeLabel;
@property (strong, nonatomic) IBOutlet UILabel *indexLabel;
@property (strong, nonatomic) IBOutlet UILabel *keyCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *usernameStatusLabel;
@property (strong, nonatomic) IBOutlet UILabel *uniqueIdLabel;
@property (strong, nonatomic) id identityNameObserver;
@property (strong, nonatomic) id identityRegistrationStatusObserver;
@property (readonly, nonatomic) DSIdentity *identity;

@end

@implementation DSInvitationDetailViewController

- (DSIdentity *)identity {
    return self.invitation.identity;
}

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

    __weak typeof(self) weakSelf = self;

    self.identityNameObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSIdentityDidUpdateUsernameStatusNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          __strong typeof(weakSelf) strongSelf = weakSelf;
                                                          if (!strongSelf) {
                                                              return;
                                                          }
                                                          if ([note.userInfo[DSIdentityKey] isEqual:strongSelf.identity]) {
                                                              [strongSelf reloadRegistrationInfo];
                                                          }
                                                      }];

    self.identityRegistrationStatusObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSIdentityDidUpdateNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          __strong typeof(weakSelf) strongSelf = weakSelf;
                                                          if (!strongSelf) {
                                                              return;
                                                          }
                                                          if ([note.userInfo[DSIdentityKey] isEqual:strongSelf.identity]) {
                                                              if ([note.userInfo[DSIdentityUpdateEvents] containsObject:DSIdentityUpdateEventRegistration]) {
                                                                  [strongSelf reloadRegistrationInfo];
                                                              }
                                                              if ([note.userInfo[DSIdentityUpdateEvents] containsObject:DSIdentityUpdateEventKeyUpdate]) {
                                                                  [strongSelf reloadKeyInfo];
                                                              }
                                                          }
                                                      }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.identityNameObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self.identityRegistrationStatusObserver];
}

- (void)reloadRegistrationInfo {
    DUsernameStatus *username_status = [self.identity statusOfDashpayUsername:self.identity.currentDashpayUsername];

    if (!self.identity.registered) {
        self.aboutMeLabel.text = @"Not registered";
        self.usernameStatusLabel.text = @"";
    } else if (!self.identity.currentDashpayUsername) {
        self.aboutMeLabel.text = @"No Username";
        self.usernameStatusLabel.text = @"";
    } else if (!dash_spv_platform_document_usernames_UsernameStatus_is_confirmed(username_status)) {
        self.aboutMeLabel.text = @"Username Process";
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
        [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:self.identity.matchingDashpayUserInViewContext.avatarPath]];
        self.usernameStatusLabel.text = @"";
    }
    DUsernameStatusDtor(username_status);
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}

- (void)viewController:(UIViewController *)controller didChooseIdentity:(DSIdentity *)identity {
    [self.invitation createInvitationFullLinkFromIdentity:identity
                                               completion:^(BOOL cancelled, NSString *_Nonnull invitationFullLink) {
                                                   NSLog(@"invitation full link %@", invitationFullLink);
                                               }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ChooseIdentityForLinkIdentifier"]) {
        DSIdentityChooserViewController *identityChooserViewController = segue.destinationViewController;
        identityChooserViewController.chain = self.chainManager.chain;
        identityChooserViewController.delegate = self;
    }
}

@end
