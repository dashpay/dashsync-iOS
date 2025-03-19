//  
//  Created by Andrei Ashikhmin
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import "DSBackoff.h"

@implementation DSBackoff

- (instancetype)initInitialBackoff:(float_t)initial maxBackoff:(float_t)max multiplier:(float_t)multiplier {
    self = [super init];
    if (self) {
        _maxBackoff = max;
        _initialBackoff = initial;
        _multiplier = multiplier;
        [self trackSuccess];
    }
    return self;
}

- (void)trackSuccess {
    _backoff = _initialBackoff;
    _retryTime = [NSDate date];
}

- (void)trackFailure {
    _retryTime = [[NSDate date] dateByAddingTimeInterval:_backoff];
    _backoff = MIN(_backoff, _maxBackoff);
}

@end
