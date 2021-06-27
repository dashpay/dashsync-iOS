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

#import "DSErrorSimulationManager.h"

@implementation DSErrorSimulationManager

@dynamic enabled;
@dynamic peerRandomDisconnectionFrequency;
@dynamic peerByzantineTransactionOmissionFrequency;

+ (instancetype)sharedInstance {
    static DSErrorSimulationManager *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    NSDictionary *defaults = @{
        @"enabled": @NO,
        @"peerRandomDisconnectionFrequency": @0,          // 10 min
        @"peerByzantineTransactionOmissionFrequency": @0, // 10 min
    };

    self = [super initWithUserDefaults:nil defaults:defaults];
    if (self) {
    }
    return self;
}


@end
