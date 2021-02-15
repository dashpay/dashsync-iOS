//
//  DSAddDevnetViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/19/18.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DSChain;

@interface DSAddDevnetViewController : UITableViewController <UITextFieldDelegate>

@property (nonatomic, strong) DSChain *chain;

- (IBAction)save;
- (IBAction)cancel;

@end
