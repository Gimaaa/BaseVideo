//
//  ViewController.m
//  LX
//
//  Created by 金正国 on 2019/9/19.
//  Copyright © 2019 金正国. All rights reserved.
//

#import "ViewController.h"
#import "ShootVideoViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 点一下屏幕就能启动了
    // 使用前记得去plist文件里写好 相机权限与麦克风权限 不然闪退
    // 图片自己去替换成高清的,我是随便放的 如:focus.png
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    
    ShootVideoViewController *vc = [ShootVideoViewController new];
   __weak typeof(self) weakSelf = self;
    vc.complateBlock = ^(UIImage *firstImage, NSString *videoPath) {
        //firstImage 视频的浏览第一贞图
        //videoPath
        //
        NSLog(@"%@",videoPath);
        [weakSelf.navigationController popToViewController:weakSelf animated:YES];
    };
    [self.navigationController pushViewController:vc animated:YES];
}
@end
