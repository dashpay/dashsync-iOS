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

NS_ASSUME_NONNULL_BEGIN

@interface DPDocument : DPBaseObject

//@property (readonly, copy, nonatomic) NSString *identifier;

@property (readonly, copy, nonatomic) NSString *type;
@property (readonly, copy, nonatomic) NSString *contractId;
@property (readonly, copy, nonatomic) NSString *userId;
@property (readonly, copy, nonatomic) NSString *entropy;
@property (readonly, strong, nonatomic) NSNumber *revision;
@property (readonly, copy, nonatomic) DPJSONObject *data;

- (instancetype)initWithRawDocument:(DPJSONObject *)rawDocument;

- (instancetype)init NS_UNAVAILABLE;

- (void)setData:(DPJSONObject *)data error:(NSError *_Nullable __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
