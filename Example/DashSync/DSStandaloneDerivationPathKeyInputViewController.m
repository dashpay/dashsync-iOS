//
//  DSStandaloneDerivationPathKeyInputViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/10/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSStandaloneDerivationPathKeyInputViewController.h"
#import <DashSync/DashSync.h>

@interface DSStandaloneDerivationPathKeyInputViewController ()

@property (strong, nonatomic) IBOutlet UITextView *inputKeyTextView;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *saveButton;

@end

@implementation DSStandaloneDerivationPathKeyInputViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.saveButton.enabled = FALSE;
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)textViewDidChange:(UITextView *)textView {
    if ([textView.text isValidDashPrivateKeyOnChain:self.chain] || [textView.text isValidDashExtendedPublicKeyOnChain:self.chain]) {
        self.saveButton.enabled = TRUE;
    } else {
        self.saveButton.enabled = FALSE;
    }
}

- (IBAction)createDerivationPath:(id)sender {
    if ([self.inputKeyTextView.text isValidDashExtendedPublicKeyOnChain:self.chain]) {
        DSDerivationPath * derivationPath = [DSDerivationPath derivationPathWithSerializedExtendedPublicKey:self.inputKeyTextView.text onChain:self.chain];
        [self.chain registerStandaloneDerivationPath:derivationPath];
        [self.navigationController popViewControllerAnimated:TRUE];
    } else if ([self.inputKeyTextView.text isValidDashPrivateKeyOnChain:self.chain]) {
        DSDerivationPath * derivationPath = [DSDerivationPath derivationPathWithSerializedExtendedPublicKey:self.inputKeyTextView.text onChain:self.chain];
        [self.chain registerStandaloneDerivationPath:derivationPath];
        [self.navigationController popViewControllerAnimated:TRUE];
    }
}

@end
