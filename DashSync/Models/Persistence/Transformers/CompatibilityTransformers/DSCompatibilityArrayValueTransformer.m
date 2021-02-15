//
//  Created by Samuel Westrich
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

#import "DSCompatibilityArrayValueTransformer.h"

@interface DSCompatibilityArrayValueTransformer ()

@property (nonatomic, strong) id decodedObject;

@end

@implementation DSCompatibilityArrayValueTransformer

+ (void)load {
    [NSValueTransformer setValueTransformer:DSCompatibilityArrayValueTransformer.new
                                    forName:@"DSCompatibilityArrayValueTransformer"];
}

+ (Class)transformedValueClass {
    return NSData.class;
}

+ (NSArray<Class> *)allowedTopLevelClasses {
    return @[NSArray.class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value {
    NSAssert([value isKindOfClass:NSData.class] == NO, @"invalid");
    if (@available(iOS 11.0, *)) {
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:value requiringSecureCoding:NO error:&error];
        NSAssert(error == nil, @"Failed transforming object to data %@", error);
        return data;
    } else {
        NSAssert(NO, @"unsupported");
        return nil;
    }
}

- (id)reverseTransformedValue:(id)value {
    NSAssert([value isKindOfClass:NSData.class], @"invalid");
    if (@available(iOS 11.0, *)) {
        NSError *error = nil;
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:value error:&error];
        unarchiver.requiresSecureCoding = FALSE;
        unarchiver.delegate = self;
        [unarchiver finishDecoding];
        NSAssert(error == nil, @"Failed transforming data to object %@", error);
        NSAssert(self.decodedObject != nil, @"Decoded object should exist");
        return self.decodedObject;
    } else {
        NSAssert(NO, @"unsupported");
        return nil;
    }
}

- (nullable id)unarchiver:(NSKeyedUnarchiver *)unarchiver didDecodeObject:(nullable id)object {
    self.decodedObject = object;
    return nil;
}

@end
