//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "DSContactProfileAvatarView.h"

#import <SDWebImage/SDWebImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSContactProfileAvatarView ()

@property (nonatomic, strong) UIImageView *imageView;

@end

@implementation DSContactProfileAvatarView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor groupTableViewBackgroundColor];

        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.backgroundColor = [UIColor lightGrayColor];
        [self addSubview:imageView];
        _imageView = imageView;

        [NSLayoutConstraint activateConstraints:@[
            [imageView.topAnchor constraintEqualToAnchor:self.topAnchor
                                                constant:10.0],
            [imageView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor
                                                   constant:-10.0],
            [imageView.heightAnchor constraintEqualToAnchor:imageView.widthAnchor],
            [imageView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        ]];
    }
    return self;
}

- (void)updateWithImageURL:(nullable NSURL *)url {
    [self.imageView sd_setImageWithURL:url];
}

@end

NS_ASSUME_NONNULL_END
