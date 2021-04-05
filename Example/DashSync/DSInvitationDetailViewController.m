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
@property (strong, nonatomic) id blockchainIdentityNameObserver;
@property (strong, nonatomic) id blockchainIdentityRegistrationStatusObserver;
@property (readonly, nonatomic) DSBlockchainIdentity *blockchainIdentity;

@end

@implementation DSInvitationDetailViewController

- (DSBlockchainIdentity *)blockchainIdentity {
    return self.invitation.identity;
}

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
        self.aboutMeLabel.text = @"Not registered";
        self.usernameStatusLabel.text = @"";
    } else if (!self.blockchainIdentity.currentDashpayUsername) {
        self.aboutMeLabel.text = @"No Username";
        self.usernameStatusLabel.text = @"";
    } else if ([self.blockchainIdentity statusOfDashpayUsername:self.blockchainIdentity.currentDashpayUsername] != DSBlockchainIdentityUsernameStatus_Confirmed) {
        self.aboutMeLabel.text = @"Username Process";
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

- (void)viewController:(UIViewController *)controller didChooseIdentity:(DSBlockchainIdentity *)identity {
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
