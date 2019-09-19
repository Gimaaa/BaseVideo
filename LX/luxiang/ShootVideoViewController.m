//
//  ShootVideoViewController.m
//  VideoRecording
//
//  Created by lwq on 2015/7/17.
//  Copyright © 2015年 lwq. All rights reserved.
//

#import "ShootVideoViewController.h"
#import "PlayVideoViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

#define TIMER_INTERVAL 0.05
#define VIDEO_FOLDER @"videoFolder"
//
#import "XLCircleProgress.h"



typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

@interface ShootVideoViewController ()<AVCaptureFileOutputRecordingDelegate>//视频文件输出代理
{
    XLCircleProgress *_circle;
}

@property (strong,nonatomic) AVCaptureSession           *captureSession;//负责输入和输出设置之间的数据传递
@property (strong,nonatomic) AVCaptureDeviceInput       *captureDeviceInput;//负责从AVCaptureDevice获得输入数据
@property (strong,nonatomic) AVCaptureMovieFileOutput   *captureMovieFileOutput;//视频输出流
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;//相机拍摄预览图层
@property (strong,nonatomic) UIView                     *viewContainer;//视频容器
@property (strong,nonatomic) UIImageView                *focusCursor;//聚焦光标
@property (strong,nonatomic) UIView                     *warningSuperView;//提示语言
@property (strong,nonatomic) UIView                     *waitingngSuperView;//提示语言
@property (strong,nonatomic) UILabel                    *lastTimeLabel;//倒计时
@property (assign,nonatomic) BOOL                       stopAndEnd;//终止录制;
@end

@implementation ShootVideoViewController{
    
    NSMutableArray* urlArray;//保存视频片段的数组
    
    float currentTime; //当前视频长度
    
    NSTimer *countTimer; //计时器
    
    float preLayerWidth;//镜头宽
    float preLayerHeight;//镜头高
    float preLayerHWRate; //高，宽比
    
    UIButton *shootBt;//录制按钮
    UIButton *remakeBt;//重置
    UIButton *quitBt;//退出
    
    UIButton* flashBt;//闪光灯
    UIButton* cameraBt;//切换摄像头
    
}
@synthesize totalTime;
@synthesize minTime;

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = NO;
    
    [self.captureSession stopRunning];
    
    //还原数据-----------
    [self deleteAllVideos];
    
    //进度还原
    currentTime = 0;
    _circle.progress = 0.0;
    
    //按钮还原
    [self shootBtnReset];
    
    //按钮重拍隐藏
    remakeBt.hidden = YES;
    
    //计时器停止
    [self stopTimer];
    
    //终止按钮点击记录清空
    self.stopAndEnd = NO;
    
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    self.navigationController.navigationBarHidden = YES;
    [self.captureSession startRunning];
}



-(BOOL)prefersStatusBarHidden {
    return YES;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    self.title = @"视频录制";
    
    //视频最大时长 默认45秒
    if (totalTime==0) {
        totalTime =45;
    }
    //视频最小时长 默认10秒
    if(minTime == 0){
        minTime = 10;
    }
    
    urlArray = [[NSMutableArray alloc]init];
    
    preLayerWidth = SCREEN_WIDTH;
    preLayerHeight = SCREEN_WIDTH * (1280.0/720.0);
    
    preLayerHWRate = preLayerHeight/preLayerWidth;
    
    //创建根目录文件夹
    [self createVideoFolderIfNotExist];
    
    //创建UI
    [self initCapture];
}

-(void)initCapture{
    
    //获取状态栏的rect

    
    //1:视频浏览界面
    if(([UIScreen mainScreen].bounds.size.height >= 812.0 ? 1 : 0)){//刘海手机
        self.viewContainer = [[UIView alloc]initWithFrame:CGRectMake(0,88, preLayerWidth, preLayerHeight)];
    }else{
        self.viewContainer = [[UIView alloc]initWithFrame:CGRectMake(0,0, preLayerWidth, preLayerHeight)];
    }

    [self.view addSubview:self.viewContainer];

    
    //2:开始按钮
    CGFloat btnWH = 76.0;
    _circle = [[XLCircleProgress alloc]initWithFrame:CGRectMake(SCREEN_WIDTH/2.0 - btnWH/2.0, CGRectGetMaxY(self.viewContainer.frame) - 100, 76, 76)];
    shootBt = [[UIButton alloc]initWithFrame:CGRectMake(9.5,9.5, 57, 57)];
    shootBt.backgroundColor = [UIColor colorWithRed:241/255.0 green:65/255.0 blue:58/255.0 alpha:1.0];
    [shootBt addTarget:self action:@selector(shootButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [shootBt makeCornerRadius:57/2 borderColor:[UIColor clearColor] borderWidth:0];
    [_circle addSubview:shootBt];
    [self.view addSubview:_circle];
    
    
    //4:重拍按钮
    remakeBt = [[UIButton alloc]initWithFrame:CGRectMake(SCREEN_WIDTH * 2.0/4.0 - 100, CGRectGetMinY(_circle.frame) + btnWH/2 - 25, 50, 50)];
    remakeBt.adjustsImageWhenHighlighted = NO;
    [remakeBt setTitle:@"重拍" forState:UIControlStateNormal];
    [remakeBt addTarget:self action:@selector(reset) forControlEvents:UIControlEventTouchUpInside];
    remakeBt.hidden = YES;
    [self.view addSubview:remakeBt];
    
    //4:退出按钮
    quitBt = [[UIButton alloc]initWithFrame:CGRectMake(20, CGRectGetMaxY(_circle.frame) - btnWH/2 - 25, 50, 50)];
    quitBt.adjustsImageWhenHighlighted = NO;
    [quitBt setTitle:@"退出" forState:UIControlStateNormal];
    [quitBt addTarget:self action:@selector(quit) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:quitBt];
    
    //5:镜头转换按钮
    cameraBt = [[UIButton alloc]initWithFrame:CGRectMake(SCREEN_WIDTH  - 70, CGRectGetMinY(_circle.frame) + btnWH/2 - 25, 50, 50)];
    [cameraBt setBackgroundImage:[UIImage imageNamed:@"btn_video_flip_camera.png"] forState:UIControlStateNormal];
    [cameraBt makeCornerRadius:17 borderColor:nil borderWidth:0];
    [cameraBt addTarget:self action:@selector(changeCamera:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cameraBt];
    
    //6:闪光灯按钮
    //没添
    
    //6:添加对焦手势
    [self addGenstureRecognizer];
    
    //7:提示语言
    UIView *warningSuperView = [[UIView alloc]init];
    warningSuperView.layer.cornerRadius = 12.5;
    warningSuperView.clipsToBounds = YES;
    warningSuperView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:warningSuperView];
    warningSuperView.frame = CGRectMake(0, 0, 150, 30);
    warningSuperView.center = CGPointMake(SCREEN_WIDTH/2.0, SCREEN_HEIGHT*0.5);

    UIView *warningBackView = [[UIView alloc]init];
    warningBackView.frame = warningSuperView.bounds;
    warningBackView.backgroundColor = [UIColor blackColor];
    warningBackView.alpha = 0.4;
    [warningSuperView addSubview:warningBackView];
    
    UILabel *warningLabel = [[UILabel alloc]init];
    warningLabel.textAlignment = NSTextAlignmentCenter;
    warningLabel.text = [NSString stringWithFormat:@"录制时间需大于%.0f秒",minTime];
    warningLabel.textColor = [UIColor whiteColor];
    warningLabel.font = [UIFont systemFontOfSize:14];
    [warningSuperView addSubview:warningLabel];
    warningLabel.frame = warningSuperView.bounds;
    self.warningSuperView = warningSuperView;
    self.warningSuperView.alpha = 0;
    
    //8:合成提示语言
    UIView *waitingSuperView = [[UIView alloc]init];
    waitingSuperView.layer.cornerRadius = 12.5;
    waitingSuperView.clipsToBounds = YES;
    waitingSuperView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:waitingSuperView];
    waitingSuperView.frame = CGRectMake(0, 0, 150, 30);
    waitingSuperView.center = CGPointMake(SCREEN_WIDTH/2.0, SCREEN_HEIGHT*0.5);
    
    UIView *waitingBackView = [[UIView alloc]init];
    waitingBackView.frame = waitingSuperView.bounds;
    waitingBackView.backgroundColor = [UIColor blackColor];
    waitingBackView.alpha = 0.4;
    [waitingSuperView addSubview:waitingBackView];
    
    UILabel *waitingLabel = [[UILabel alloc]init];
    waitingLabel.textAlignment = NSTextAlignmentCenter;
    waitingLabel.text = @"处理中,请稍后..";
    waitingLabel.textColor = [UIColor whiteColor];
    waitingLabel.font = [UIFont systemFontOfSize:14];
    [waitingSuperView addSubview:waitingLabel];
    waitingLabel.frame = waitingSuperView.bounds;
    self.waitingngSuperView = waitingSuperView;
    self.waitingngSuperView.alpha = 0;
    
    //倒计时
    UILabel *lastTimeLabel = [[UILabel alloc]init];
    lastTimeLabel.textColor = [UIColor whiteColor];
    lastTimeLabel.font = [UIFont systemFontOfSize:15];
    lastTimeLabel.textAlignment = NSTextAlignmentCenter;
    if(([UIScreen mainScreen].bounds.size.height >= 812.0 ? 1 : 0)){//刘海手机
        lastTimeLabel.frame = CGRectMake(0, CGRectGetMinY(self.viewContainer.frame)-25, SCREEN_WIDTH, 25);
    }else{
        lastTimeLabel.frame = CGRectMake(0, CGRectGetMinY(self.viewContainer.frame), SCREEN_WIDTH, 25);
    }
    lastTimeLabel.text = [NSString stringWithFormat:@"00:00 / 00:%.0f",totalTime];
    self.lastTimeLabel = lastTimeLabel;
    [self.view addSubview:lastTimeLabel];
    
    //开启录像机
    [self InitWithVideo];
}

//开始按钮变形成方形
-(void)shootBtnStart{
    cameraBt.hidden = YES;//前后摄像头转换按钮
    [UIView animateWithDuration:0.15 animations:^{
        [self->shootBt makeCornerRadius:7 borderColor:[UIColor clearColor] borderWidth:0];
        self->shootBt.transform=CGAffineTransformMakeScale(0.6, 0.6);
    }];
}

//开始按钮回归原来
-(void)shootBtnReset{
    cameraBt.hidden = NO;//前后摄像头转换按钮
    self.lastTimeLabel.text = [NSString stringWithFormat:@"00:00 / 00:%.0f",totalTime];
    [UIView animateWithDuration:0.15 animations:^{
        [self->shootBt makeCornerRadius:57/2 borderColor:[UIColor clearColor] borderWidth:0];
        self->shootBt.transform=CGAffineTransformMakeScale(1, 1);
    }];
}


#pragma mark - 开启录像机
- (void)InitWithVideo{
    
    //初始化会话
    _captureSession=[[AVCaptureSession alloc]init];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {//设置分辨率
        _captureSession.sessionPreset=AVCaptureSessionPreset1280x720;
    }
    
    //获得输入设备
    AVCaptureDevice *captureDevice=[self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];//取得后置摄像头
    //添加一个音频输入设备
    AVCaptureDevice *audioCaptureDevice=[[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    NSError *error=nil;
    //根据输入设备初始化设备输入对象，用于获得输入数据
    _captureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:captureDevice error:&error];
    
    AVCaptureDeviceInput *audioCaptureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:audioCaptureDevice error:&error];
    
    //初始化设备输出对象，用于获得输出数据
    _captureMovieFileOutput=[[AVCaptureMovieFileOutput alloc]init];
    
    //将设备输入添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
        [_captureSession addInput:audioCaptureDeviceInput];
        AVCaptureConnection *captureConnection=[_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([captureConnection isVideoStabilizationSupported ]) {
            captureConnection.preferredVideoStabilizationMode=AVCaptureVideoStabilizationModeAuto;
        }
    }
    
    //将设备输出添加到会话中
    if ([_captureSession canAddOutput:_captureMovieFileOutput]) {
        [_captureSession addOutput:_captureMovieFileOutput];
    }
    
    //创建视频预览层，用于实时展示摄像头状态
    _captureVideoPreviewLayer=[[AVCaptureVideoPreviewLayer alloc]initWithSession:self.captureSession];
    
    CALayer *layer= self.viewContainer.layer;
    layer.masksToBounds=YES;
    
    _captureVideoPreviewLayer.frame=  CGRectMake(0, 0, preLayerWidth, preLayerHeight);
    _captureVideoPreviewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;//填充模式
    [layer insertSublayer:_captureVideoPreviewLayer below:self.focusCursor.layer];
}

#pragma mark - 退出
-(void)quit{
    [self reset];
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - 重拍
- (void)reset{
    
    //计时器关闭
    [self stopTimer];
    //当前录像长度归零
    currentTime = 0;
    //开始按钮的旋转进度归零
    _circle.progress = 0.0f;
    //开始按钮重置
    [self shootBtnReset];
    //隐藏重拍按钮
    remakeBt.hidden = YES;
    //停止录制
    [self.captureMovieFileOutput stopRecording];
    //数据清空
    urlArray = [NSMutableArray array];
}


#pragma mark - 闪光灯
-(void)flashBtTap:(UIButton*)bt{
    if (bt.selected == YES) {
        bt.selected = NO;
        //关闭闪光灯
        [flashBt setBackgroundImage:[UIImage imageNamed:@"btn_video_flash_open.png"] forState:UIControlStateNormal];
        [self setTorchMode:AVCaptureTorchModeOff];
    }else{
        bt.selected = YES;
        //开启闪光灯
        [flashBt setBackgroundImage:[UIImage imageNamed:@"btn_video_flash_close.png"] forState:UIControlStateNormal];
        [self setTorchMode:AVCaptureTorchModeOn];
    }
}


#pragma mark - 计时器开启与关闭,(控制圆圈进度)
-(void)startTimer{
    countTimer = [NSTimer scheduledTimerWithTimeInterval:TIMER_INTERVAL target:self selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [countTimer fire];
}


-(void)stopTimer{
    [countTimer invalidate];
    countTimer = nil;
}



#pragma mark - UI 开始按钮的圆圈进度与时间进度
- (void)onTimer:(NSTimer *)timer{
    currentTime += TIMER_INTERVAL;

    //开始按钮变成录制中
    [self shootBtnStart];
    
    //时间
    if(currentTime < 9.5){
        self.lastTimeLabel.text = [NSString stringWithFormat:@"00:0%.0f / 00:%.0f",currentTime,totalTime];
    }else{
        self.lastTimeLabel.text = [NSString stringWithFormat:@"00:%.0f / 00:%.0f",currentTime,totalTime];
    }
    
    
    //圆
    _circle.progress = currentTime/totalTime;

    //2秒后开始显示重拍按钮
    if (currentTime > 2) {
        remakeBt.hidden = NO;
    }
    
    //时间到了停止录制视频
    if (currentTime >= totalTime) {
        
        //不用再画圈进度View了
        [countTimer invalidate];
        countTimer = nil;
        
        //正在拍摄
        if (_captureMovieFileOutput.isRecording) {
            [_captureMovieFileOutput stopRecording];//停止录像,会调用代理didFinishRecordingToOutputFileAtURL
        }else{//已经暂停了
            [self mergeAndExportVideosAtFileURLs:urlArray];
        }
    }
}

#pragma mark -- 结束录制代码
-(void)finishBtTap{
    
    //录像时间小于最短标准
    if(currentTime < minTime){
        [UIView animateWithDuration:0.2 animations:^{
            self.warningSuperView.alpha = 1;
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.2 animations:^{
                self.warningSuperView.alpha = 0;
            }];
        });
        return;
    }
    
    //表示人为点击了终止录制
    self.stopAndEnd = YES;
    
    //不用再画圈进度View了
    [countTimer invalidate];
    countTimer = nil;
    
    //正在拍摄
    if (_captureMovieFileOutput.isRecording) {
        [_captureMovieFileOutput stopRecording];//停止录像,会调用代理didFinishRecordingToOutputFileAtURL
    }else{//已经暂停了
        [self mergeAndExportVideosAtFileURLs:urlArray];
    }
}




#pragma mark 开始录像 or  结束录制
- (void)shootButtonClick:(UIButton *)button{
    
    //防止多次点击
    button.enabled = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        button.enabled = YES;
    });
    
    //根据设备输出获得连接
    AVCaptureConnection *captureConnection=[self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    
    //根据连接取得设备输出的数据
    if (![self.captureMovieFileOutput isRecording]) {//开始录制
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        //预览图层和视频方向保持一致
        urlArray = [NSMutableArray array];
        captureConnection.videoOrientation=[self.captureVideoPreviewLayer connection].videoOrientation;
        [self.captureMovieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:[self getVideoSaveFilePathString]] recordingDelegate:self];
        
    }else{//结束录制
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        [self finishBtTap];//结束录制代码
    }
}



#pragma mark 切换前后摄像头
- (void)changeCamera:(UIButton*)bt {
    AVCaptureDevice *currentDevice=[self.captureDeviceInput device];
    AVCaptureDevicePosition currentPosition=[currentDevice position];
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition=AVCaptureDevicePositionFront;
    if (currentPosition==AVCaptureDevicePositionUnspecified||currentPosition==AVCaptureDevicePositionFront) {
        toChangePosition=AVCaptureDevicePositionBack;
        flashBt.hidden = NO;
    }else{
        flashBt.hidden = YES;
    }
    toChangeDevice=[self getCameraDeviceWithPosition:toChangePosition];
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:nil];
    
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [self.captureSession beginConfiguration];
    //移除原有输入对象
    [self.captureSession removeInput:self.captureDeviceInput];
    //添加新的输入对象
    if ([self.captureSession canAddInput:toChangeDeviceInput]) {
        [self.captureSession addInput:toChangeDeviceInput];
        self.captureDeviceInput=toChangeDeviceInput;
    }
    //提交会话配置
    [self.captureSession commitConfiguration];
    
    //关闭闪光灯
    flashBt.selected = NO;
    [flashBt setBackgroundImage:[UIImage imageNamed:@"flashOn.png"] forState:UIControlStateNormal];
    [self setTorchMode:AVCaptureTorchModeOff];
   
    
}

#pragma mark - 视频输出代理
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
    NSLog(@"开始录制...");
    [self startTimer];
}
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    
     NSLog(@"录制结束...");
    
    //此段录制的视频地址.mov
    [urlArray addObject:outputFileURL];
    
    //超出了录制时间所以合成视频去
    if (currentTime>=totalTime) {
        [self mergeAndExportVideosAtFileURLs:urlArray];//合成视频
        
    }else{//没录够
        if(self.stopAndEnd){//人为终止
              [self mergeAndExportVideosAtFileURLs:urlArray];//合成视频
        }else{//暂停:功能还未实现
            
        }
    }
}

//显示请稍等+隐藏操作按钮
-(void)showWaitingAndHidenBtn:(BOOL)showWaiting{
    self.waitingngSuperView.alpha = showWaiting ? 1 : 0;
    shootBt.hidden =  showWaiting ? YES : NO;
    remakeBt.hidden = showWaiting ? YES : NO;
    quitBt.hidden = showWaiting ? YES : NO;
    _circle.hidden = showWaiting ? YES : NO;
}

//用 mov视频片段 合成视频为MP4
- (void)mergeAndExportVideosAtFileURLs:(NSMutableArray *)fileURLArray
{
    NSLog(@"合成中...");
    [self showWaitingAndHidenBtn:YES];
    NSError *error = nil;
    
    CGSize renderSize = CGSizeMake(0, 0);
    
    NSMutableArray *layerInstructionArray = [[NSMutableArray alloc] init];
    
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    
    CMTime totalDuration = kCMTimeZero;
    
    NSMutableArray *assetTrackArray = [[NSMutableArray alloc] init];
    NSMutableArray *assetArray = [[NSMutableArray alloc] init];
    for (NSURL *fileURL in fileURLArray) {
        
        AVAsset *asset = [AVAsset assetWithURL:fileURL];
        [assetArray addObject:asset];
        
        NSArray* tmpAry =[asset tracksWithMediaType:AVMediaTypeVideo];
        if (tmpAry.count>0) {
            AVAssetTrack *assetTrack = [tmpAry objectAtIndex:0];
            [assetTrackArray addObject:assetTrack];
            renderSize.width = MAX(renderSize.width, assetTrack.naturalSize.height);
            renderSize.height = MAX(renderSize.height, assetTrack.naturalSize.width);
        }
    }
    
    CGFloat renderW = MIN(renderSize.width, renderSize.height);
    
    for (int i = 0; i < [assetArray count] && i < [assetTrackArray count]; i++) {
        
        AVAsset *asset = [assetArray objectAtIndex:i];
        AVAssetTrack *assetTrack = [assetTrackArray objectAtIndex:i];
        
        AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        
        NSArray*dataSourceArray= [asset tracksWithMediaType:AVMediaTypeAudio];
        [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:([dataSourceArray count]>0)?[dataSourceArray objectAtIndex:0]:nil
                             atTime:totalDuration
                              error:nil];
        
        AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        
        [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:assetTrack
                             atTime:totalDuration
                              error:&error];
        
        AVMutableVideoCompositionLayerInstruction *layerInstruciton = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        
        totalDuration = CMTimeAdd(totalDuration, asset.duration);
        
        CGFloat rate;
        rate = renderW / MIN(assetTrack.naturalSize.width, assetTrack.naturalSize.height);
        
        CGAffineTransform layerTransform = CGAffineTransformMake(assetTrack.preferredTransform.a, assetTrack.preferredTransform.b, assetTrack.preferredTransform.c, assetTrack.preferredTransform.d, assetTrack.preferredTransform.tx * rate, assetTrack.preferredTransform.ty * rate);
        layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, 0, -(assetTrack.naturalSize.width - assetTrack.naturalSize.height) / 2.0+preLayerHWRate*(preLayerHeight-preLayerWidth)/2));
        layerTransform = CGAffineTransformScale(layerTransform, rate, rate);
        
        [layerInstruciton setTransform:layerTransform atTime:kCMTimeZero];
        [layerInstruciton setOpacity:0.0 atTime:totalDuration];

        [layerInstructionArray addObject:layerInstruciton];
    }
    
    NSString *path = [self getVideoMergeFilePathString];
    NSURL *mergeFileURL = [NSURL fileURLWithPath:path];
    
    AVMutableVideoCompositionInstruction *mainInstruciton = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruciton.timeRange = CMTimeRangeMake(kCMTimeZero, totalDuration);
    mainInstruciton.layerInstructions = layerInstructionArray;
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    mainCompositionInst.instructions = @[mainInstruciton];
    mainCompositionInst.frameDuration = CMTimeMake(1, 100);
    mainCompositionInst.renderSize = CGSizeMake(renderW, renderW*preLayerHWRate);
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetMediumQuality];
    exporter.videoComposition = mainCompositionInst;
    exporter.outputURL = mergeFileURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
             NSLog(@"合成完毕");
            [self showWaitingAndHidenBtn:NO];
            PlayVideoViewController* view = [[PlayVideoViewController alloc]init];
            view.videoURL = mergeFileURL;
            view.videoPath = path;
            view.complateBlock = self.complateBlock;
            [self.navigationController pushViewController:view animated:YES];
            
        });
    }];
}

//工具:获取合成后的存储地址.MP4
- (NSString *)getVideoMergeFilePathString
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    path = [path stringByAppendingPathComponent:VIDEO_FOLDER];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@"merge.mp4"];
    
    return fileName;
}


//输出保存为.mov
- (NSString *)getVideoSaveFilePathString
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    path = [path stringByAppendingPathComponent:VIDEO_FOLDER];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@".mov"];
    
    return fileName;
}

//创建保存视频的文件夹目录
- (void)createVideoFolderIfNotExist
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    NSString *folderPath = [path stringByAppendingPathComponent:VIDEO_FOLDER];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isDirExist = [fileManager fileExistsAtPath:folderPath isDirectory:&isDir];
    
    if(!(isDirExist && isDir))
    {
        BOOL bCreateDir = [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
        if(!bCreateDir){
            NSLog(@"创建保存视频文件夹失败");
        }
    }
}

//删除s输出源搞出来的mov视频们
- (void)deleteAllVideos
{
    for (NSURL *videoFileURL in urlArray) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *filePath = [[videoFileURL absoluteString] stringByReplacingOccurrencesOfString:@"file://" withString:@""];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if ([fileManager fileExistsAtPath:filePath]) {
                NSError *error = nil;
                [fileManager removeItemAtPath:filePath error:&error];
                
                if (error) {
                    NSLog(@"delete All Video 删除视频文件出错:%@", error);
                }
            }
        });
    }
    [urlArray removeAllObjects];
}


#pragma mark - 私有方法
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}

-(void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice= [self.captureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}




//闪光灯
-(void)setTorchMode:(AVCaptureTorchMode )torchMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isTorchModeSupported:torchMode]) {
            [captureDevice setTorchMode:torchMode];
        }
    }];
}

-(void)setFocusMode:(AVCaptureFocusMode )focusMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
    }];
}

-(void)setExposureMode:(AVCaptureExposureMode)exposureMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
    }];
}

-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}

-(void)addGenstureRecognizer{
    UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [self.viewContainer addGestureRecognizer:tapGesture];
    self.focusCursor = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"focus.png"]];
    self.focusCursor.frame = CGRectMake(0, 0, 60, 60);
    self.focusCursor.alpha=0;
    [self.viewContainer addSubview:self.focusCursor];
}

-(void)tapScreen:(UITapGestureRecognizer *)tapGesture{
    CGPoint point= [tapGesture locationInView:self.viewContainer];
    //将UI坐标转化为摄像头坐标
    CGPoint cameraPoint= [self.captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

-(void)setFocusCursorWithPoint:(CGPoint)point{

    
    self.focusCursor.center= point;
    self.focusCursor.transform = CGAffineTransformIdentity;
    self.focusCursor.transform= CGAffineTransformMakeScale(1.3, 1.3);
    self.focusCursor.alpha= 1.0;
    [UIView animateWithDuration:0.2 animations:^{
         self.focusCursor.transform= CGAffineTransformMakeScale(1.0, 1.0);
    } completion:^(BOOL finished) {
        self.focusCursor.alpha=0;
        
    }];
}

-(void)dealloc{
    NSLog(@"退出了!!!!!!!!!!!");
}
@end
