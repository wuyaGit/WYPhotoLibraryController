//
//  WYPhotoLibraryController.h
//  ExtractVideos
//
//  Created by Yangguangliang on 2017/12/26.
//  Copyright © 2017年 YANGGL. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, WYPhotoFilterType) {
    WYPhotoFilterAllImage   = 0,
    WYPhotoFilterAllVideo,
    WYPhotoFilterAll
};

typedef NS_ENUM(NSInteger, WYPhotoMediaType) {
    WYPhotoMediaTypeUnknown   = 0,
    WYPhotoMediaTypeImage,
    WYPhotoMediaTypeVideo,
    WYPhotoMediaTypeAudio
};

@interface WYPhoto: NSObject

@property (nonatomic, strong) id asset;
@property (nonatomic, assign) WYPhotoMediaType mediaType;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSTimeInterval duration;      //视频时长
@property (nonatomic, getter=isSelected, assign) BOOL selected;

@property (nonatomic, copy) void (^getThumbnail)(UIImage *);
@property (nonatomic, copy) void (^getFullImage)(UIImage *);
@property (nonatomic, copy) void (^getFileSize)(NSInteger);

@property (nonatomic, copy) void (^getNetworkProgressHandler)(double, NSError *, BOOL *, NSDictionary *);

@end

@protocol WYPhotoLibraryControllerDelegate;
@interface WYPhotoLibraryController : UINavigationController

@property (nonatomic, assign) WYPhotoFilterType photoFilterType;
@property (nonatomic, weak) id<WYPhotoLibraryControllerDelegate> libraryDelegate;

@end

@protocol WYPhotoLibraryControllerDelegate<NSObject>
@optional

- (void)photoLibraryController:(WYPhotoLibraryController *)library didFinishPickingPhotos:(NSArray *)photos;
- (void)photoLibraryControllerDidCancel:(WYPhotoLibraryController *)library;
@end

@interface WYPhotoGroupViewController: UITableViewController

@end

@class WYPhotoGroup;
@interface WYPhotoViewController: UIViewController
@property (nonatomic, strong) WYPhotoGroup *group;

@end
