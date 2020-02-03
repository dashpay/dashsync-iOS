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

#import "DSDAPIGRPCResponseHandler.h"

@interface DSDAPIGRPCResponseHandler()

@property(nonatomic,strong) NSDictionary * responseDictionary;

@end

@implementation DSDAPIGRPCResponseHandler

- (void)didReceiveInitialMetadata:(nullable NSDictionary *)initialMetadata {
    NSLog(@"didReceiveInitialMetadata");
}

- (void)didReceiveProtoMessage:(nullable GPBMessage *)message {
    NSLog(@"didReceiveProtoMessage");
}

- (void)didCloseWithTrailingMetadata:(nullable NSDictionary *)trailingMetadata
                               error:(nullable NSError *)error {
    
    if (error) {
        if (self.errorHandler) {
            self.errorHandler(error);
        }
        NSLog(@"error in didCloseWithTrailingMetadata %@",error);
    } else {
        self.successHandler(self.responseDictionary);
    }
    NSLog(@"didCloseWithTrailingMetadata");
}

-(void)didWriteMessage {
    NSLog(@"didWriteMessage");
}


@end
