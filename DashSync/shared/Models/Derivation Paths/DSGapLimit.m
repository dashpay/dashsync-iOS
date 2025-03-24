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
+ (instancetype)withLimit:(uintptr_t)limit {
    DSGapLimit *inst = [[self alloc] init];
    inst.gapLimit = limit;
    return inst;
}
+ (instancetype)single {
    return [DSGapLimit withLimit:1];
}
@end

@implementation DSGapLimitFunds

+ (instancetype)withLimit:(uintptr_t)limit {
    DSGapLimitFunds *inst = [[self alloc] init];
    inst.gapLimit = limit;
    return inst;
}

+ (instancetype)withLimit:(uintptr_t)limit direction:(DSGapLimitFundsDirection)direction {
    DSGapLimitFunds *inst = [DSGapLimitFunds withLimit:limit];
    inst.direction = direction;
    return inst;
}
+ (instancetype)internalSingle {
    DSGapLimitFunds *inst = [DSGapLimitFunds withLimit:1];
    inst.direction = DSGapLimitFundsDirection_Internal;
    return inst;
}
+ (instancetype)externalSingle {
    DSGapLimitFunds *inst = [DSGapLimitFunds withLimit:1];
    inst.direction = DSGapLimitFundsDirection_External;
    return inst;
}
+ (instancetype)internal:(uintptr_t)limit {
    DSGapLimitFunds *inst = [DSGapLimitFunds withLimit:limit];
    inst.direction = DSGapLimitFundsDirection_Internal;
    return inst;
}
+ (instancetype)external:(uintptr_t)limit {
    DSGapLimitFunds *inst = [DSGapLimitFunds withLimit:limit];
    inst.direction = DSGapLimitFundsDirection_External;
    return inst;
}

@end

@implementation DSGapLimitIdentity
+ (instancetype)withLimit:(uintptr_t)limit {
    DSGapLimitIdentity *inst = [[self alloc] init];
    inst.gapLimit = limit;
    return inst;
}

+ (instancetype)withLimit:(uintptr_t)limit identityID:(uint32_t)identityID {
    DSGapLimitIdentity *inst = [DSGapLimitIdentity withLimit:limit];
    inst.identityID = identityID;
    return inst;
}
@end
