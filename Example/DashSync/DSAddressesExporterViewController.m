//
//  DSAddressesExporterViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/18/18.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSAddressesExporterViewController.h"
#import "BRBubbleView.h"

@interface DSAddressesExporterViewController ()
- (IBAction)export:(id)sender;

@end

@implementation DSAddressesExporterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
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

- (IBAction)export:(id)sender {
    for (int i = 0; i < 60; i++) {
        @autoreleasepool {
            NSArray *addressesArray = [self.derivationPath addressesForExportWithInternalRange:NSMakeRange(i * 50000, 50000) externalCount:NSMakeRange(i * 50000, 50000)];
            NSError *error = nil;
            NSData *data = [NSJSONSerialization dataWithJSONObject:addressesArray options:0 error:&error];

            NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *fileAtPath = [filePath stringByAppendingPathComponent:[NSString stringWithFormat:@"addresses%d.txt", i]];

            [data writeToFile:fileAtPath atomically:FALSE];
        }
    }

    //    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    //    pasteboard.string = string;
    [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"copied", nil)
                                                center:CGPointMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0 - 130.0)] popIn]
                              popOutAfterDelay:2.0]];
}

@end
