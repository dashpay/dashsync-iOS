//
//  DSBLSSignatures.h
//  DashSync
//
//  Created by Andrew Podkovyrin on 02/11/2018.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DSDerivationPath;

@interface DSBLSSignatures : NSObject

+(UInt256)privateKeyDerivedFromSeed:(UInt512)seed toPath:(DSDerivationPath*)derivationPath;

@end

NS_ASSUME_NONNULL_END
