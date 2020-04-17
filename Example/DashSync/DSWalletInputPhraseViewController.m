//
//  DSWalletInputPhraseViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 5/18/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSWalletInputPhraseViewController.h"
#import <DashSync/DashSync.h>

@interface DSWalletInputPhraseViewController ()
@property (strong, nonatomic) IBOutlet UITextView *inputSeedPhraseTextView;
@property (strong, nonatomic) NSString * randomPassphrase;
- (IBAction)generateRandomPassphrase:(id)sender;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *saveButton;
- (IBAction)createWallet:(id)sender;

@end

@implementation DSWalletInputPhraseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.saveButton.enabled = FALSE;
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

- (IBAction)generateRandomPassphrase:(id)sender {
    self.randomPassphrase = [DSWallet generateRandomSeedPhrase];
    self.inputSeedPhraseTextView.text = self.randomPassphrase;
    self.saveButton.enabled = TRUE;
}


-(void)textViewDidChange:(UITextView *)textView {
    if ([[DSBIP39Mnemonic sharedInstance] phraseIsValid:textView.text] || [textView.text isValidDashExtendedPublicKeyOnChain:self.chain]) {
        self.saveButton.enabled = TRUE;
    } else {
        self.saveButton.enabled = FALSE;
    }
}

- (IBAction)createWallet:(id)sender {
    if ([[DSBIP39Mnemonic sharedInstance] phraseIsValid:self.inputSeedPhraseTextView.text]) {
        NSTimeInterval creationDate = [self.inputSeedPhraseTextView.text isEqualToString:self.randomPassphrase]?[NSDate timeIntervalSince1970]:0;
        DSWallet * wallet = [DSWallet standardWalletWithSeedPhrase:self.inputSeedPhraseTextView.text setCreationDate:creationDate forChain:self.chain storeSeedPhrase:YES isTransient:NO];
        [self.chain registerWallet:wallet];
        [self.navigationController popViewControllerAnimated:TRUE];
    } else if ([self.inputSeedPhraseTextView.text isValidDashExtendedPublicKeyOnChain:self.chain]) {
        DSDerivationPath * derivationPath = [DSDerivationPath derivationPathWithSerializedExtendedPublicKey:self.inputSeedPhraseTextView.text onChain:self.chain];
        [self.chain registerStandaloneDerivationPath:derivationPath];
        [self.navigationController popViewControllerAnimated:TRUE];
    }
}

@end

