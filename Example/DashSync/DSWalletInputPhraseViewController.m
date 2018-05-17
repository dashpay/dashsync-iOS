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
- (IBAction)savePassphrase:(id)sender;

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
    self.inputSeedPhraseTextView.text = [[DSWalletManager sharedInstance] generateRandomSeed];
    self.saveButton.enabled = TRUE;
}

-(IBAction)saveSeedPhrase:(id)sender {
    [[DSWalletManager sharedInstance] setSeedPhrase:self.inputSeedPhraseTextView.text];
}

-(void)textViewDidChange:(UITextView *)textView {
    if ([[DSWalletManager sharedInstance].mnemonic phraseIsValid:textView.text]) {
        self.saveButton.enabled = TRUE;
    } else {
        self.saveButton.enabled = FALSE;
    }
}

- (IBAction)savePassphrase:(id)sender {
    [[DSWalletManager sharedInstance] setSeedPhrase:self.inputSeedPhraseTextView.text];
    [self.navigationController popViewControllerAnimated:TRUE];
}

@end

