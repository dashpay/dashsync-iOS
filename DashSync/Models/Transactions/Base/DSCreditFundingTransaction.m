//  
//  Created by Sam Westrich
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

#import "DSCreditFundingTransaction.h"
#import "DSCreditFundingTransactionEntity+CoreDataClass.h"

@implementation DSCreditFundingTransaction

-(UInt256)creditBurnIdentityIdentifier {
    for (NSData * script in self.outputScripts) {
        if ([script UInt8AtOffset:0] == OP_RETURN && script.length == 21) {
            return [script SHA256_2];
        }
    }
    return UINT256_ZERO;
}

-(Class)entityClass {
    return [DSCreditFundingTransactionEntity class];
}

@end
