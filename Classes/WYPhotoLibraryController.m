//
//  WYPhotoLibraryController.m
//  ExtractVideos
//
//  Created by Yangguangliang on 2017/12/26.
//  Copyright © 2017年 YANGGL. All rights reserved.
//

#import "WYPhotoLibraryController.h"
#import <Photos/Photos.h>

#define kThumbImageHeight    80.0f
#define kThumbImageSize      CGSizeMake(kThumbImageHeight, kThumbImageHeight)

#define kMinimumInteritemSpacing        2.f
#define kMinimumLineSpacing              2.f


@interface NSDate (TimeInterval)

+ (NSString *)timeDescriptionOfTimeInterval:(NSTimeInterval)timeInterval;

@end

@implementation NSDate (TimeInterval)

+ (NSDateComponents *)componetsWithTimeInterval:(NSTimeInterval)timeInterval {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSDate *date1 = [[NSDate alloc] init];
    NSDate *date2 = [[NSDate alloc] initWithTimeInterval:timeInterval sinceDate:date1];
    
    unsigned int unitFlags =
    NSCalendarUnitSecond | NSCalendarUnitMinute | NSCalendarUnitHour |
    NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear;
    
    return [calendar components:unitFlags
                       fromDate:date1
                         toDate:date2
                        options:0];
}

+ (NSString *)timeDescriptionOfTimeInterval:(NSTimeInterval)timeInterval {
    NSDateComponents *components = [self.class componetsWithTimeInterval:timeInterval];
    NSInteger roundedSeconds = lround(timeInterval - (components.hour * 60) - (components.minute * 60 * 60));
    
    if (components.hour > 0){
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)components.hour, (long)components.minute, (long)roundedSeconds];
    }else{
        return [NSString stringWithFormat:@"%ld:%02ld", (long)components.minute, (long)roundedSeconds];
    }
}

@end


@interface WYPhotoGroup: NSObject

@property (nonatomic, strong) id assetCollection;
@property (nonatomic, strong) id fetchResult;
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, copy) NSString *groupName;
@property (nonatomic, copy) void (^getThumbnail)(UIImage *);

- (void)enumerateObjectsUsingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block;
@end
@interface WYPhotoGroup()

@property (nonatomic, strong) UIImage *cacheThumbImage;
@end

@implementation WYPhotoGroup

- (void)setGetThumbnail:(void (^)(UIImage *))getThumbnail {
    _getThumbnail = getThumbnail;
    
    if (_cacheThumbImage) {
        _getThumbnail(_cacheThumbImage);
        return;
    }
    
    if ([_assetCollection isKindOfClass:[PHCollection class]]) {
        if (!_fetchResult) {
            PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
            _fetchResult = [PHCollection fetchCollectionsInCollectionList:_assetCollection options:fetchOptions];
        }
        
        PHFetchResult *tmpFetchResult = _fetchResult;
        PHAsset *tmpAsset = [tmpFetchResult objectAtIndex:tmpFetchResult.count - 1];
        
        PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
        requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
        requestOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
        [[PHImageManager defaultManager] requestImageForAsset:tmpAsset targetSize:CGSizeMake(200, 200) contentMode:PHImageContentModeAspectFill options:requestOptions resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
            BOOL download = ![info[PHImageCancelledKey] boolValue] && ![info[PHImageErrorKey] boolValue] && ![info[PHImageResultIsDegradedKey] boolValue];
            
            if (download) {
                float scale = result.size.height / kThumbImageHeight;
                _cacheThumbImage = [UIImage imageWithCGImage:result.CGImage scale:scale orientation:UIImageOrientationUp];
                _getThumbnail(_cacheThumbImage);
            }
        }];
    }
}

- (void)enumerateObjectsUsingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block {
    if (_assetCollection) {
        if ([_assetCollection isKindOfClass:[PHCollection class]]) {
            if (!_fetchResult) {
                PHFetchOptions *tmpFetchOptions = [[PHFetchOptions alloc] init];
                _fetchResult = [PHCollection fetchCollectionsInCollectionList:_assetCollection options:tmpFetchOptions];
            }
            [(PHFetchResult *) _fetchResult enumerateObjectsUsingBlock:block];
        }
    }
}

@end

@interface WYPhoto()

@property (nonatomic, strong) UIImage *cacheThumbImage;
@property (nonatomic, strong) UIImage *cacheFullImage;
@property (nonatomic, assign) NSInteger cacheFileSize;

@end

@implementation WYPhoto

- (WYPhotoMediaType)mediaType {
    if ([_asset isKindOfClass:[PHAsset class]]) {
        switch ([(PHAsset *)_asset mediaType]) {
            case PHAssetMediaTypeImage:
                return WYPhotoMediaTypeImage;
                break;
            case PHAssetMediaTypeVideo:
                return WYPhotoMediaTypeVideo;
                break;
            case PHAssetMediaTypeAudio:
                return WYPhotoMediaTypeAudio;
                break;
            default:
                break;
        }
    }
    return WYPhotoMediaTypeUnknown;
}

- (NSString *)name {
    if ([_asset isKindOfClass:[PHAsset class]]) {
        return [_asset valueForKey:@"filename"];
    }
    return @"unknown.JPG";
}

- (NSTimeInterval)duration {
    if ([_asset isKindOfClass:[PHAsset class]]) {
        return [(PHAsset *)_asset duration]; 
    }
    return 0;
}

- (void)setGetFileSize:(void (^)(NSInteger))getFileSize {
    _getFileSize = getFileSize;
    
    if (_asset) {
        if (_cacheFileSize > 0) {
            _getFileSize(_cacheFileSize);
            return;
        }
        
        if (self.mediaType == WYPhotoMediaTypeVideo) {
            PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
            [[PHImageManager defaultManager] requestAVAssetForVideo:_asset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
                if ([asset isKindOfClass:[AVURLAsset class]]) {
                    AVURLAsset *urlAsset = (AVURLAsset *)asset;
                    NSNumber *size;
                    
                    [urlAsset.URL getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
                    _cacheFileSize = [size floatValue]; // _cacheFileSize / (1024 * 1024) 转MB
                    _getFileSize(_cacheFileSize);
                }
            }];
        }else {
            [[PHImageManager defaultManager] requestImageDataForAsset:_asset options:nil resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
                _cacheFileSize = imageData.length; // _cacheFileSize / (1024 * 1024) 转MB
                _getFileSize(_cacheFileSize);
            }];
        }
    }
}


- (void)setGetThumbnail:(void (^)(UIImage *))getThumbnail {
    _getThumbnail = getThumbnail;
    
    if (_asset) {
        if (_cacheThumbImage) {
            _getThumbnail(_cacheThumbImage);
            return;
        }
        
        if ([_asset isKindOfClass:[PHAsset class]]) {
            PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
            requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
            requestOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
            [[PHImageManager defaultManager] requestImageForAsset:_asset targetSize:CGSizeMake(200, 200) contentMode:PHImageContentModeAspectFill options:requestOptions resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                BOOL download = ![info[PHImageCancelledKey] boolValue] && ![info[PHImageErrorKey] boolValue] && ![info[PHImageResultIsDegradedKey] boolValue];
                
                if (download) {
                    _cacheThumbImage = result;
                    _getThumbnail(_cacheThumbImage);
                }
            }];
        }
    }
}

- (void)setGetFullImage:(void (^)(UIImage *))getFullImage {
    _getFullImage = getFullImage;
    
    if (_asset) {
        if (_cacheFullImage) {
            _getFullImage(_cacheFullImage);
            return;
        }
        
        if ([_asset isKindOfClass:[PHAsset class]]) {
            PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
            requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
            requestOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
            
            CGFloat photoWidth = [UIScreen mainScreen].bounds.size.width;
            CGFloat aspectRatio = ((PHAsset*)_asset).pixelWidth / (CGFloat)((PHAsset*)_asset).pixelHeight;
            CGFloat multiple = [UIScreen mainScreen].scale;
            CGFloat pixelWidth = photoWidth * multiple;
            CGFloat pixelHeight = pixelWidth / aspectRatio;
            
            //允许从iCloud上下载
            requestOptions.networkAccessAllowed = YES;
            requestOptions.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
                if (self.getNetworkProgressHandler) {
                    self.getNetworkProgressHandler(progress, error, stop, info);
                }
            };
            
            [[PHImageManager defaultManager] requestImageForAsset:_asset targetSize:CGSizeMake(pixelWidth, pixelHeight) contentMode:PHImageContentModeAspectFill options:requestOptions resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                BOOL download = ![info[PHImageCancelledKey] boolValue] && ![info[PHImageErrorKey] boolValue] && ![info[PHImageResultIsDegradedKey] boolValue];
                
                if (download) {
                    _cacheFullImage = result;
                    _getFullImage(_cacheFullImage);
                }
            }];
        }
    }
}


@end

#pragma mark - WYPhotoLibraryController

@implementation WYPhotoLibraryController

- (instancetype)init {
    WYPhotoGroupViewController *rootViewController = [[WYPhotoGroupViewController alloc] init];
    if (self = [super initWithRootViewController:rootViewController]) {
        
    }
    
    return self;
}

@end

#pragma mark - WYPhotoGroupViewCell

@interface WYPhotoGroupViewCell: UITableViewCell

@property (nonatomic, strong) WYPhotoGroup *photoGroup;
@end

@implementation WYPhotoGroupViewCell

- (void)setPhotoGroup:(WYPhotoGroup *)photoGroup {
    _photoGroup = photoGroup;
    
    __weak typeof(self) weakSelf = self;
    [_photoGroup setGetThumbnail:^(UIImage *image) {
        weakSelf.imageView.image = image;
        [weakSelf setNeedsLayout];
    }];
    
    self.textLabel.text = photoGroup.groupName;
    self.detailTextLabel.text = [NSString stringWithFormat:@"%zi", photoGroup.count];
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

@end

#pragma mark - WYPhotoGroupViewController

@interface WYPhotoGroupViewController ()

@property (nonatomic, strong) NSMutableArray *photoGroups;
@end

@implementation WYPhotoGroupViewController

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.photoGroups.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    WYPhotoGroupViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[WYPhotoGroupViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    cell.photoGroup = self.photoGroups[indexPath.row];
    
    return cell;
}

#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kThumbImageHeight + 10;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    WYPhotoViewController *viewController = [[WYPhotoViewController alloc] init];
    viewController.group = self.photoGroups[indexPath.row];
    
    [self.navigationController pushViewController:viewController animated:YES];
}

#pragma mark - Cycle life

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupView];
    [self setupBarButtonItem];
    [self setupGroup];
}

#pragma mark - Setup

- (void)setupView {
    self.title = NSLocalizedString(@"相册", nil);
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

- (void)setupBarButtonItem {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"取消", nil)
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(dismiss:)];
}

- (void)setupGroup {
    if (self.photoGroups) {
        [self.photoGroups removeAllObjects];
    }else {
        self.photoGroups = [[NSMutableArray alloc] init];
    }
    
    __block BOOL showAlbums = YES;
    WYPhotoLibraryController *library = (WYPhotoLibraryController *)self.navigationController;
    
    //iOS8以后,使用PHAsset
    PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
    
    //获取所有系统相册
    PHFetchResult *smartAlbumsFetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:fetchOptions];
    //遍历相册
    [smartAlbumsFetchResult enumerateObjectsUsingBlock:^(PHAssetCollection *collection, NSUInteger idx, BOOL *stop) {
        showAlbums = NO;
        PHFetchOptions *fetchOptionsAlbums = [[PHFetchOptions alloc] init];
        
        switch (library.photoFilterType) {
            case WYPhotoFilterAllImage:
                fetchOptionsAlbums.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
                break;
            case WYPhotoFilterAllVideo:
                fetchOptionsAlbums.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeVideo];
                break;
            default:
                break;
        }
        
        //有可能是PHCollectionList，会造成crash，过滤掉
        if ([collection isKindOfClass:[PHAssetCollection class]]) {
            //从相册中获取数据
            PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:fetchOptionsAlbums];
            //去掉视频、最近删除、最近添加
            if (![collection.localizedTitle isEqualToString:@"Recently Deleted"] &&
                ![collection.localizedTitle isEqualToString:@"Recently Added"] &&
                ![collection.localizedTitle isEqualToString:@"Videos"]) {
                if (fetchResult.count > 0) {
                    WYPhotoGroup *group = [[WYPhotoGroup alloc] init];
                    group.groupName = collection.localizedTitle;
                    group.count = fetchResult.count;
                    group.assetCollection = collection;
                    group.fetchResult = fetchResult;
                    [self.photoGroups addObject:group];
                }
            }
        }
    }];
    
    //获取所有自定义相册
    PHFetchResult *userAlbumsFetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:fetchOptions];
    //遍历相册
    [userAlbumsFetchResult enumerateObjectsUsingBlock:^(PHAssetCollection *collection, NSUInteger idx, BOOL *stop) {
        showAlbums = NO;
        PHFetchOptions *fetchOptionsAlbums = [[PHFetchOptions alloc] init];
        
        switch (library.photoFilterType) {
            case WYPhotoFilterAllImage:
                fetchOptionsAlbums.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
                break;
            case WYPhotoFilterAllVideo:
                fetchOptionsAlbums.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeVideo];
                break;
            default:
                break;
        }
        
        PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:fetchOptionsAlbums];
        if (fetchResult.count > 0) {
            WYPhotoGroup *group = [[WYPhotoGroup alloc] init];
            group.groupName = collection.localizedTitle;
            group.count = fetchResult.count;
            group.assetCollection = collection;
            group.fetchResult = fetchResult;
            [self.photoGroups addObject:group];
        }
    }];

    if (showAlbums) {
        [self noAllowed];
    }else {
        [self reloadData];
    }
}

#pragma mark - No allowed OR NO Asset

- (void)noAllowed {
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    NSString *tipTextWhenNoPhotosAuthorization = [NSString stringWithFormat:NSLocalizedString(@"请在设备的\"设置-隐私-照片\"选项中，允许%@访问您的手机相册。", nil), appName];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"此应用没有权限访问相册", nil)
                                                                             message:tipTextWhenNoPhotosAuthorization
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *qdAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"确定", nil) style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:qdAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)noAssets {
    WYPhotoLibraryController *library = (WYPhotoLibraryController *)self.navigationController;
    NSString *title = NSLocalizedString(@"没有照片或视频", nil);
    if (library.photoFilterType == WYPhotoFilterAllVideo) {
        title = NSLocalizedString(@"没有视频", nil);
    }else if (library.photoFilterType == WYPhotoFilterAllImage) {
        title = NSLocalizedString(@"没有照片", nil);
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:NSLocalizedString(@"您可以使用 iTunes 将照片和视频\n同步到 iPhone。", nil)
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *qdAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"确定", nil) style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:qdAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - Action

- (void)dismiss:(id)sender {
    WYPhotoLibraryController *library = (WYPhotoLibraryController *)self.navigationController;
    
    if (library.libraryDelegate && [library.libraryDelegate respondsToSelector:@selector(photoLibraryControllerDidCancel:)]) {
        [library.libraryDelegate photoLibraryControllerDidCancel:library];
    }
}

- (void)reloadData {
    if (self.photoGroups.count == 0) {
        [self noAssets];
    }
    
    [self.tableView reloadData];
}

@end

#pragma mark - WYCollectionViewCell

@interface WYCollectionViewCell: UICollectionViewCell

@property (nonatomic, strong) WYPhoto *photo;
@property (nonatomic, strong) UIButton *tapButton;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *bottomView;

@property (nonatomic, strong) UIImageView *videoIcon;
@property (nonatomic, strong) UILabel *fileLength;

@property (nonatomic, copy) void (^pickingPhoto)(WYPhoto *);
@end

@implementation WYCollectionViewCell

//刷新视图
- (void)setNeedsLayout {
    [super setNeedsLayout];
    
    self.imageView.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    self.tapButton.frame = CGRectMake(self.frame.size.width - 35, 5, 30, 30);
    self.bottomView.frame = CGRectMake(0, self.frame.size.height - 22, self.frame.size.width, 22);
    self.fileLength.frame = CGRectMake(0, 0, self.frame.size.width - 4, 22);
}

- (void)setPhoto:(WYPhoto *)photo {
    _photo = photo;
    
    self.imageView.image = _photo.cacheThumbImage;
    self.tapButton.selected = _photo.selected;

    __weak typeof(self) weakSelf = self;
    [_photo setGetThumbnail:^(UIImage *image) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.imageView.image = image;
        });
    }];
    
    if (_photo.mediaType == WYPhotoMediaTypeVideo) {
        self.bottomView.hidden = NO;
    }else {
        self.bottomView.hidden = YES;
    }
    
//    [_photo setGetFileSize:^(NSInteger fileSize) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            weakSelf.fileLength.text = [NSString stringWithFormat:@"%.1fMB", fileSize / (1024 * 1024.0)];
//        });
//    }];
    
    self.fileLength.text = [NSDate timeDescriptionOfTimeInterval:_photo.duration];
}

- (UIImageView *)imageView {
    if (_imageView == nil) {
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.clipsToBounds = YES;
        [self.contentView addSubview:imageView];
        _imageView = imageView;
    }
    
    return _imageView;
}

- (UIButton *)tapButton {
    if (_tapButton == nil) {
        UIButton *tapButton = [[UIButton alloc] init];
        tapButton.frame = CGRectMake(self.frame.size.width - 35, 5, 30, 30);
        [tapButton setUserInteractionEnabled:NO];
        [tapButton setImage:[UIImage new] forState:UIControlStateNormal];
        [tapButton setImage:[UIImage imageWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"WYPhotoLibrary.bundle/Images/PhotoChecked@2x.png"]] forState:UIControlStateSelected];
        [self.contentView addSubview:tapButton];
        _tapButton = tapButton;
    }
    return _tapButton;
}

- (UIView *)bottomView {
    if (_bottomView == nil) {
        UIView *bottomView = [[UIView alloc] init];
        bottomView.frame = CGRectMake(0, self.frame.size.height - 22, self.frame.size.width, 22);
        bottomView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.6];
        [self.contentView addSubview:bottomView];
        
        [bottomView addSubview:self.videoIcon];
        [bottomView addSubview:self.fileLength];

        _bottomView = bottomView;
    }
    return _bottomView;
}

- (UILabel *)fileLength {
    if (_fileLength == nil) {
        UILabel *fileLength = [[UILabel alloc] init];
        fileLength.font = [UIFont boldSystemFontOfSize:10];
        fileLength.frame = CGRectMake(0, 0, self.frame.size.width - 4, 22);
        fileLength.textColor = [UIColor whiteColor];
        fileLength.textAlignment = NSTextAlignmentRight;
        _fileLength = fileLength;
    }
    return _fileLength;
}

- (UIImageView *)videoIcon {
    if (_videoIcon == nil) {
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.frame = CGRectMake(6, 0, 18, 22);
        imageView.image = [UIImage imageWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"WYPhotoLibrary.bundle/Images/PhotoVideoIcon@2x.png"]];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.clipsToBounds = YES;
        _videoIcon = imageView;
    }
    
    return _videoIcon;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.tapButton.selected = !self.tapButton.selected;
    self.photo.selected = self.tapButton.selected;
    
    if (self.pickingPhoto) {
        self.pickingPhoto(_photo);
    }
}

@end

#pragma mark - WYCollectionHeaderReusableView WYCollectionFooterReusableView

@interface WYCollectionHeaderReusableView : UICollectionReusableView

@end

@implementation WYCollectionHeaderReusableView

@end

@interface WYCollectionFooterReusableView : UICollectionReusableView

@end

@implementation WYCollectionFooterReusableView

@end

#pragma mark - WYPhotoViewController

@interface WYPhotoViewController ()<UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray *photos;
@property (nonatomic, strong) NSMutableArray *seletedPhotos;

@end

@implementation WYPhotoViewController

#pragma mark - Collection view data source

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.photos.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    WYCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    cell.photo = self.photos[indexPath.item];
    
    __weak typeof(*&self) weakSelf = self;
    cell.pickingPhoto = ^(WYPhoto *photo) {
        if (photo.isSelected) {
            [weakSelf.seletedPhotos addObject:photo];
        }else {
            [weakSelf.seletedPhotos removeObject:photo];
        }
        [weakSelf realodTitleWithItems];
    };
    
    [cell setNeedsLayout];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath{
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        // 头部
        WYCollectionHeaderReusableView *view = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"header" forIndexPath:indexPath];
        view.backgroundColor = [UIColor orangeColor];
        
        return view;
    }else {
        // 底部
        WYCollectionFooterReusableView *view = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"footer" forIndexPath:indexPath];
        view.backgroundColor = [UIColor blueColor];
        
        return view;
    }
}

#pragma mark - Collection view delegate flowLayout

//Cell设置宽高
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([[UIDevice currentDevice] orientation] == UIDeviceOrientationPortrait ||
        [[UIDevice currentDevice] orientation] == UIDeviceOrientationPortraitUpsideDown) {
        return CGSizeMake((self.view.frame.size.width - kMinimumLineSpacing*5) / 4, (self.view.frame.size.width - kMinimumLineSpacing*5) / 4);
    }else {
        return CGSizeMake((self.view.frame.size.width - kMinimumLineSpacing*6) / 5, (self.view.frame.size.width - kMinimumLineSpacing*6) / 5);
    }
}

//Header设置宽高
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return CGSizeMake(self.view.frame.size.width, 0.001);
}

//Footer设置宽高
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section {
    return CGSizeMake(self.view.frame.size.width, 0.001);
}

//Section设置 四边间距
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    
    //分别为上、左、下、右
    return UIEdgeInsetsMake(10, kMinimumInteritemSpacing, 10, kMinimumInteritemSpacing);
    
}

//两行cell设置 间距（上下行cell的间距）
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    
    return kMinimumLineSpacing;
}

//两个cell设置 间距（同一行的cell的间距）
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return kMinimumInteritemSpacing;
}

#pragma mark - Collection view delegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {

}

#pragma mark - Life cycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupView];
    [self setupBarButtonItem];
    [self setupData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)realodTitleWithItems {
    if (self.seletedPhotos.count == 0) {
        self.title = self.group.groupName;
        return;
    }
    
    BOOL photoSelected = NO;
    BOOL videoSelected  = NO;
    
    for (WYPhoto *photo in _seletedPhotos) {
        if (photo.mediaType == WYPhotoMediaTypeImage) {
            photoSelected  = YES;
        }
        if (photo.mediaType == WYPhotoMediaTypeVideo) {
            videoSelected   = YES;
        }
        if (photoSelected && videoSelected) {
            break;
        }
    }
    
    NSString *title;
    if (photoSelected && videoSelected) {
        title = NSLocalizedString(@"已选择 %ld 个项目", nil);
    }else if (photoSelected) {
        title = NSLocalizedString(@"已选择 %ld 张照片", nil);
    }else if (videoSelected) {
        title = NSLocalizedString(@"已选择 %ld 部视频", nil);
    }
    self.title = [NSString stringWithFormat:title, (long)_seletedPhotos.count];
}

#pragma mark - Rotation

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    
    //[self.collectionView setNeedsLayout]; 只刷新视图大小，不重载视图
    [self.collectionView reloadData];
}

#pragma mark - Setup

- (void)setupView {
    self.title = self.group.groupName;
    
    [self.view addSubview:self.collectionView];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSDictionary *views = @{@"collectionView": self.collectionView};
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[collectionView]|" options:0 metrics:nil views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[collectionView]|" options:0 metrics:nil views:views]];
    
    // 注册collectionViewcell:WWCollectionViewCell是我自定义的cell的类型
    [self.collectionView registerClass:[WYCollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
    // 注册collectionView头部的view
    [self.collectionView registerClass:[WYCollectionHeaderReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"header"];
    // 注册collectionview底部的view
    [self.collectionView registerClass:[WYCollectionFooterReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"footer"];
}

- (void)setupBarButtonItem {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"完成", nil)
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(finished:)];
}

- (void)setupData {
    __weak typeof(self) weakSelf = self;
    [self.group enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (obj) {
            WYPhoto *photo = [[WYPhoto alloc] init];
            photo.asset = obj;
            
            [weakSelf.photos addObject:photo];
        }
        
        if (weakSelf.group.count-1 ==idx) {
            [weakSelf.collectionView reloadData];
        }
    }];
}

#pragma mark - Actions

- (void)finished:(id)sender {
    WYPhotoLibraryController *library = (WYPhotoLibraryController *)self.navigationController;
    
    if (library.libraryDelegate && [library.libraryDelegate respondsToSelector:@selector(photoLibraryController:didFinishPickingPhotos:)]) {
        [library.libraryDelegate photoLibraryController:library didFinishPickingPhotos:self.seletedPhotos];
    }
}

#pragma mark - Getter

- (UICollectionView *)collectionView {
    if (_collectionView == nil) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        // 设置collectionView的滚动方向，需要注意的是如果使用了collectionview的headerview或者footerview的话， 如果设置了水平滚动方向的话，那么就只有宽度起作用了了
        [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
        // layout.minimumInteritemSpacing = 10;// 垂直方向的间距
        // layout.minimumLineSpacing = 10; // 水平方向的间距
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        _collectionView.alwaysBounceVertical = YES;
        _collectionView.backgroundColor = [UIColor whiteColor];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
    }
    
    return _collectionView;
}

- (NSMutableArray *)photos {
    if (_photos == nil) {
        _photos = [[NSMutableArray alloc] init];
    }
    
    return _photos;
}

- (NSMutableArray *)seletedPhotos {
    if (_seletedPhotos == nil) {
        _seletedPhotos = [[NSMutableArray alloc] init];
    }
    
    return _seletedPhotos;
}

@end
