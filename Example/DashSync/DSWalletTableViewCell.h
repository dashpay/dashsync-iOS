//
//  DSWalletTableViewCell.h
//  DashSync_Example
//
//  Created by Sam Westrich on 4/20/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol DSWalletTableViewCellDelegate;

@interface DSWalletTableViewCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UILabel *passphraseLabel;
@property (strong, nonatomic) IBOutlet UILabel *xPublicKeyLabel;
@property (strong, nonatomic) IBOutlet UIButton *showPassphraseButton;
@property (weak) id<DSWalletTableViewCellDelegate> actionDelegate;
- (IBAction)showPassphrase:(id)sender;

@end

@protocol DSWalletTableViewCellDelegate
- (void)walletTableViewCellDidRequestAuthentication:(DSWalletTableViewCell *)cell;

@end
