//
//  Created by Andrew Podkovyrin
//  Copyright © 2018 Dash Core Group. All rights reserved.
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

#import "DSHTTPDashBtcCCOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSHTTPDashBtcCCOperation ()

@property (strong, nonatomic, nullable) NSNumber *dashBtcPrice;

@end

@implementation DSHTTPDashBtcCCOperation

- (void)processSuccessResponse:(id)parsedData responseHeaders:(NSDictionary *)responseHeaders statusCode:(NSInteger)statusCode {
    NSParameterAssert(parsedData);

    NSDictionary *response = (NSDictionary *)parsedData;
    if (![response isKindOfClass:NSDictionary.class]) {
        [self cancelWithInvalidResponse:response];

        return;
    }

    NSDictionary *raw = response[@"RAW"];
    if (![raw isKindOfClass:NSDictionary.class]) {
        [self cancelWithInvalidResponse:response];

        return;
    }

    NSNumber *dashBtcPrice = raw[@"PRICE"];
    if (![dashBtcPrice isKindOfClass:NSNumber.class]) {
        [self cancelWithInvalidResponse:response];

        return;
    }

    self.dashBtcPrice = dashBtcPrice;

    [self finish];
}

@end

NS_ASSUME_NONNULL_END
