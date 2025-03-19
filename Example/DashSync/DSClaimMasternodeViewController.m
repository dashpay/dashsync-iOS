//
//  DSClaimMasternodeViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/15/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
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
//        UInt160 publicKeyHash = [DSKeyManager ecdsaKeyPublicKeyHashFromSecret:self.inputTextView.text forChainType:self.chain.chainType];
        NSString *seckeyStr = self.inputTextView.text;
        
        DMaybeECDSAKey *result =  DMaybeECDSAKeyWithPrivateKey(DChar(seckeyStr), self.chain.chainType);
        BOOL valid = NO;
        if (result->ok) {
            u160 *pub_key_hash = DECDSAKeyPublicKeyHash(result->ok);
            dashcore_hash_types_PubkeyHash *key_id_voting = self.masternode->masternode_list_entry->key_id_voting;
            u160 *key_id = dashcore_hash_types_PubkeyHash_inner(key_id_voting);
            UInt160 pubKeyHash = u160_cast(pub_key_hash);
            UInt160 keyID = u160_cast(key_id);
            valid = uint160_eq(pubKeyHash, keyID);
            u160_dtor(key_id);
        }
        DMaybeECDSAKeyDtor(result);
        if (valid) {
            [self.navigationController popViewControllerAnimated:TRUE];
        } else {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Mismatched Key"
                                                                                     message:@"This private key is valid but does not correspond to this masternode"
                                                                              preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"Ok"
                                                                style:UIAlertActionStyleCancel
                                                              handler:^(UIAlertAction *_Nonnull action) {}]];
            [self presentViewController:alertController
                               animated:TRUE
                             completion:^{}];
        }
    }
}

- (IBAction)openQRCodeReader:(id)sender {
}

@end
