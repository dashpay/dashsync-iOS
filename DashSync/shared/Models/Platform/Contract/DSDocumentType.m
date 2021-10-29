//
//  Created by Sam Westrich
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

#import "DSDocumentType.h"
#import "DPContract.h"
#import "NSData+Dash.h"

@implementation DSDocumentType

- (NSArray<NSData *> *)path {
    return @[uint256_data(self.contract.contractId), [NSData dataWithUInt8:self.contractIndex]];
}

- (NSData *)serializedPath {
    NSMutableData *contactenatedData = [NSMutableData data];
    for (NSData *pathData in self.path) {
        [contactenatedData appendData:[NSData dataWithUInt8:pathData.length]];
        [contactenatedData appendData:pathData];
    }
    return uint256_data([contactenatedData SHA256_2]);
}

@end
