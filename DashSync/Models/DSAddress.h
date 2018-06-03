//
//  DSAddress.h
//  DashSync
//
//  Created by Sam Westrich on 6/3/18.
//

#import <Foundation/Foundation.h>
@class DSDerivationPath;

@interface DSAddress : NSObject

@property(nonatomic,readonly) DSDerivationPath * derivationPath;
@property(nonatomic,readonly) BOOL internal;
@property(nonatomic,readonly) uint32_t index;
@property(nonatomic,readonly) NSString * addressString;

+(DSAddress*)addressWithAddressString:(NSString*)addressString onDerivationPath:(DSDerivationPath*)derivationPath atIndex:(uint32_t)index internal:(BOOL)internal;

@end
