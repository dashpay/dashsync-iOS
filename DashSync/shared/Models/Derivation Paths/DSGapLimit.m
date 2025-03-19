//  
//  Created by Vladimir Pirogov
//  Copyright © 2025 Dash Core Group. All rights reserved.
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

#import "DSGapLimit.h"

@implementation DSGapLimit
+ (instancetype)initWithLimit:(uintptr_t)limit {
    DSGapLimit *inst = [[self alloc] init];
    inst.gapLimit = limit;
    return inst;
}
@end

@implementation DSGapLimitInternal
+ (instancetype)initWithLimit:(uintptr_t)limit internal:(BOOL)internal {
    DSGapLimitInternal *inst = [DSGapLimitInternal initWithLimit:limit];
    inst.internal = internal;
    return inst;
}
@end

@implementation DSGapLimitIdentity
+ (instancetype)initWithLimit:(uintptr_t)limit identityID:(uint32_t)identityID {
    DSGapLimitIdentity *inst = [DSGapLimitIdentity initWithLimit:limit];
    inst.identityID = identityID;
    return inst;
}
@end
