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

//#import "BionicOSC.h"

@interface ViewController ()

@property (nonatomic) AEAudioController *audioController;
@property (nonatomic) AEPlaythroughChannel *receiver;
@property (nonatomic) AEBlockFilter *looperBlock;
@property (nonatomic) AEBlockFilter *chorusBlock;

@property stk::Chorus *myChorus;
@property stk::PRCRev *myReverb;

@property (nonatomic) TPOscilloscopeLayer *inputOscilloscope;

@property (nonatomic) NSMutableArray *loopIndicators;

@end

@implementation ViewController

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
    
    
    self.chorusBlock = [AEBlockFilter filterWithBlock:^(AEAudioControllerFilterProducer producer, void *producerToken, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio) {
        
        OSStatus status = producer(producerToken, audio, &frames);
        if ( status != noErr ) return;

        
        for (int i = 0; i<frames; i++) {
            
            ((float*)audio->mBuffers[0].mData)[i] += self.myReverb->tick( self.myChorus->tick(((float*)audio->mBuffers[0].mData)[i]) );
        }
    }];
    
    [self.audioController addFilter:self.chorusBlock];
    
    [self setupUI];
    

    
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
    
    
    self.myChorus->setModFrequency(touchLocation.x * 1.5);
    self.myReverb->setT60(touchLocation.y/768);
    
    NSLog(@"reverb: %f", touchLocation.y/768);
    
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

@end
