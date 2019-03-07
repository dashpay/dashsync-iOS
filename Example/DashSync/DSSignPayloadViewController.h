//
//  DSSignPayloadViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 3/8/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>


@class DSProviderRegistrationTransaction;

NS_ASSUME_NONNULL_BEGIN

@protocol DSSignPayloadDelegate

-(void)viewController:(UIViewController*)controller didReturnSignature:(NSData*)signature;

@end

@interface DSSignPayloadViewController : UIViewController

@property (nonatomic,weak) id <DSSignPayloadDelegate> delegate;
@property (nonatomic,strong) NSString * collateralAddress;
@property (nonatomic,strong) DSProviderRegistrationTransaction * providerRegistrationTransaction;

@end

NS_ASSUME_NONNULL_END
