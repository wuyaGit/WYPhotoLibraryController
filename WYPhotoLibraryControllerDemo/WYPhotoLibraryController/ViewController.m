//
//  ViewController.m
//  WYPhotoLibraryController
//
//  Created by Yangguangliang on 2017/12/27.
//  Copyright © 2017年 Yangguangliang. All rights reserved.
//

#import "ViewController.h"
#import "WYPhotoLibraryController.h"

@interface ViewController () <WYPhotoLibraryControllerDelegate, UIScrollViewDelegate>

@property (weak, nonatomic) IBOutlet UILabel *pageIndex;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

@property (nonatomic, strong) WYPhotoLibraryController *photoLibraryController;
@property (nonatomic, strong) NSArray *photos;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onTouchOpenLibrary:(id)sender {
    [self presentViewController:self.photoLibraryController animated:YES completion:nil];
}

- (WYPhotoLibraryController *)photoLibraryController {
    if (_photoLibraryController == nil) {
        _photoLibraryController = [[WYPhotoLibraryController alloc] init];
        _photoLibraryController.photoFilterType = WYPhotoFilterAll;
        _photoLibraryController.libraryDelegate = self;
    }
    
    return _photoLibraryController;
}

#pragma mark - Private

- (void)layoutScrollView {
    for (UIView *view in self.scrollView.subviews) {
        if ([view isKindOfClass:[UIImageView class]]) {
            [view removeFromSuperview];
        }
    }
    
    __weak typeof(&*self) weakSelf = self;
    __block NSInteger index = 0;
    for (WYPhoto *photo in self.photos) {
        [photo setGetFullImage:^(UIImage *image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                imageView.frame = CGRectMake(self.view.frame.size.width * index, 0, self.view.frame.size.width, self.view.frame.size.height);
                imageView.contentMode = UIViewContentModeScaleAspectFit;
                [weakSelf.scrollView addSubview:imageView];
                [weakSelf.scrollView setContentSize:CGSizeMake(self.view.frame.size.width * (index + 1), self.view.frame.size.height)];
                
                index++;
            });
        }];
        
    }
}

#pragma mark - Rotation

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    
    if (self.photos.count) {
        [self layoutScrollView];
    }
}

#pragma mark - WYPhotoLibraryControllerDelegate

- (void)photoLibraryController:(WYPhotoLibraryController *)library didFinishPickingPhotos:(NSArray *)photos {
    [library dismissViewControllerAnimated:YES completion:nil];
    
    self.photos = photos;
    if (photos.count) {
        [self layoutScrollView];
        self.pageIndex.text = [NSString stringWithFormat:@"1/%@", @(photos.count)];
    }
}

- (void)photoLibraryControllerDidCancel:(WYPhotoLibraryController *)library {
    [library dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Scrol view delegate

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    NSInteger index = scrollView.contentOffset.x / scrollView.frame.size.width + 1;
    
    self.pageIndex.text = [NSString stringWithFormat:@"%@/%@", @(index), @(_photos.count)];
}

@end
