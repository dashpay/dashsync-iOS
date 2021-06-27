//
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

#import <DSDynamicOptions/DSDynamicOptions.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSErrorSimulationManager : DSDynamicOptions

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) uint32_t peerRandomDisconnectionFrequency;

//This is when a byzantine peer can omit transactions.
@property (nonatomic, assign) uint32_t peerByzantineTransactionOmissionFrequency;

//This is when a byzantine peer can maliciously report a higher estimated block height to get the client to select them.
@property (nonatomic, assign) uint32_t peerByzantineReportingHigherEstimatedBlockHeightFrequency;

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
