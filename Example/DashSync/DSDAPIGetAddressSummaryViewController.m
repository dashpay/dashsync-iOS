//
//  DSDAPIGetAddressSummaryViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 9/13/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSDAPIGetAddressSummaryViewController.h"
#import "BRBubbleView.h"
@interface DSDAPIGetAddressSummaryViewController ()
@property (strong, nonatomic) IBOutlet UITextField *addressTextField;
- (IBAction)checkAddress:(id)sender;

@end

@implementation DSDAPIGetAddressSummaryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)checkAddress:(id)sender {
    NSString * address = self.addressTextField.text;
    if ([address isValidDashAddressOnChain:self.chainManager.chain]) {
        [self.chainManager.DAPIClient getAddressSummary:address success:^(NSDictionary * _Nonnull addressSummary) {
            NSLog(@"%@", addressSummary);
        } failure:^(NSError * _Nonnull error) {
            [self.view addSubview:[[[BRBubbleView viewWithText:[NSString stringWithFormat:@"%@",error.localizedDescription]
                                                        center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
                                   popOutAfterDelay:2.0]];
        }];
    }
}


@end
