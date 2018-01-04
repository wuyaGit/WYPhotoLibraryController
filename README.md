# WYPhotoLibraryController

简单的对媒体资源库UI封装。可以根据需要，浏览并选取相册中的相片、视频或全部资源。

主要是对<Photos/Photos.h>库的使用。（备注：AssetsLibrary库在iOS9以后弃用，苹果建议使用Photos库。）

### 1.可以使用CocoaPods导入到项目

    pod 'WYPhotoLibraryController'
    
### 2.代码说明

获取系统相册

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
    
    
 获取资源图片
 
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
            
            
            
### 3.效果图

  ![示例1](https://github.com/wuyaGit/WYPhotoLibraryController/blob/master/ShotScreen/PhotoLibraryController.gif)

    
 
