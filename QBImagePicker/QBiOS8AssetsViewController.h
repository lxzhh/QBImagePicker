//
//  QBiOS8AssetsViewController.h
//  QBImagePicker
//
//  Created by redhat' iMac on 16/7/26.
//  Copyright © 2016年 Katsuma Tanaka. All rights reserved.
//

#import <UIKit/UIKit.h>

@class QBImagePickerController;
@class PHAssetCollection;
@interface QBiOS8AssetsViewController : UICollectionViewController
@property (nonatomic, weak) QBImagePickerController *imagePickerController;
@property (nonatomic, strong) PHAssetCollection *photoCollection;
@end
