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

#import "NSPredicate+CBORData.h"
#import "NSObject+DSCborEncoding.h"


@implementation NSPredicate (CBORData)

-(NSArray*)whereClauseArray {
    if ([self isMemberOfClass:[NSCompoundPredicate class]]) {
        NSMutableArray * mArray = [NSMutableArray array];
        NSCompoundPredicate * compoundPredicate = (NSCompoundPredicate *)self;
        for (NSPredicate * predicate in compoundPredicate.subpredicates) {
            [mArray addObject:[predicate whereClauseArray]];
        }
        return mArray;
    } else {
        NSMutableArray * mArray = [NSMutableArray array];
        NSComparisonPredicate * comparisonPredicate = (NSComparisonPredicate*)self;
        NSExpression * leftExpression = comparisonPredicate.leftExpression;
        NSExpression * rightExpression = comparisonPredicate.rightExpression;
        NSString * operator;
        switch (comparisonPredicate.predicateOperatorType) {
            case NSEqualToPredicateOperatorType:
                operator = @"==";
                break;
            case NSLessThanPredicateOperatorType:
                operator = @"<";
                break;
            case NSLessThanOrEqualToPredicateOperatorType:
                operator = @"<=";
                break;
            case NSGreaterThanPredicateOperatorType:
                operator = @"==";
                break;
            case NSGreaterThanOrEqualToPredicateOperatorType:
                operator = @">=";
                break;
            case NSNotEqualToPredicateOperatorType:
                operator = @"!=";
                NSAssert(FALSE, @"Not supported yet");
                break;
            case NSBeginsWithPredicateOperatorType:
                operator = @"startsWith";
                break;
            case NSInPredicateOperatorType:
                    operator = @"in";
                    break;
            default:
                operator = @"!";
                NSAssert(FALSE, @"Not supported yet");
                break;
        }
        switch (leftExpression.expressionType) {
            case NSConstantValueExpressionType:
                [mArray addObject:leftExpression.constantValue];
                break;
            case NSKeyPathExpressionType:
                [mArray addObject:leftExpression.keyPath];
                break;
                
            default:
                NSAssert(FALSE, @"Not supported yet");
                break;
        }
        [mArray addObject:operator];
        switch (rightExpression.expressionType) {
            case NSConstantValueExpressionType:
                [mArray addObject:rightExpression.constantValue];
                break;
            case NSKeyPathExpressionType:
                [mArray addObject:rightExpression.keyPath];
                break;
                
            default:
                NSAssert(FALSE, @"Not supported yet");
                break;
        }
        return mArray;
    }
}

-(NSData*)dashPlatormWhereDataWithStartAt:(NSNumber* _Nullable)startAt limit:(NSNumber* _Nullable)limit orderBy:(NSArray<NSSortDescriptor*>*)sortDescriptors {
    NSMutableDictionary * dictionary = [NSMutableDictionary dictionary];
    if (startAt) {
        [dictionary setObject:startAt forKey:@"startAt"];
    }
    if (limit) {
        [dictionary setObject:limit forKey:@"limit"];
    }
    [dictionary setObject:[self whereClauseArray] forKey:@"where"];
    NSMutableArray * sortDescriptorsArray = [NSMutableArray array];
    for (NSSortDescriptor * sortDescriptor in sortDescriptors) {
        [sortDescriptorsArray addObject:@[sortDescriptor.key,sortDescriptor.ascending?@"asc":@"desc"]];
    }
    [dictionary setObject:sortDescriptorsArray forKey:@"orderBy"];
    return [dictionary ds_cborEncodedObject];
}

@end
