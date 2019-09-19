//
//  PlayVideoViewController.m
//  VideoRecording
//
//  Created by lwq on 15/4/27.
//  Copyright (c) 2015年 lwq. All rights reserved.
//

#import "PlayVideoViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "UIView+Tools.h"


@interface PlayVideoViewController ()<UITextFieldDelegate>

@end

@implementation PlayVideoViewController
{

    AVPlayer *player;
    AVPlayerLayer *playerLayer;
    AVPlayerItem *playerItem;
    UIImageView* playImg;    
}



@synthesize videoURL;

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = NO;
}

-(BOOL)prefersStatusBarHidden {
    return YES;
}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.title = @"预览";
    
    //获取状态栏的rect
    float videoWidth = self.view.frame.size.width;
    float videoH = self.view.frame.size.width * (1280.0/720.0);
    AVAsset *movieAsset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
    playerItem = [AVPlayerItem playerItemWithAsset:movieAsset];
    player = [AVPlayer playerWithPlayerItem:playerItem];
    playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    
    if((([UIScreen mainScreen].bounds.size.height >= 812.0 ? 1 : 0))){//刘海手机
        playerLayer.frame = CGRectMake(0,88, videoWidth, videoH);
    }else{
        playerLayer.frame = CGRectMake(0,0, videoWidth, videoH);
    }
    playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer addSublayer:playerLayer];
    
    
    
    CGFloat btnY = CGRectGetMaxY(playerLayer.frame) - 100 + 76/2 - 25;
    
    UIButton *finishBt = [[UIButton alloc]initWithFrame:CGRectMake(videoWidth - 70,  btnY, 50, 50)];
    finishBt.adjustsImageWhenHighlighted = NO;
    [finishBt setTitle:@"确定" forState:UIControlStateNormal];
    [finishBt setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [finishBt addTarget:self action:@selector(finishBtTap) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:finishBt];
    
    
    UIButton *finishBt2 = [[UIButton alloc]initWithFrame:CGRectMake(20,  btnY, 50, 50)];
    finishBt2.adjustsImageWhenHighlighted = NO;
    [finishBt2 setTitle:@"重拍" forState:UIControlStateNormal];
    [finishBt2 setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [finishBt2 addTarget:self action:@selector(review) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:finishBt2];
    
    
    playImg = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, 40, 40)];
    playImg.center = CGPointMake(videoWidth/2, videoH/2);
    [playImg setImage:[UIImage imageNamed:@"vedioplay.png"]];
    [playerLayer addSublayer:playImg.layer];
    playImg.hidden = YES;
    UITapGestureRecognizer *playTap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playOrPause)];
    [self.view addGestureRecognizer:playTap];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playingEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    //从头开播
    [self pressPlayButton];
}



//重录
- (void)review
{
    [self.navigationController popViewControllerAnimated:YES];
}


//确定
- (void)finishBtTap
{
    if(_complateBlock){
        
        NSURL *url = self.videoURL;
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = TRUE;
        CMTime thumbTime = CMTimeMakeWithSeconds(0, 60);
        generator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
        AVAssetImageGeneratorCompletionHandler generatorHandler =
        ^(CMTime requestedTime, CGImageRef im, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error){
            if (result == AVAssetImageGeneratorSucceeded) {
                UIImage *thumbImg = [UIImage imageWithCGImage:im];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        _complateBlock(thumbImg,self.videoPath);
                    });
            }
        };
        [generator generateCGImagesAsynchronouslyForTimes:
         [NSArray arrayWithObject:[NSValue valueWithCMTime:thumbTime]] completionHandler:generatorHandler];
    }
}



-(void)playOrPause{
    if (playImg.isHidden) {
        playImg.hidden = NO;
        [player pause];
        
    }else{
        playImg.hidden = YES;
        [player play];
    }
}

- (void)pressPlayButton
{
    [playerItem seekToTime:kCMTimeZero];
    [player play];
}

- (void)playingEnd:(NSNotification *)notification
{
    if (playImg.isHidden) {
        [self pressPlayButton];
    }
}


-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"浏览视频退出");
}


@end
