//
//  DSClaimMasternodeViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/15/18.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSClaimMasternodeViewController.h"

@interface DSClaimMasternodeViewController ()
@property (strong, nonatomic) IBOutlet UITextView *inputTextView;
- (IBAction)openQRCodeReader:(id)sender;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *saveButton;
- (IBAction)save:(id)sender;

@end

@implementation DSClaimMasternodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.saveButton.enabled = FALSE;
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)textViewDidChange:(UITextView *)textView {
    if ([textView.text isValidDashPrivateKeyOnChain:self.chain]) {
        self.saveButton.enabled = TRUE;
    } else {
        self.saveButton.enabled = FALSE;
    }
}

- (IBAction)save:(id)sender {
    if ([self.inputTextView.text isValidDashPrivateKeyOnChain:self.chain]) {
        
        [self.chain registerVotingKey:[NSData data] forMasternodeBroadcast:self.masternode];
        [self.navigationController popViewControllerAnimated:TRUE];
    }
}

- (IBAction)openQRCodeReader:(id)sender {
}

@end
