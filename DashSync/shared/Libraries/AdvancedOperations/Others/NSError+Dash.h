//  
//  Created by Vladimir Pirogov
//  Copyright © 2022 Dash Core Group. All rights reserved.
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define ERROR_500(msg) [NSError errorWithCode:500 localizedDescriptionKey:msg]
//#define DS_ERROR(domain, code, localizedDescriptionKey) [NSError errorWithDomain:domain code:code userInfo:@{ NSLocalizedDescriptionKey: localizedDescriptionKey }];

@interface NSError (Dash)

+ (instancetype)errorWithCode:(NSInteger)code userInfo:(nullable NSDictionary<NSErrorUserInfoKey, id> *)dict;
+ (instancetype)errorWithCode:(NSInteger)code descriptionKey:(NSString *)descriptionKey;
+ (instancetype)errorWithCode:(NSInteger)code localizedDescriptionKey:(NSString *)localizedDescriptionKey;

+ (instancetype)osStatusErrorWithCode:(NSInteger)code;
+ (NSString *)errorsDescription:(NSArray<NSError *> *)errors;

@end

NS_ASSUME_NONNULL_END
