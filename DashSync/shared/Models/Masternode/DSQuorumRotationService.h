//  
//  Created by Vladimir Pirogov
//  Copyright © 2022 Dash Core Group. All rights reserved.
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

#import <Foundation/Foundation.h>
#import "DSMasternodeListService.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumRotationService : DSMasternodeListService

@property (nonatomic, readonly) DSMasternodeList *masternodeListAtTip;
@property (nonatomic, readonly) DSMasternodeList *masternodeListAtH;
@property (nonatomic, readonly) DSMasternodeList *masternodeListAtHC;
@property (nonatomic, readonly) DSMasternodeList *masternodeListAtH2C;
@property (nonatomic, readonly) DSMasternodeList *masternodeListAtH3C;
@property (nonatomic, readonly) DSMasternodeList *masternodeListAtH4C;

@end

NS_ASSUME_NONNULL_END
