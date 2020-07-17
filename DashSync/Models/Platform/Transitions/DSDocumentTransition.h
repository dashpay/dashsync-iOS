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

#import "DSTransition.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DSDocumentTransitionType) {
    DSDocumentTransitionType_Create = 1,
    DSDocumentTransitionType_Update = 2,
    DSDocumentTransitionType_Delete = 3,
};

@interface DSDocumentTransition : DSTransition

@property(nonatomic,readonly) NSArray<DPDocument *>* documents;

-(instancetype)initForDocuments:(NSArray<DPDocument*>*)documents withTransitionVersion:(uint16_t)version blockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId usingEntropyString:(NSString*)entropyString onChain:(DSChain *)chain;

@end

NS_ASSUME_NONNULL_END
