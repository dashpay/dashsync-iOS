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

#import "DSDirectionalRange.h"
#import "DSPlatformTreeQuery.h"
#import "NSData+Dash.h"
#import "NSObject+DSCborEncoding.h"
#import "NSPredicate+CBORData.h"


@implementation NSPredicate (CBORData)

- (NSArray *)whereClauseArray {
    return [self whereClauseArrayWithOptions:NSPredicateCBORDataOptions_None];
}

- (NSArray *)whereClauseArrayWithOptions:(NSPredicateCBORDataOptions)options {
    if ([self isMemberOfClass:[NSCompoundPredicate class]]) {
        return [self whereClauseNestedArrayWithOptions:options];
    } else {
        return @[[self whereClauseNestedArrayWithOptions:options]];
    }
}

- (NSData *)singleElementQueryKey {
    NSAssert(![self isMemberOfClass:[NSCompoundPredicate class]], @"This should only be queried on non compound queries");
    NSAssert([self isKindOfClass:[NSComparisonPredicate class]], @"This should only be queried on a comparison predicate");
    NSComparisonPredicate *comparisonPredicate = (NSComparisonPredicate *)self;
    NSAssert(comparisonPredicate.predicateOperatorType == NSEqualToPredicateOperatorType, @"This should only be queried on a comparison predicate");
    NSExpression *leftExpression = comparisonPredicate.leftExpression;
    NSExpression *rightExpression = comparisonPredicate.rightExpression;
    id key;
    switch (leftExpression.expressionType) {
        case NSConstantValueExpressionType:
            key = leftExpression.constantValue;
            break;
        case NSKeyPathExpressionType: {
            switch (rightExpression.expressionType) {
                case NSConstantValueExpressionType:
                    key = rightExpression.constantValue;
                    break;
                case NSKeyPathExpressionType:
                    NSAssert(NO, @"We must be querying a value");
                    break;
                case NSVariableExpressionType:
                    key = rightExpression.variable;
                    break;

                default:
                    NSAssert(FALSE, @"Not supported yet");
                    break;
            }
        } break;
        case NSVariableExpressionType:
            key = leftExpression.variable;
            break;

        default:
            NSAssert(FALSE, @"Not supported yet");
            break;
    }
    if ([key isKindOfClass:[NSData class]]) {
        return key;
    } else if ([key isKindOfClass:[NSString class]]) {
        return [(NSString *)key dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([key isKindOfClass:[NSNumber class]]) {
        return [NSData dataWithUInt64:[key unsignedLongLongValue]];
    } else {
        NSAssert(FALSE, @"Not supported key type");
        return nil;
    }
}

- (NSArray<NSData *> *)multipleElementQueryKey {
    NSAssert(![self isMemberOfClass:[NSCompoundPredicate class]], @"This should only be queried on non compound queries");
    NSAssert([self isKindOfClass:[NSComparisonPredicate class]], @"This should only be queried on a comparison predicate");
    NSComparisonPredicate *comparisonPredicate = (NSComparisonPredicate *)self;
    NSAssert(comparisonPredicate.predicateOperatorType == NSInPredicateOperatorType, @"This should only be queried on a comparison predicate");
    NSExpression *leftExpression = comparisonPredicate.leftExpression;
    NSExpression *rightExpression = comparisonPredicate.rightExpression;
    id key;
    switch (leftExpression.expressionType) {
        case NSConstantValueExpressionType:
            key = leftExpression.constantValue;
            break;
        case NSKeyPathExpressionType: {
            switch (rightExpression.expressionType) {
                case NSConstantValueExpressionType:
                    key = rightExpression.constantValue;
                    break;
                case NSKeyPathExpressionType:
                    NSAssert(NO, @"We must be querying a value");
                    break;
                case NSVariableExpressionType:
                    key = rightExpression.variable;
                    break;

                default:
                    NSAssert(FALSE, @"Not supported yet");
                    break;
            }
        } break;
        case NSVariableExpressionType:
            key = leftExpression.variable;
            break;

        default:
            NSAssert(FALSE, @"Not supported yet");
            break;
    }
    if ([key isKindOfClass:[NSArray class]]) {
        return key;
    } else {
        NSAssert(FALSE, @"Not supported key type");
        return nil;
    }
}

- (NSArray *)whereClauseNestedArrayWithOptions:(NSPredicateCBORDataOptions)options {
    if ([self isMemberOfClass:[NSCompoundPredicate class]]) {
        NSMutableArray *mArray = [NSMutableArray array];
        NSCompoundPredicate *compoundPredicate = (NSCompoundPredicate *)self;
        NSAssert(compoundPredicate.compoundPredicateType == NSAndPredicateType, @"We currently only support AND predicates");
        for (NSPredicate *predicate in compoundPredicate.subpredicates) {
            [mArray addObject:[predicate whereClauseNestedArrayWithOptions:options]];
        }
        return mArray;
    } else {
        NSMutableArray *mArray = [NSMutableArray array];
        NSComparisonPredicate *comparisonPredicate = (NSComparisonPredicate *)self;
        NSExpression *leftExpression = comparisonPredicate.leftExpression;
        NSExpression *rightExpression = comparisonPredicate.rightExpression;
        NSString *operator;
        switch (comparisonPredicate.predicateOperatorType) {
            case NSEqualToPredicateOperatorType:
                operator= @"==";
                break;
            case NSLessThanPredicateOperatorType:
                operator= @"<";
                break;
            case NSLessThanOrEqualToPredicateOperatorType:
                operator= @"<=";
                break;
            case NSGreaterThanPredicateOperatorType:
                operator= @">";
                break;
            case NSGreaterThanOrEqualToPredicateOperatorType:
                operator= @">=";
                break;
            case NSNotEqualToPredicateOperatorType:
                operator= @"!=";
                NSAssert(FALSE, @"Not supported yet");
                break;
            case NSBeginsWithPredicateOperatorType:
                operator= @"startsWith";
                break;
            case NSInPredicateOperatorType:
                operator= @"in";
                break;
            default:
                operator= @"!";
                NSAssert(FALSE, @"Not supported yet");
                break;
        }
        switch (leftExpression.expressionType) {
            case NSConstantValueExpressionType:
                if (options & NSPredicateCBORDataOptions_DataToBase64 && [rightExpression.constantValue isKindOfClass:[NSData class]]) {
                    [mArray addObject:[((NSData *)leftExpression.constantValue) base64String]];
                } else {
                    [mArray addObject:leftExpression.constantValue];
                }
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
                if (options & NSPredicateCBORDataOptions_DataToBase64 && [rightExpression.constantValue isKindOfClass:[NSData class]]) {
                    [mArray addObject:[((NSData *)rightExpression.constantValue) base64String]];
                } else if (options & NSPredicateCBORDataOptions_DataToBase64 && [rightExpression.constantValue isKindOfClass:[NSArray class]]) {
                    //We might have an array of data
                    NSMutableArray *base64Array = [NSMutableArray array];
                    for (NSObject *member in rightExpression.constantValue) {
                        if ([member isKindOfClass:[NSData class]]) {
                            [base64Array addObject:[((NSData *)member) base64String]];
                        } else {
                            [base64Array addObject:member];
                        }
                    }
                    [mArray addObject:base64Array];
                } else {
                    [mArray addObject:rightExpression.constantValue];
                }
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

- (DSPlatformTreeQuery *)platformTreeQuery {
    //todo
    return nil;
}

- (NSData *)dashPlatormWhereData {
    return [[self whereClauseArray] ds_cborEncodedObject];
}

- (NSData *)secondaryIndexPathForQueryType:(DSPlatformQueryType)queryType {
    //ToDo: We probably need to not have the last element of the whereClause
    NSArray *array = [self whereClauseArrayWithOptions:NSPredicateCBORDataOptions_DataToBase64];
    //This will be replaced
    switch (queryType) {
        case DSPlatformQueryType_OneElement:
            return [[array componentsJoinedByString:@"|"] dataUsingEncoding:NSUTF8StringEncoding];
        case DSPlatformQueryType_IndividualElements:
            return [[array componentsJoinedByString:@"|"] dataUsingEncoding:NSUTF8StringEncoding];
        case DSPlatformQueryType_RangeOverValue:
            return [[array componentsJoinedByString:@"|"] dataUsingEncoding:NSUTF8StringEncoding];
        case DSPlatformQueryType_RangeOverIndex:
            return [[array componentsJoinedByString:@"|"] dataUsingEncoding:NSUTF8StringEncoding];
    }
}

@end
