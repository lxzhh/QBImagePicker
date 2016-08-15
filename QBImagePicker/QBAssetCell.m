//
//  QBAssetCell.m
//  QBImagePicker
//
//  Created by Katsuma Tanaka on 2015/04/06.
//  Copyright (c) 2015 Katsuma Tanaka. All rights reserved.
//

#import "QBAssetCell.h"
#import <Photos/Photos.h>
@interface QBAssetCell ()

@property (weak, nonatomic) IBOutlet UIView *overlayView;
@property (nonatomic, assign) PHImageRequestID requestId;

@end

@implementation QBAssetCell

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    // Show/hide overlay view
    self.overlayView.hidden = !(selected && self.showsOverlayViewWhenSelected);
}
-(void)setImageWiAsset:(id)asset{
    // Image
    if ([asset isKindOfClass:[PHAsset class]]) {
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.resizeMode = PHImageRequestOptionsResizeModeFast;
        CGFloat scale = [UIScreen mainScreen].scale;
        CGFloat dimension = 78.0f;
        CGSize size = CGSizeMake(dimension*scale, dimension*scale);
        
        PHImageRequestID requestId = [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:size contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage *result, NSDictionary *info) {
            self.imageView.image = result;
        }];
        self.requestId = requestId;
    }
    
}


-(void)prepareForReuse{
    if (self.requestId > 0) {
        [[PHImageManager defaultManager] cancelImageRequest:self.requestId];
    }
}
@end
