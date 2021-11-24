//
//  Created by Vladimir Pirogov
//  Copyright © 2021 Dash Core Group. All rights reserved.
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

#import "BigIntTypes.h"
#import "mndiff.h"
#import <Foundation/Foundation.h>

#ifndef rust_utils_h
#define rust_utils_h
#include <stdio.h>

// shorthand for UInt256 <-> c array pointer
UInt256 UInt256fromCArray(uint8_t (*arr)[32]) {
    //[NSData dataWithBytes:list->block_hash length:32].UInt256;
    UInt256 u;
    memset(u.u8, 0, 32);
    memcpy(u.u8, arr, 32);
    return u;
}

#endif /* rust_utils_h */
