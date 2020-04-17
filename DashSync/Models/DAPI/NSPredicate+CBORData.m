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
#import "NSData+Bitcoin.h"


@implementation NSPredicate (CBORData)

-(NSArray*)whereClauseArray {
    if ([self isMemberOfClass:[NSCompoundPredicate class]]) {
        return [self whereClauseNestedArray];
    } else {
        return @[[self whereClauseNestedArray]];
    }
}

-(NSArray*)whereClauseNestedArray {
    if ([self isMemberOfClass:[NSCompoundPredicate class]]) {
        NSMutableArray * mArray = [NSMutableArray array];
        NSCompoundPredicate * compoundPredicate = (NSCompoundPredicate *)self;
        for (NSPredicate * predicate in compoundPredicate.subpredicates) {
            [mArray addObject:[predicate whereClauseNestedArray]];
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
            case NSVariableExpressionType:
                [mArray addObject:leftExpression.variable];
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
            case NSVariableExpressionType:
                [mArray addObject:rightExpression.variable];
                break;
                
            default:
                NSAssert(FALSE, @"Not supported yet");
                break;
        }
        return mArray;
    }
}

-(NSData*)dashPlatormWhereData {
//    NSMutableDictionary * dictionary = [NSMutableDictionary dictionary];
//    if (startAt) {
//        [dictionary setObject:startAt forKey:@"startAt"];
//    }
//    if (limit) {
//        [dictionary setObject:limit forKey:@"limit"];
//    }
//    [dictionary setObject:[self whereClauseArray] forKey:@"where"];
//    NSMutableArray * sortDescriptorsArray = [NSMutableArray array];
//    for (NSSortDescriptor * sortDescriptor in sortDescriptors) {
//        [sortDescriptorsArray addObject:@[sortDescriptor.key,sortDescriptor.ascending?@"asc":@"desc"]];
//    }
//    [dictionary setObject:sortDescriptorsArray forKey:@"orderBy"];
    NSData * json = [NSJSONSerialization dataWithJSONObject:[self whereClauseArray] options:0 error:nil];
    DSDLog(@"json where %@",[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]);
 //   DSDLog(@"hex %@",[[self whereClauseArray] ds_cborEncodedObject].hexString);
    return [[self whereClauseArray] ds_cborEncodedObject];
}

@end
