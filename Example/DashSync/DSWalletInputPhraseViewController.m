//
//  DSWalletInputPhraseViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 5/18/18.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSWalletInputPhraseViewController.h"
#import <DashSync/DashSync.h>

@interface DSWalletInputPhraseViewController ()
@property (strong, nonatomic) IBOutlet UITextView *inputSeedPhraseTextView;
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
    self.inputSeedPhraseTextView.text = [DSWallet generateRandomSeed];
    self.saveButton.enabled = TRUE;
}


-(void)textViewDidChange:(UITextView *)textView {
    if ([[DSBIP39Mnemonic sharedInstance] phraseIsValid:textView.text]) {
        self.saveButton.enabled = TRUE;
    } else {
        self.saveButton.enabled = FALSE;
    }
}

- (IBAction)createWallet:(id)sender {
    if ([[DSBIP39Mnemonic sharedInstance] phraseIsValid:self.inputSeedPhraseTextView.text]) {
        DSWallet * wallet = [DSWallet standardWalletWithSeedPhrase:self.inputSeedPhraseTextView.text forChain:self.chain storeSeedPhrase:TRUE];
        [self.chain addWallet:wallet];
        [self.navigationController popViewControllerAnimated:TRUE];
    }
}

@end

