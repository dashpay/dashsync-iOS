//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DSContactProfileViewController;

@protocol DSContactProfileViewControllerDelegate <NSObject>

- (void)contactProfileViewControllerDidCancel:(DSContactProfileViewController *)controller;
- (void)contactProfileViewControllerDidUpdateProfile:(DSContactProfileViewController *)controller;

@end

@interface DSContactProfileViewController : UIViewController

@property (readonly, nonatomic, strong) DSBlockchainIdentity *blockchainIdentity;
@property (nullable, nonatomic, weak) id<DSContactProfileViewControllerDelegate> delegate;

- (instancetype)initWithBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity;

@end

NS_ASSUME_NONNULL_END
