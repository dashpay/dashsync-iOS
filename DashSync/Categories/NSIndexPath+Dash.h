//
//  NSIndexPath+Dash.h
//  AFNetworking
//
//  Created by Sam Westrich on 11/3/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSIndexPath (Dash)

-(NSIndexPath*)indexPathByRemovingFirstIndex;
-(NSString *)indexPathString;
-(NSIndexPath*)hardenAllItems;
-(NSIndexPath*)softenAllItems;

@end

NS_ASSUME_NONNULL_END
