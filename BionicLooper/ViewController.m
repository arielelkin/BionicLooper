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

@interface ViewController ()

@property (nonatomic) AEAudioController *audioController;
@property (nonatomic) AEPlaythroughChannel *receiver;
@property (nonatomic) AEBlockFilter *looperBlock;

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
	
	
}


-(IBAction)clearButtonHit{
	NSLog(@"Cleared Loops!");
	playLoop = false;
	
	for(int i = 0; i<MAXLOOPS; i++){
		for(int j = 0; j<MAXLOOPLENGTH; j++){
			loopStack[i][j] = 0;
		}
	}
	
	numLoops = 0;
	playHead = 0;
    
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
