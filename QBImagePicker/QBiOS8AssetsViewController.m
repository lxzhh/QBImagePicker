//
//  QBiOS8AssetsViewController.m
//  QBImagePicker
//
//  Created by redhat' iMac on 16/7/26.
//  Copyright © 2016年 Katsuma Tanaka. All rights reserved.
//

#import "QBiOS8AssetsViewController.h"
#import "QBAssetCell.h"
#import "QBVideoIndicatorView.h"
// ViewControllers
#import "QBImagePickerController.h"
#import <Photos/Photos.h>
@interface QBImagePickerController (Private)

@property (nonatomic, strong) NSBundle *assetBundle;

@end


@interface QBiOS8AssetsViewController () <UICollectionViewDelegateFlowLayout,PHPhotoLibraryChangeObserver>

@property (nonatomic, strong) IBOutlet UIBarButtonItem *doneButton;

@property (nonatomic, copy) NSArray *assets;
@property (nonatomic, assign) NSUInteger numberOfAssets;
@property (nonatomic, assign) NSUInteger numberOfPhotos;
@property (nonatomic, assign) NSUInteger numberOfVideos;

@property (nonatomic, assign) BOOL disableScrollToBottom;
@property (nonatomic, strong) NSIndexPath *indexPathForLastVisibleItem;
@property (nonatomic, strong) NSIndexPath *lastSelectedItemIndexPath;

@end

@implementation QBiOS8AssetsViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setUpToolbarItems];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Configure navigation item
    self.navigationItem.title = [self.photoCollection localizedTitle];
    self.navigationItem.prompt = self.imagePickerController.prompt;
    
    // Configure collection view
    self.collectionView.allowsMultipleSelection = self.imagePickerController.allowsMultipleSelection;
    
    // Show/hide 'Done' button
    if (self.imagePickerController.allowsMultipleSelection) {
        [self.navigationItem setRightBarButtonItem:self.doneButton animated:NO];
    } else {
        [self.navigationItem setRightBarButtonItem:nil animated:NO];
    }
    
    [self updateDoneButtonState];
    [self updateSelectionInfo];
    
    // Scroll to bottom
    if (self.numberOfAssets > 0 && self.isMovingToParentViewController && !self.disableScrollToBottom) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:(self.numberOfAssets - 1) inSection:0];
        [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionTop animated:NO];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    self.disableScrollToBottom = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.disableScrollToBottom = NO;
}




#pragma mark - Accessors

- (void)setPhotoCollection:(PHAssetCollection *)photoCollection
{
    _photoCollection = photoCollection;
    
    [self updateAssets];
    
    if ([self isAutoDeselectEnabled] && self.imagePickerController.selectedAssetURLs.count > 0) {
        // Get index of previous selected asset
        NSURL *previousSelectedAssetURL = [self.imagePickerController.selectedAssetURLs firstObject];
        
        [self.assets enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger index, BOOL *stop) {
            NSURL *assetURL = [NSURL URLWithString:[asset localIdentifier]];
            
            if ([assetURL isEqual:previousSelectedAssetURL]) {
                self.lastSelectedItemIndexPath = [NSIndexPath indexPathForItem:index inSection:0];
                *stop = YES;
            }
        }];
    }
    
    [self.collectionView reloadData];
}

- (BOOL)isAutoDeselectEnabled
{
    return (self.imagePickerController.maximumNumberOfSelection == 1
            && self.imagePickerController.maximumNumberOfSelection >= self.imagePickerController.minimumNumberOfSelection);
}


#pragma mark - Handling Device Rotation

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    // Save indexPath for the last item
    self.indexPathForLastVisibleItem = [[self.collectionView indexPathsForVisibleItems] lastObject];
    
    // Update layout
    [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    // Restore scroll position
    [self.collectionView scrollToItemAtIndexPath:self.indexPathForLastVisibleItem atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    // Save indexPath for the last item
    NSIndexPath *indexPath = [[self.collectionView indexPathsForVisibleItems] lastObject];
    
    // Update layout
    [self.collectionView.collectionViewLayout invalidateLayout];
    
    // Restore scroll position
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
    }];
}


#pragma mark - Handling Assets Library Changes
- (void)photoLibraryDidChange:(PHChange *)changeInstance{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        PHObjectChangeDetails * changeDetails = [changeInstance changeDetailsForObject:self.photoCollection];
        if ([changeDetails assetContentChanged] || [changeDetails objectWasDeleted]) {
            [self updateAssets];
            [self.collectionView reloadData];
        }
    });
}



#pragma mark - Actions

- (IBAction)done:(id)sender
{
    if ([self.imagePickerController.delegate respondsToSelector:@selector(qb_imagePickerController:didSelectAssets:)]) {
        [self fetchAssetsFromSelectedAssetURLsWithCompletion:^(NSArray *assets) {
            [self.imagePickerController.delegate qb_imagePickerController:self.imagePickerController didSelectAssets:assets];
        }];
    }
}


#pragma mark - Toolbar

- (void)setUpToolbarItems
{
    // Space
    UIBarButtonItem *leftSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    UIBarButtonItem *rightSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    
    // Info label
    NSDictionary *attributes = @{ NSForegroundColorAttributeName: [UIColor blackColor] };
    UIBarButtonItem *infoButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:NULL];
    infoButtonItem.enabled = NO;
    [infoButtonItem setTitleTextAttributes:attributes forState:UIControlStateNormal];
    [infoButtonItem setTitleTextAttributes:attributes forState:UIControlStateDisabled];
    
    self.toolbarItems = @[leftSpace, infoButtonItem, rightSpace];
}

- (void)updateSelectionInfo
{
    NSMutableOrderedSet *selectedAssetURLs = self.imagePickerController.selectedAssetURLs;
    
    if (selectedAssetURLs.count > 0) {
        NSBundle *bundle = self.imagePickerController.assetBundle;
        NSString *format;
        if (selectedAssetURLs.count > 1) {
            format = NSLocalizedStringFromTableInBundle(@"items_selected", @"QBImagePicker", bundle, nil);
        } else {
            format = NSLocalizedStringFromTableInBundle(@"item_selected", @"QBImagePicker", bundle, nil);
        }
        
        NSString *title = [NSString stringWithFormat:format, selectedAssetURLs.count];
        [(UIBarButtonItem *)self.toolbarItems[1] setTitle:title];
    } else {
        [(UIBarButtonItem *)self.toolbarItems[1] setTitle:@""];
    }
}


#pragma mark - Fetching Assets

- (void)updateAssets
{
    NSMutableArray *assets = [NSMutableArray array];
    __block NSUInteger numberOfAssets = 0;
    __block NSUInteger numberOfPhotos = 0;
    __block NSUInteger numberOfVideos = 0;
    
    PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
    PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:self.photoCollection options:fetchOptions];
    [fetchResult enumerateObjectsUsingBlock:^(PHAsset*  _Nonnull result, NSUInteger idx, BOOL * _Nonnull stop) {
        if (result) {
            numberOfAssets++;
            PHAssetMediaType assetType = [result mediaType];
            
            if (assetType == PHAssetMediaTypeImage) numberOfPhotos++;
            else if (assetType == PHAssetMediaTypeVideo) numberOfVideos++;
            [assets addObject:result];
        }
    }];
    
    self.assets = assets;
    self.numberOfAssets = numberOfAssets;
    self.numberOfPhotos = numberOfPhotos;
    self.numberOfVideos = numberOfVideos;
}

- (void)fetchAssetsFromSelectedAssetURLsWithCompletion:(void (^)(NSArray *assets))completion
{
    // Load assets from URLs
    // The asset will be ignored if it is not found
    NSMutableOrderedSet *selectedAssetURLs = self.imagePickerController.selectedAssetURLs;
    
    __block NSMutableArray *assets = [NSMutableArray array];
    
    void (^checkNumberOfAssets)(void) = ^{
        if (assets.count == selectedAssetURLs.count) {
            if (completion) {
                completion([assets copy]);
            }
        }
    };
    
    for (NSURL *assetURL in selectedAssetURLs) {
        //是PHAsset
        PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetURL.absoluteString] options:nil];
        __block PHAsset *asset;
        if (result.count >0) {
            asset = [result firstObject];
        }else{
            dispatch_semaphore_t    semaphore = dispatch_semaphore_create(0);
            
            PHFetchOptions *userAlbumsOptions = [PHFetchOptions new];
            userAlbumsOptions.predicate = [NSPredicate predicateWithFormat:@"estimatedAssetCount > 0"];
            PHFetchResult *userAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumMyPhotoStream options:userAlbumsOptions];
            
            [userAlbums enumerateObjectsUsingBlock:^(PHAssetCollection *collection, NSUInteger idx1, BOOL *stop) {
                NSLog(@"album title %@", collection.localizedTitle);
                PHFetchOptions *fetchOptions = [PHFetchOptions new];
                fetchOptions.predicate = [NSPredicate predicateWithFormat:@"self.localIdentifier CONTAINS [cd] %@",assetURL.absoluteString];
                PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:fetchOptions];
                if ([assetsFetchResult count]>0) {
                    asset = [assetsFetchResult firstObject];
                    NSLog(@"assetsFetchResult:%@",asset);
                }
                dispatch_semaphore_signal(semaphore);
                
            }];
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            
        }
        [assets addObject:asset];
        checkNumberOfAssets();
    }
}


#pragma mark - Checking for Selection Limit

- (BOOL)isMinimumSelectionLimitFulfilled
{
    return (self.imagePickerController.minimumNumberOfSelection <= self.imagePickerController.selectedAssetURLs.count);
}

- (BOOL)isMaximumSelectionLimitReached
{
    NSUInteger minimumNumberOfSelection = MAX(1, self.imagePickerController.minimumNumberOfSelection);
    
    if (minimumNumberOfSelection <= self.imagePickerController.maximumNumberOfSelection) {
        return (self.imagePickerController.maximumNumberOfSelection <= self.imagePickerController.selectedAssetURLs.count);
    }
    
    return NO;
}

- (void)updateDoneButtonState
{
    NSInteger selectedCount = self.imagePickerController.selectedAssetURLs.count;
    
    // Validation
    NSString *rightBarItemTitle;
    
    NSBundle *bundle = self.imagePickerController.assetBundle;
    if (selectedCount>1) {
        rightBarItemTitle = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"完成(%d)", @"QBImagePicker", bundle, nil),selectedCount];
    }else{
        rightBarItemTitle = @"完成";
    }
    self.doneButton = [[UIBarButtonItem alloc] initWithTitle:rightBarItemTitle style:UIBarButtonItemStylePlain target:self action:@selector(done:)];
    [self.navigationItem setRightBarButtonItem:self.doneButton];
    
    
    self.doneButton.enabled = [self isMinimumSelectionLimitFulfilled];
}


#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.numberOfAssets;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    QBAssetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AssetCell" forIndexPath:indexPath];
    cell.tag = indexPath.item;
    cell.showsOverlayViewWhenSelected = self.imagePickerController.allowsMultipleSelection;
    
    // Image
    PHAsset *asset = self.assets[indexPath.item];
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.resizeMode = PHImageRequestOptionsResizeModeFast;
    
    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat dimension = 78.0f;
    CGSize size = CGSizeMake(dimension*scale, dimension*scale);
    
    
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:size contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage *result, NSDictionary *info) {
        cell.imageView.image = result;
    }];
    
    // Video indicator
    PHAssetMediaType assetType = [asset mediaType];
    
    if (assetType == PHAssetMediaTypeVideo) {
        cell.videoIndicatorView.hidden = NO;
        
        NSTimeInterval duration = [asset duration];
        NSInteger minutes = (NSInteger)(duration / 60.0);
        NSInteger seconds = (NSInteger)ceil(duration - 60.0 * (double)minutes);
        cell.videoIndicatorView.timeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
    } else {
        cell.videoIndicatorView.hidden = YES;
    }
    
    // Selection state
    NSURL *assetURL = [NSURL URLWithString:[asset localIdentifier]];
    
    if ([self.imagePickerController.selectedAssetURLs containsObject:assetURL]) {
        [cell setSelected:YES];
        [collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
    }
    
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if (kind == UICollectionElementKindSectionFooter) {
        UICollectionReusableView *footerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                                                                  withReuseIdentifier:@"FooterView"
                                                                                         forIndexPath:indexPath];
        
        // Number of assets
        UILabel *label = (UILabel *)[footerView viewWithTag:1];
        NSBundle *bundle = self.imagePickerController.assetBundle;
        NSUInteger numberOfPhotos = self.numberOfPhotos;
        NSUInteger numberOfVideos = self.numberOfVideos;
        
        switch (self.imagePickerController.filterType) {
            case QBImagePickerControllerFilterTypeNone:
            {
                NSString *format;
                if (numberOfPhotos == 1) {
                    if (numberOfVideos == 1) {
                        format = NSLocalizedStringFromTableInBundle(@"format_photo_and_video", @"QBImagePicker", bundle, nil);
                    } else {
                        format = NSLocalizedStringFromTableInBundle(@"format_photo_and_videos", @"QBImagePicker", bundle, nil);
                    }
                } else if (numberOfVideos == 1) {
                    format = NSLocalizedStringFromTableInBundle(@"format_photos_and_video", @"QBImagePicker", bundle, nil);
                } else {
                    format = NSLocalizedStringFromTableInBundle(@"format_photos_and_videos", @"QBImagePicker", bundle, nil);
                }
                
                label.text = [NSString stringWithFormat:format, numberOfPhotos, numberOfVideos];
            }
                break;
                
            case QBImagePickerControllerFilterTypePhotos:
            {
                NSString *key = (numberOfPhotos == 1) ? @"format_photo" : @"format_photos";
                NSString *format = NSLocalizedStringFromTableInBundle(key, @"QBImagePicker", bundle, nil);
                
                label.text = [NSString stringWithFormat:format, numberOfPhotos];
            }
                break;
                
            case QBImagePickerControllerFilterTypeVideos:
            {
                NSString *key = (numberOfVideos == 1) ? @"format_video" : @"format_videos";
                NSString *format = NSLocalizedStringFromTableInBundle(key, @"QBImagePicker", bundle, nil);
                
                label.text = [NSString stringWithFormat:format, numberOfVideos];
            }
                break;
        }
        
        return footerView;
    }
    
    return nil;
}


#pragma mark - UICollectionViewDelegate

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.imagePickerController.delegate respondsToSelector:@selector(qb_imagePickerController:shouldSelectAsset:)]) {
        return [self.imagePickerController.delegate qb_imagePickerController:self.imagePickerController shouldSelectAsset:nil];
    }
    
    if ([self isAutoDeselectEnabled]) {
        return YES;
    }
    
    return ![self isMaximumSelectionLimitReached];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    QBImagePickerController *imagePickerController = self.imagePickerController;
    NSMutableOrderedSet *selectedAssetURLs = imagePickerController.selectedAssetURLs;
    
    PHAsset *asset = self.assets[indexPath.item];
    NSURL *assetURL = [NSURL URLWithString:[asset localIdentifier]];
    
    if (imagePickerController.allowsMultipleSelection) {
        if ([self isAutoDeselectEnabled] && selectedAssetURLs.count > 0) {
            // Remove previous selected asset from set
            [imagePickerController willChangeValueForKey:@"selectedAssetURLs"];
            [selectedAssetURLs removeObjectAtIndex:0];
            [imagePickerController didChangeValueForKey:@"selectedAssetURLs"];
            
            // Deselect previous selected asset
            if (self.lastSelectedItemIndexPath) {
                [collectionView deselectItemAtIndexPath:self.lastSelectedItemIndexPath animated:NO];
            }
        }
        
        // Add asset to set
        [imagePickerController willChangeValueForKey:@"selectedAssetURLs"];
        [selectedAssetURLs addObject:assetURL];
        [imagePickerController didChangeValueForKey:@"selectedAssetURLs"];
        
        self.lastSelectedItemIndexPath = indexPath;
        
        [self updateDoneButtonState];
        
        if (imagePickerController.showsNumberOfSelectedAssets) {
            [self updateSelectionInfo];
            
            if (selectedAssetURLs.count == 1) {
                // Show toolbar
                [self.navigationController setToolbarHidden:NO animated:YES];
            }
        }
    } else {
        if ([imagePickerController.delegate respondsToSelector:@selector(qb_imagePickerController:didSelectAsset:)]) {
            [imagePickerController.delegate qb_imagePickerController:imagePickerController didSelectAsset:nil];
        }
    }
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!self.imagePickerController.allowsMultipleSelection) {
        return;
    }
    
    QBImagePickerController *imagePickerController = self.imagePickerController;
    NSMutableOrderedSet *selectedAssetURLs = imagePickerController.selectedAssetURLs;
    
    // Remove asset from set
    PHAsset *asset = self.assets[indexPath.item];
    NSURL *assetURL = [NSURL URLWithString:[asset localIdentifier]];
    
    [imagePickerController willChangeValueForKey:@"selectedAssetURLs"];
    [selectedAssetURLs removeObject:assetURL];
    [imagePickerController didChangeValueForKey:@"selectedAssetURLs"];
    
    self.lastSelectedItemIndexPath = nil;
    
    [self updateDoneButtonState];
    
    if (imagePickerController.showsNumberOfSelectedAssets) {
        [self updateSelectionInfo];
        
        if (selectedAssetURLs.count == 0) {
            // Hide toolbar
            [self.navigationController setToolbarHidden:YES animated:YES];
        }
    }
}


#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger numberOfColumns;
    if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation])) {
        numberOfColumns = self.imagePickerController.numberOfColumnsInPortrait;
    } else {
        numberOfColumns = self.imagePickerController.numberOfColumnsInLandscape;
    }
    
    CGFloat width = (CGRectGetWidth(self.view.frame) - 2.0 * (numberOfColumns + 1)) / numberOfColumns;
    
    return CGSizeMake(width, width);
}

@end

