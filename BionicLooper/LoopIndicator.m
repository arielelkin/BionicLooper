//
//  LoopIndicator.m
//  BionicLooper
//
//  Created by Ariel Elkin on 19/05/2013.
//  Copyright (c) 2013 ariel. All rights reserved.
//

#import "LoopIndicator.h"
#import <QuartzCore/QuartzCore.h>

@interface LoopIndicator()

@property CALayer *loopIndicator;

@end

@implementation LoopIndicator

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        CALayer *loopBackground = [CALayer layer];
        [loopBackground setFrame:frame];
        [loopBackground setBackgroundColor:[UIColor blackColor].CGColor];
        [self.layer addSublayer:loopBackground];
        
        self.loopIndicator = [CALayer layer];
        [self.loopIndicator setFrame:CGRectMake(0, 0, 0, loopBackground.frame.size.height)];
        [self.loopIndicator setBackgroundColor:[UIColor redColor].CGColor];
        [loopBackground addSublayer:self.loopIndicator];
           
    }
    return self;
}

-(void)updateLoopIndicator:(float)value{
    if (value >= 0 && value <= 1){
        [self.loopIndicator setFrame:CGRectMake(self.loopIndicator.frame.origin.x,
                                                self.loopIndicator.frame.origin.y,
                                                self.frame.size.width * value,
                                                self.loopIndicator.frame.size.height)
         ];
        
        NSLog(@"should set to %f", value);
    }
    else {
        NSLog(@"loopindicator (value >= 0 && value <= 1)");
    }
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
