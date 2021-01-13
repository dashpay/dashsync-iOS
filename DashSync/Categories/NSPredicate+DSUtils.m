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

#import "NSPredicate+DSUtils.h"
#import <CoreData/CoreData.h>

@implementation NSPredicate (DSUtils)

- (NSPredicate *)predicateInContext:(NSManagedObjectContext *)context {
    if ([self isMemberOfClass:[NSCompoundPredicate class]]) {
        NSMutableArray *mArray = [NSMutableArray array];
        NSCompoundPredicate *compoundPredicate = (NSCompoundPredicate *)self;
        for (NSPredicate *predicate in compoundPredicate.subpredicates) {
            [mArray addObject:[predicate predicateInContext:context]];
        }
        switch (compoundPredicate.compoundPredicateType) {
            case NSAndPredicateType:
                return [NSCompoundPredicate andPredicateWithSubpredicates:mArray];
            case NSOrPredicateType:
                return [NSCompoundPredicate orPredicateWithSubpredicates:mArray];
            case NSNotPredicateType:
                return [NSCompoundPredicate notPredicateWithSubpredicate:[mArray firstObject]];
            default:
                return [NSCompoundPredicate andPredicateWithSubpredicates:mArray];
        }
    } else {
        NSComparisonPredicate *comparisonPredicate = (NSComparisonPredicate *)self;
        NSExpression *leftExpression = comparisonPredicate.leftExpression;
        NSExpression *rightExpression = comparisonPredicate.rightExpression;
        NSExpression *leftExpressionInContext = comparisonPredicate.leftExpression;
        NSExpression *rightExpressionInContext = comparisonPredicate.rightExpression;

        if ((leftExpression.expressionType == NSConstantValueExpressionType) && [leftExpression.constantValue isKindOfClass:[NSManagedObject class]]) {
            NSManagedObject *managedObject = (NSManagedObject *)leftExpression.constantValue;
            NSManagedObject *managedObjectInContext = [context objectWithID:managedObject.objectID];
            leftExpressionInContext = [NSExpression expressionForConstantValue:managedObjectInContext];
        }
        if ((rightExpression.expressionType == NSConstantValueExpressionType) && [rightExpression.constantValue isKindOfClass:[NSManagedObject class]]) {
            NSManagedObject *managedObject = (NSManagedObject *)rightExpression.constantValue;
            NSManagedObject *managedObjectInContext = [context objectWithID:managedObject.objectID];
            rightExpressionInContext = [NSExpression expressionForConstantValue:managedObjectInContext];
        }
        return [NSComparisonPredicate predicateWithLeftExpression:leftExpressionInContext rightExpression:rightExpressionInContext modifier:comparisonPredicate.comparisonPredicateModifier type:comparisonPredicate.predicateOperatorType options:comparisonPredicate.options];
    }
}

@end
