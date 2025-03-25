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

#import "NSError+Dash.h"

@implementation NSError (Dash)

+ (instancetype)errorWithCode:(NSInteger)code userInfo:(nullable NSDictionary<NSErrorUserInfoKey, id> *)dict {
    return [NSError errorWithDomain:@"DashSync" code:code userInfo:dict];
}

+ (instancetype)errorWithCode:(NSInteger)code descriptionKey:(NSString *)descriptionKey {
    return [NSError errorWithCode:code userInfo:@{NSLocalizedDescriptionKey: descriptionKey}];
}

+ (instancetype)errorWithCode:(NSInteger)code localizedDescriptionKey:(NSString *)localizedDescriptionKey {
    return [NSError errorWithCode:code descriptionKey:DSLocalizedString(localizedDescriptionKey, nil)];
}

+ (instancetype)osStatusErrorWithCode:(NSInteger)code {
    return [NSError errorWithDomain:NSOSStatusErrorDomain code:code userInfo:nil];
}

+ (NSString *)errorsDescription:(NSArray<NSError *> *)errors {
    NSMutableString *description = [NSMutableString string];
    for (NSError *error in errors) {
        [description appendFormat:@"%@\n", error.localizedDescription];
    }
    return description;
}

@end
