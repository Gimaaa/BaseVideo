//
//  PlayVideoViewController.h
//  VideoRecording
//
//  Created by lwq on 15/4/27.
//  Copyright (c) 2015年 lwq. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface PlayVideoViewController : UIViewController

@property(nonatomic,copy) NSURL * videoURL;
@property(nonatomic,copy) NSString * videoPath;

@property(nonatomic,copy)void(^complateBlock)(UIImage *firstImage,NSString *videoPath);

@end
