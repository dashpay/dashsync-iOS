//
//  Created by Andrew Podkovyrin
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

#import "DPBaseObject.h"

#import "DPBase58DataEncoder.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DPDocumentAction) {
    DPDocumentAction_Create = 0,
    DPDocumentAction_Update = 1,
    DPDocumentAction_Delete = 2,
};

@interface DPDocument : DPBaseObject

@property (readonly, copy, nonatomic) NSString *identifier;

@property (readonly, copy, nonatomic) NSString *type;
@property (readonly, copy, nonatomic) NSString *scope;
@property (readonly, copy, nonatomic) NSString *scopeId;
@property (readonly, assign, nonatomic) DPDocumentAction action;
@property (readonly, strong, nonatomic) NSNumber *revision;
@property (readonly, copy, nonatomic) DPJSONObject *data;

- (instancetype)initWithRawDocument:(DPJSONObject *)rawDocument
                  base58DataEncoder:(id<DPBase58DataEncoder>)base58DataEncoder;

- (instancetype)init NS_UNAVAILABLE;

- (void)setAction:(DPDocumentAction)action error:(NSError *_Nullable __autoreleasing *)error;
- (void)setData:(DPJSONObject *)data error:(NSError *_Nullable __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
