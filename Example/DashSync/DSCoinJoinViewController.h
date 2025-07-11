//  
//  Created by Andrei Ashikhmin
//  Copyright © 2023 Dash Core Group. All rights reserved.
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
#import "DSCoinJoinManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSCoinJoinViewController : UIViewController

@property (strong, nonatomic) DSChainManager *chainManager;
@property (strong, nonatomic) IBOutlet UISwitch *coinJoinSwitch;
@property (strong, nonatomic) IBOutlet UILabel *infoLabel;
@property (strong, nonatomic) DSCoinJoinManager *coinJoinManager;

@end

NS_ASSUME_NONNULL_END
