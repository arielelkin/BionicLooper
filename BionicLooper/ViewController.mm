//
//  ViewController.m
//  BionicLooper
//
//  Created by Ariel Elkin on 18/05/2013.
//  Copyright (c) 2013 ariel. All rights reserved.
//

#import "ViewController.h"

#import "AEAudioController.h"
#import "AEPlaythroughChannel.h"
#import "AEBlockFilter.h"
#import "AEBlockChannel.h"

#import "TPOscilloscopeLayer.h"
#import "LoopIndicator.h"

#import "Chorus.h"
#import "PRCRev.h"
#import "PitShift.h"

#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>



//#import "BionicOSC.h"

static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};


@interface ViewController ()

@property (nonatomic) AEAudioController *audioController;
@property (nonatomic) AEPlaythroughChannel *receiver;
@property (nonatomic) AEBlockFilter *looperBlock;
@property (nonatomic) AEBlockFilter *chorusBlock;

@property stk::Chorus *myChorus;
@property stk::PRCRev *myReverb;
@property stk::PitShift *pitShift;

@property (nonatomic) TPOscilloscopeLayer *inputOscilloscope;

@property (nonatomic) NSMutableArray *loopIndicators;


@property (nonatomic) BOOL isUsingFrontFacingCamera;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic) dispatch_queue_t videoDataOutputQueue;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, strong) UIImage *borderImage;
@property (nonatomic, strong) CIDetector *faceDetector;


@end

@implementation ViewController

@synthesize videoDataOutput = _videoDataOutput;
@synthesize videoDataOutputQueue = _videoDataOutputQueue;

@synthesize borderImage = _borderImage;
@synthesize previewView = _previewView;
@synthesize previewLayer = _previewLayer;

@synthesize faceDetector = _faceDetector;

@synthesize isUsingFrontFacingCamera = _isUsingFrontFacingCamera;


#define MAXLOOPS 5 //there can be no more than 5 loops
#define MAXLOOPLENGTH 1000000 //loops cannot be longer than 1000000
float loopStack[MAXLOOPS][MAXLOOPLENGTH] = { { 0 } };
int playHead = 0;
int loopSize = 1000000;
bool recording = false;
bool playLoop = false;
int numLoops = 0;


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //AUDIO CONTROLLER SETUP
    self.audioController = [[AEAudioController alloc]
                            initWithAudioDescription:[AEAudioController nonInterleavedFloatStereoAudioDescription]
                            inputEnabled:YES
                            ];

    NSError *errorAudioSetup = NULL;
    BOOL result = [_audioController start:&errorAudioSetup];
    if ( !result ) {
        NSLog(@"Error starting audio engine: %@", errorAudioSetup.localizedDescription);
    }

    
    //RECEIVER
    self.receiver = [[AEPlaythroughChannel alloc] initWithAudioController:self.audioController];
    [self.audioController addInputReceiver:self.receiver];
    [self.audioController addChannels:@[self.receiver]];
    
    
    //FILTER
    AEBlockFilter *looperBlock = [AEBlockFilter filterWithBlock:^(AEAudioControllerFilterProducer producer, void *producerToken, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio) {
        
        OSStatus status = producer(producerToken, audio, &frames);
        if ( status != noErr ) return;
        
        for (int i = 0; i<frames; i++) {
            
            if (recording) {
                
                loopStack[numLoops-1][playHead] = ((float *)audio->mBuffers[0].mData)[i];
                playHead++;
            }
            
            
            if(playLoop){
                //add everything at that point on the loopStack to what we're hearing
                if(recording){
                    for(int j = 0; j<numLoops; j++){
                        ((float*)audio->mBuffers[0].mData)[i] += loopStack[0][playHead-1];
                    }
                    
                } else if(!recording){
                    for(int k = 0; k<numLoops; k++){
                        ((float*)audio->mBuffers[0].mData)[i] += loopStack[k][playHead];

                    }
                    playHead++;
                }
            }
            
            playHead = playHead%loopSize;
            
            ((float*)audio->mBuffers[1].mData)[i] = ((float*)audio->mBuffers[0].mData)[i];
            
            
        }
    }];
    
    [self.audioController addFilter:looperBlock];
    

    self.myChorus = new stk::Chorus(400);
    self.myChorus->setModDepth(0.4);
    self.myChorus->setModFrequency(400);
    self.myChorus->setEffectMix(0.3);
    
    self.myReverb = new stk::PRCRev();
    self.myReverb->setEffectMix(0.3);
    
    self.pitShift = new stk::PitShift();
    
    
    self.chorusBlock = [AEBlockFilter filterWithBlock:^(AEAudioControllerFilterProducer producer, void *producerToken, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio) {
        
        OSStatus status = producer(producerToken, audio, &frames);
        if ( status != noErr ) return;

        
        for (int i = 0; i<frames; i++) {
            
            ((float*)audio->mBuffers[0].mData)[i] += self.myReverb->tick( self.myChorus->tick(((float*)audio->mBuffers[0].mData)[i]) );
        }
    }];
    
    [self.audioController addFilter:self.chorusBlock];
    
    [self setupUI];
    
    [self setupProximitySensing];
    
    [self setupAVCapture];
	self.borderImage = [UIImage imageNamed:@"border"];
	NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil];
	self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];

    

    
//    // OSC RECEIVER
//
//    
//    double delayInSeconds = 2.0;
//    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
//    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//        
//        BionicOSCPacketListener listener;
//        UdpListeningReceiveSocket s(
//                                    IpEndpointName( IpEndpointName::ANY_ADDRESS, PORT ),
//                                    &listener );
//        s.RunUntilSigInt();
//
//        
//    });
//    

}

-(void)setupUI{
    
    NSLog(@"SHOULD LOAD UI!");
    
    [self.view setBackgroundColor:[UIColor whiteColor]];
    
    
    UIButton *loopOneButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [loopOneButton setFrame:CGRectMake(0, 0, 300, 300)];
    [loopOneButton setTitle:@"LOOP" forState:UIControlStateNormal];
    [loopOneButton addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchDown];
    [loopOneButton setCenter:CGPointMake(self.view.center.x, 200)];
    [self.view addSubview:loopOneButton];
    
    UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [clearButton setFrame:CGRectMake(0, 0, 100, 100)];
    [clearButton setTitle:@"CLEAR" forState:UIControlStateNormal];
    [clearButton addTarget:self action:@selector(clearButtonHit) forControlEvents:UIControlEventTouchDown];
    [clearButton setCenter:CGPointMake(self.view.center.x, loopOneButton.center.y+250)];
    [self.view addSubview:clearButton];
    
    
    self.inputOscilloscope = [[TPOscilloscopeLayer alloc] initWithAudioController:_audioController];
    _inputOscilloscope.frame = CGRectMake(0, 0, 200, 80);
    _inputOscilloscope.lineColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    [self.view.layer addSublayer:_inputOscilloscope];
    [_audioController addInputReceiver:_inputOscilloscope];
    [_inputOscilloscope start];
    
    
    self.loopIndicators = [NSMutableArray array];
    
    LoopIndicator *loopOne = [[LoopIndicator alloc] initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.height, 200)];
    
    [loopOne setCenter:CGPointMake(loopOne.center.x, 800)];
    
    [self.view addSubview:loopOne];
    
    [self.loopIndicators addObject:loopOne];
    
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateLoopUI) userInfo:nil repeats:YES];
    
    
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	// get touch event
	UITouch *touch = [[event allTouches] anyObject];
	CGPoint touchLocation = [touch locationInView:self.view];
	NSLog(@"x: %0.0f, y: %0.0f", touchLocation.x, touchLocation.y);
    
    
//    self.myChorus->setModFrequency(touchLocation.x * 1.5);
    self.myReverb->setT60(touchLocation.y/768);
    
    NSLog(@"reverb: %f", touchLocation.y/768);
    
}

-(void)setupProximitySensing{
}

-(void)updateLoopUI{
    
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        LoopIndicator *l =  (LoopIndicator *) self.loopIndicators[0];
        
        float currentLoopPosition = ((float)playHead/(float)loopSize);
        [l updateLoopIndicator:currentLoopPosition];

//    });
    
    
}

-(IBAction)buttonPressed{
    
    //start recording loop
    if (!recording) {
        recording = true;
        numLoops++;
    }
    
    //stop recording loop
    else {
        recording = false;
        playLoop = true;
        
        if(numLoops == 1){
            loopSize = playHead;
            NSLog(@"loopSize set to %d", playHead);
        }
    }
    
    NSLog(@"Recording: %d, numLoops: %d", recording, numLoops);
    NSLog(@"playhead: %d, loopsize: %d", playHead, loopSize);
	
}


-(IBAction)clearButtonHit{
	NSLog(@"Cleared Loops!");
    recording = false;
	playLoop = false;
	
	for(int i = 0; i<MAXLOOPS; i++){
		for(int j = 0; j<MAXLOOPLENGTH; j++){
			loopStack[i][j] = 0;
		}
	}
	
	numLoops = 0;
	playHead = 0;
    loopSize = 1000000;
    
}




- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}





#pragma mark -
#pragma mark Face stuff
//https://github.com/jeroentrappers/FaceDetectionPOC/

- (void)setupAVCapture
{
	NSError *error = nil;
	
	AVCaptureSession *session = [[AVCaptureSession alloc] init];
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone){
	    [session setSessionPreset:AVCaptureSessionPreset640x480];
	} else {
	    [session setSessionPreset:AVCaptureSessionPresetPhoto];
	}
    
    // Select a video device, make an input
	AVCaptureDevice *device;
	
    AVCaptureDevicePosition desiredPosition = AVCaptureDevicePositionFront;
	
    // find the front facing camera
	for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
		if ([d position] == desiredPosition) {
			device = d;
            self.isUsingFrontFacingCamera = YES;
			break;
		}
	}
    // fall back to the default camera.
    if( nil == device )
    {
        self.isUsingFrontFacingCamera = NO;
        device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    // get the input device
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    
	if( !error ) {
        
        // add the input to the session
        if ( [session canAddInput:deviceInput] ){
            [session addInput:deviceInput];
        }
        
        
        // Make a video data output
        self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        
        // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
        NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
                                           [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        [self.videoDataOutput setVideoSettings:rgbOutputSettings];
        [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked
        
        // create a serial dispatch queue used for the sample buffer delegate
        // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
        // see the header doc for setSampleBufferDelegate:queue: for more information
        self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQueue];
        
        if ( [session canAddOutput:self.videoDataOutput] ){
            [session addOutput:self.videoDataOutput];
        }
        
        // get the output for doing face detection.
        [[self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
        
        self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
        self.previewLayer.backgroundColor = [[UIColor blackColor] CGColor];
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        
        CALayer *rootLayer = [self.previewView layer];
        [rootLayer setMasksToBounds:YES];
        [self.previewLayer setFrame:[rootLayer bounds]];
        [rootLayer addSublayer:self.previewLayer];
        [session startRunning];
        
    }
	session = nil;
	if (error) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:
                                  [NSString stringWithFormat:@"Failed with error %d", (int)[error code]]
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"Dismiss"
                                                  otherButtonTitles:nil];
		[alertView show];
		[self teardownAVCapture];
	}
}

// clean up capture setup
- (void)teardownAVCapture
{
	self.videoDataOutput = nil;
    self.videoDataOutputQueue = nil;
	[self.previewLayer removeFromSuperlayer];
	self.previewLayer = nil;
}


// utility routine to display error aleart if takePicture fails
- (void)displayErrorOnMainQueue:(NSError *)error withMessage:(NSString *)message
{
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:[NSString stringWithFormat:@"%@ (%d)", message, (int)[error code]]
                                  message:[error localizedDescription]
                                  delegate:nil
                                  cancelButtonTitle:@"Dismiss"
                                  otherButtonTitles:nil];
        [alertView show];
	});
}


// find where the video box is positioned within the preview layer based on the video size and gravity
+ (CGRect)videoPreviewBoxForGravity:(NSString *)gravity
                          frameSize:(CGSize)frameSize
                       apertureSize:(CGSize)apertureSize
{
    CGFloat apertureRatio = apertureSize.height / apertureSize.width;
    CGFloat viewRatio = frameSize.width / frameSize.height;
    
    CGSize size = CGSizeZero;
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (viewRatio > apertureRatio) {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        } else {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        size.width = frameSize.width;
        size.height = frameSize.height;
    }
	
	CGRect videoBox;
	videoBox.size = size;
	if (size.width < frameSize.width)
		videoBox.origin.x = (frameSize.width - size.width) / 2;
	else
		videoBox.origin.x = (size.width - frameSize.width) / 2;
	
	if ( size.height < frameSize.height )
		videoBox.origin.y = (frameSize.height - size.height) / 2;
	else
		videoBox.origin.y = (size.height - frameSize.height) / 2;
    
	return videoBox;
}

// called asynchronously as the capture output is capturing sample buffers, this method asks the face detector
// to detect features and for each draw the green border in a layer and set appropriate orientation
- (void)drawFaces:(NSArray *)features
      forVideoBox:(CGRect)clearAperture
      orientation:(UIDeviceOrientation)orientation
{
	NSArray *sublayers = [NSArray arrayWithArray:[self.previewLayer sublayers]];
	NSInteger sublayersCount = [sublayers count], currentSublayer = 0;
	NSInteger featuresCount = [features count], currentFeature = 0;
	
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	
	// hide all the face layers
	for ( CALayer *layer in sublayers ) {
		if ( [[layer name] isEqualToString:@"FaceLayer"] )
			[layer setHidden:YES];
	}
	
	if ( featuresCount == 0 ) {
		[CATransaction commit];
		return; // early bail.
	}
    
	CGSize parentFrameSize = [self.previewView frame].size;
	NSString *gravity = [self.previewLayer videoGravity];
	BOOL isMirrored = [self.previewLayer isMirrored];
	CGRect previewBox = [ViewController videoPreviewBoxForGravity:gravity
                                                        frameSize:parentFrameSize
                                                     apertureSize:clearAperture.size];
	
	for ( CIFaceFeature *ff in features ) {
		// find the correct position for the square layer within the previewLayer
		// the feature box originates in the bottom left of the video frame.
		// (Bottom right if mirroring is turned on)
		CGRect faceRect = [ff bounds];
        
		// flip preview width and height
		CGFloat temp = faceRect.size.width;
		faceRect.size.width = faceRect.size.height;
		faceRect.size.height = temp;
		temp = faceRect.origin.x;
		faceRect.origin.x = faceRect.origin.y;
		faceRect.origin.y = temp;
		// scale coordinates so they fit in the preview box, which may be scaled
		CGFloat widthScaleBy = previewBox.size.width / clearAperture.size.height;
		CGFloat heightScaleBy = previewBox.size.height / clearAperture.size.width;
		faceRect.size.width *= widthScaleBy;
		faceRect.size.height *= heightScaleBy;
		faceRect.origin.x *= widthScaleBy;
		faceRect.origin.y *= heightScaleBy;
        
		if ( isMirrored )
			faceRect = CGRectOffset(faceRect, previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), previewBox.origin.y);
		else
			faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
        		
		CALayer *featureLayer = nil;
		
		// re-use an existing layer if possible
		while ( !featureLayer && (currentSublayer < sublayersCount) ) {
			CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
			if ( [[currentLayer name] isEqualToString:@"FaceLayer"] ) {
				featureLayer = currentLayer;
				[currentLayer setHidden:NO];
			}
		}
		
		// create a new one if necessary
		if ( !featureLayer ) {
			featureLayer = [[CALayer alloc]init];
			featureLayer.contents = (id)self.borderImage.CGImage;
			[featureLayer setName:@"FaceLayer"];
			[self.previewLayer addSublayer:featureLayer];
			featureLayer = nil;
		}
		[featureLayer setFrame:faceRect];


		
		switch (orientation) {
			case UIDeviceOrientationPortrait:
				[featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
				break;
			case UIDeviceOrientationPortraitUpsideDown:
				[featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(180.))];
				break;
			case UIDeviceOrientationLandscapeLeft:
				[featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(90.))];
				break;
			case UIDeviceOrientationLandscapeRight:
				[featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(-90.))];
				break;
			case UIDeviceOrientationFaceUp:
			case UIDeviceOrientationFaceDown:
			default:
				break; // leave the layer in its last known orientation
		}
		currentFeature++;
	}
	
	[CATransaction commit];
}

- (NSNumber *) exifOrientation: (UIDeviceOrientation) orientation
{
	int exifOrientation;
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants.
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
     
     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
    
	enum {
		PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
		PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.
		PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
		PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
		PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
		PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
		PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
		PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
	};
	
	switch (orientation) {
		case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
			exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
			break;
		case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
			if (self.isUsingFrontFacingCamera)
				exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			else
				exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			break;
		case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
			if (self.isUsingFrontFacingCamera)
				exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			else
				exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			break;
		case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
		default:
			exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
			break;
	}
    return [NSNumber numberWithInt:exifOrientation];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
	// get the image
	CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
	CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer
                                                      options:(__bridge NSDictionary *)attachments];
	if (attachments) {
		CFRelease(attachments);
    }
    
    // make sure your device orientation is not locked.
	UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    
	NSDictionary *imageOptions = nil;
    
	imageOptions = [NSDictionary dictionaryWithObject:[self exifOrientation:curDeviceOrientation]
                                               forKey:CIDetectorImageOrientation];
    
	NSArray *features = [self.faceDetector featuresInImage:ciImage
                                                   options:imageOptions];
	
    // get the clean aperture
    // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
    // that represents image data valid for display.
	CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
	CGRect cleanAperture = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft == false*/);
	
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		[self drawFaces:features 
            forVideoBox:cleanAperture 
            orientation:curDeviceOrientation];
        
        if (features.count >0) {
            CIFaceFeature *f = (CIFaceFeature *) features[0];
            NSLog(@"x: %f", f.rightEyePosition.x);
            self.myChorus->setModFrequency(f.rightEyePosition.x*2);
        }
        
	});
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    [self teardownAVCapture];
	self.faceDetector = nil;
	self.borderImage = nil;
}

@end
