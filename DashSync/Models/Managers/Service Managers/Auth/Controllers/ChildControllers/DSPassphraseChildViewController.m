//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "DSPassphraseChildViewController.h"

#import "DSAuthenticationManager+Private.h"
#import "DSPassphraseTextView.h"
#import "DashSync.h"
#import "UIColor+DSStyle.h"
#import "UIView+DSAnimations.h"

NS_ASSUME_NONNULL_BEGIN

static CGFloat const SPACING = 16.0;
static CGFloat const TEXTVIEW_HEIGHT = 120.0;

@interface DSPassphraseChildViewController () <UITextViewDelegate>

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) DSPassphraseTextView *textView;
@property (null_resettable, nonatomic, strong) UINotificationFeedbackGenerator *feedbackGenerator;

@end

@implementation DSPassphraseChildViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor clearColor];

    [self setupView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // `becomeFirstResponder` will be called after `viewDidLayoutSubviews` but before `viewDidAppear:`
    // Assigning first responder in `viewWillAppear:` is too early and in `viewDidAppear:` is too late
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.textView becomeFirstResponder];
    });
}

- (void)verifySeedPharse {
    UITextView *textView = self.textView;
    DSBIP39Mnemonic *bip39Mnemonic = [DSBIP39Mnemonic sharedInstance];
    NSString *phrase = [bip39Mnemonic cleanupPhrase:textView.text];

    if (![phrase isEqual:textView.text]) {
        textView.text = phrase;
    }

    DSChain *chain = [[DSChainsManager sharedInstance] mainnetManager].chain;
    
    if (![chain hasAWallet]) {
        chain = [[DSChainsManager sharedInstance] testnetManager].chain;
        if (![chain hasAWallet]) {
            for (DSChain * devnetChain in [[DSChainsManager sharedInstance] devnetChains]) {
                if ([devnetChain hasAWallet]) {
                    chain = devnetChain;
                    break;
                }
            }
            if (![chain hasAWallet]) {
                [self.feedbackGenerator notificationOccurred:UINotificationFeedbackTypeError];
                [self.feedbackGenerator prepare];
                return;
            }
        }
    }

    NSData *oldData = nil;
    if (chain.wallets.count) {
        DSWallet *wallet = [chain.wallets objectAtIndex:0];
        oldData = [[wallet accountWithNumber:0] bip44DerivationPath].extendedPublicKey;
    }

    if (!oldData) {
        oldData = getKeychainData(EXTENDED_0_PUBKEY_KEY_BIP44_V1, nil);
    }

    if (!oldData) {
        oldData = getKeychainData(EXTENDED_0_PUBKEY_KEY_BIP44_V0, nil);
    }

    NSData *seed = [bip39Mnemonic deriveKeyFromPhrase:[bip39Mnemonic normalizePhrase:phrase] withPassphrase:nil];
    DSWallet *transientWallet = [DSWallet standardWalletWithSeedPhrase:phrase setCreationDate:[NSDate timeIntervalSince1970] forChain:chain storeSeedPhrase:NO isTransient:YES];
    DSAccount *transientAccount = [transientWallet accountWithNumber:0];
    DSDerivationPath *transientDerivationPath = [transientAccount bip44DerivationPath];
    NSData *transientExtendedPublicKey = transientDerivationPath.extendedPublicKey;

    if (transientExtendedPublicKey &&
        ![transientExtendedPublicKey isEqual:oldData] &&
        ![[transientDerivationPath deprecatedIncorrectExtendedPublicKeyFromSeed:seed] isEqual:oldData]) {
        [textView ds_shakeView];

        [self.feedbackGenerator notificationOccurred:UINotificationFeedbackTypeError];
        [self.feedbackGenerator prepare];
    }
    else {
        if (oldData) {
            [[DSVersionManager sharedInstance] clearKeychainWalletOldData];
        }
        [[DSAuthenticationManager sharedInstance] removePinForced];

        NSParameterAssert(self.delegate);
        [self.delegate passphraseChildViewControllerDidVerifySeedPhrase:self];
    }
}

#pragma mark - Private

- (void)setupView {
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.numberOfLines = 0;
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textColor = [UIColor ds_labelColorForMode:DSAppearanceMode_Automatic];
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.5;
    titleLabel.text = DSLocalizedString(@"Recovery phrase", nil);
    [self.view addSubview:titleLabel];
    self.titleLabel = titleLabel;

    DSPassphraseTextView *textView = [[DSPassphraseTextView alloc] initWithFrame:CGRectZero textContainer:nil];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.delegate = self;
    [self.view addSubview:textView];
    self.textView = textView;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [textView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor
                                           constant:SPACING],
        [textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [textView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [textView.heightAnchor constraintEqualToConstant:TEXTVIEW_HEIGHT],
    ]];
}

- (UINotificationFeedbackGenerator *)feedbackGenerator {
    if (_feedbackGenerator == nil) {
        _feedbackGenerator = [[UINotificationFeedbackGenerator alloc] init];
        [_feedbackGenerator prepare];
    }

    return _feedbackGenerator;
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView
    shouldChangeTextInRange:(NSRange)range
            replacementText:(NSString *)text {
    if ([text isEqual:@"\n"]) {
        [self verifySeedPharse];
        return NO;
    }
    else {
        return YES;
    }
}

@end

NS_ASSUME_NONNULL_END
