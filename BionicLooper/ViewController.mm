//
//  ViewController.m
//  BionicLooper
//
//  Created by Ariel Elkin on 18/05/2013.
//  Copyright (c) 2013 ariel. All rights reserved.
//

#import "ViewController.h"
#import "BionicOSC.h"
#import "AEAudioController.h"

@interface ViewController ()

@property AEAudioController *audioController;

@end

@implementation ViewController

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

    
    // OSC RECEIVER
    BionicOSCPacketListener listener;
    UdpListeningReceiveSocket s(
                                IpEndpointName( IpEndpointName::ANY_ADDRESS, PORT ),
                                &listener );
    s.RunUntilSigInt();
    
    //
    
    
    
	// Do any additional setup after loading the view, typically from a nib.
    
    //RECEIVER
//    self.receiver = [[AEPlaythroughChannel alloc] initWithAudioController:self.audioController];
//    [self.audioController addInputReceiver:self.receiver];
//    [self.audioController addChannels:@[self.receiver]];
//    
//    [self.audioController addInputReceiver:self.receiver];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
