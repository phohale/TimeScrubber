//
//  TimeScrubber.m
//  TimeScrubberExample
//
//  Created by Vladyslav Semenchenko on 08/12/14.
//  Copyright (c) 2014 Vladyslav Semenchenko. All rights reserved.
//

#import "TimeScrubber.h"
#import "TimeScrubberControl.h"
#import "TimeScrubberBorder.h"
#import "TimeScrubberLabel.h"
#import "ScrollWithDates.h"
#import "ScrollWithVideoFragments.h"
#import "AMPopTip.h"

#define kOneDayPeriod 86400
#define k24HoursDevider 3600
#define kTimerInterval 1

@implementation TimeScrubber
{
    //helper sizes
    float selfHeight;
    float selfWidth;
    float selfRedControlWidth;

    // helpers
    BOOL isTouchEnded;
    BOOL isDragging;
    BOOL isLongPressStart;
    BOOL isLongPressedFired;
    CGPoint currentTouchPoint;
    
    NSInteger secondsFromGMT;
    
    NSTimer *updateTimer;
    NSTimer *longPressTimer;
    
    ScrollWithDates *scrollWithDate;
    ScrollWithVideoFragments *scrollWithVideo;
    
    NSDate *previousCreatedDate;
    
    AMPopTip *popTip;
    
    NSTimeInterval currentPressedDateInterval;
    NSTimeInterval currentTimeInterval;
    
    NSDate *creationDate;
}

#pragma mark Init
- (id)initWithFrame:(CGRect)frame withPeriod:(int)period
{
    self = [super initWithFrame:frame];
    
    if (self)
    {
        // Initialization code
        self.backgroundColor = [UIColor clearColor];
        selfHeight = frame.size.height;
        selfWidth = frame.size.width;
        isTouchEnded = NO;
        isDragging = NO;
        
        // init default values - need check period
        _minimumValue = 0.0;
        _maximumValue = 24.0;
        _value = 24.0;
        self.period = period;
        self.endDateInitial = [NSDate date];
        creationDate = self.endDateInitial;
        
        previousCreatedDate = [NSDate dateWithTimeInterval:-(k24HoursDevider * 2) sinceDate:self.endDateInitial];
        
        NSDictionary *d1 = @{@"1" : @"0", @"2" : @"-3600"}; // 1h
        NSDictionary *d2 = @{@"1" : @"-72000", @"2" : @"-79200"}; // 2h
        
        self.mArrayWithVideoFragments = [NSMutableArray arrayWithObjects:d1, d2, nil];
        
        NSDate *startDate;
        
        if (self.period == 1)
        {
            startDate = [NSDate dateWithTimeInterval:-kOneDayPeriod sinceDate:self.endDateInitial];
        }
        else if (self.period == 2)
        {
            startDate = [NSDate dateWithTimeInterval:-(kOneDayPeriod*2) sinceDate:self.endDateInitial];
        }
        else if (self.period == 3)
        {
            startDate = [NSDate dateWithTimeInterval:-(kOneDayPeriod*3) sinceDate:self.endDateInitial];
        }
        
        self.startDateIntervalInitial = startDate.timeIntervalSinceNow;
        self.endDateIntervalInitial = self.endDateInitial.timeIntervalSinceNow;
        
        // scroll
        scrollWithDate = [[ScrollWithDates alloc] initWithFrame:self.bounds period:self.period startDate:[NSDate dateWithTimeIntervalSinceNow:self.startDateIntervalInitial] endDate:self.endDateInitial];
        scrollWithDate.userInteractionEnabled = NO;
        [self addSubview:scrollWithDate];
        
        scrollWithVideo = [[ScrollWithVideoFragments alloc] initWithFrame:CGRectMake(2.5, 0, self.bounds.size.width - 5, self.bounds.size.height) period:self.period startDate:[NSDate dateWithTimeIntervalSinceNow:self.startDateIntervalInitial] endDate:self.endDateInitial];
        scrollWithVideo.userInteractionEnabled = NO;
        scrollWithVideo.clipsToBounds = YES;
        [scrollWithVideo createSubviewsWithVideoFragments:self.mArrayWithVideoFragments];
        [self addSubview:scrollWithVideo];
        
        // compute current date based on self.value
        [self update];
        
        // thumbs
        self.thumbControl = [[TimeScrubberControl alloc] initWithFrame:CGRectMake(selfWidth - (selfHeight * 0.7) / 2, selfHeight / 2  - (selfHeight * 0.7) / 2, selfHeight * 0.7, selfHeight * 0.7)];
        self.thumbControlStatic = [[TimeScrubberControl alloc] initWithFrame:CGRectMake(selfWidth - (selfHeight * 0.7) / 2, selfHeight / 2  - (selfHeight * 0.7) / 2, selfHeight * 0.7, selfHeight * 0.7)];
        self.thumbControlStatic.outerColor = [UIColor colorWithRed:0.263 green:0.501 blue:0.935 alpha:1.000];
        self.thumbControlStatic.innerColor = [UIColor whiteColor];
        self.thumbControl.outerColor = [UIColor whiteColor];
        self.thumbControl.innerColor = [UIColor colorWithRed:0.263 green:0.501 blue:0.935 alpha:1.000];
        self.thumbControl.userInteractionEnabled = NO;
        self.thumbControlStatic.userInteractionEnabled = NO;
        self.thumbControlStatic.date = [NSDate date];
        self.thumbControl.date = [NSDate date];
        [self addSubview:self.thumbControl];
        [self addSubview:self.thumbControlStatic];
        
        selfRedControlWidth = self.thumbControl.frame.size.width;
        
        popTip = [AMPopTip popTip];
        popTip.popoverColor = [UIColor colorWithRed:0.263 green:0.501 blue:0.935 alpha:1.000];
    }
    
    return self;
}

#pragma mark Drawning
- (void)drawRect:(CGRect)rect
{
    //// Color Declarations
    UIColor* color3 = [UIColor whiteColor];
    
    //// Rectangle Drawing
    UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRect: CGRectMake(rect.origin.x, rect.size.height * 0.5 - 10, rect.size.width, 20)];
    [color3 setFill];
    [rectanglePath fill];
}

#pragma mark User interactions
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    isTouchEnded = NO;
    isDragging = YES;
    isLongPressedFired = NO;
    isLongPressStart = YES;
    longPressTimer = [NSTimer scheduledTimerWithTimeInterval:kTimerInterval target:self selector:@selector(handleLongPress) userInfo:nil repeats:NO];
    
    CGPoint l = [touch locationInView:self];
    currentTouchPoint = l;
    
    if ([self markerHitTest:l])
    {
        [self moveRedControl:l];
        [self sendActionsForControlEvents:UIControlEventValueChanged];
        
        [popTip showText:[NSString stringWithFormat:@"%@", [NSDate dateWithTimeInterval:self.currentDateIntervalFixed sinceDate:self.endDateInitial]] direction:AMPopTipDirectionUp maxWidth:200 inView:self fromFrame:self.thumbControl.frame];

        return YES;
    } else
    {
        return NO;
    }
    
    return NO;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    isLongPressStart = NO;
    [longPressTimer invalidate];
    
    CGPoint p = [touch locationInView:self];
    currentTouchPoint = p;
    
    CGRect trackingFrame = self.bounds;
    
    if (!CGRectContainsPoint(trackingFrame, p))
    {
        return NO;
    }
    
    [self moveRedControl:p];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    
    if (!isLongPressedFired)
    {
        isLongPressStart = YES;
        longPressTimer = [NSTimer scheduledTimerWithTimeInterval:kTimerInterval target:self selector:@selector(handleLongPress) userInfo:nil repeats:NO];
    }
    
    return YES;
}

- (void)cancelTrackingWithEvent:(UIEvent *)event
{
    [self handleLongPressFinished];
    
    isTouchEnded = YES;
    isDragging = NO;
    
    isLongPressStart = NO;
    isLongPressedFired = NO;
    [longPressTimer invalidate];
    longPressTimer = nil;
    
    [popTip hide];

    [super cancelTrackingWithEvent:event];
}


- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    if (isLongPressedFired)
    {
        [self handleLongPressFinished];
    }
    
    isTouchEnded = YES;
    isDragging = NO;
    
    isLongPressStart = NO;
    isLongPressedFired = NO;
    [longPressTimer invalidate];
    longPressTimer = nil;
    
    [popTip hide];
    
    [super endTrackingWithTouch:touch withEvent:event];
}

#pragma mark UI updates from user interactions
- (BOOL)markerHitTest:(CGPoint) point
{
    if (point.x < self.bounds.origin.x || point.x > selfWidth) // x test
    {
        return NO;
    }
    
    return YES;
}

-(void)moveRedControl:(CGPoint)lastPoint
{
    CGRect newFrameForControl = CGRectMake(lastPoint.x - selfRedControlWidth / 2, self.thumbControl.frame.origin.y, self.thumbControl.bounds.size.width, self.thumbControl.bounds.size.height);
    self.thumbControl.frame =newFrameForControl;
    
    // update current value
    float oneValuePerPixel = self.maximumValue / selfWidth;
    self.value = lastPoint.x * oneValuePerPixel;
    
    if (lastPoint.x > selfWidth || lastPoint.x < 0)
    {
        
    }
    else
    {
        [self computeCurrentDate];
        
        popTip.fromFrame = self.thumbControl.frame;
    }

    //Redraw
    [self setNeedsDisplay];
}

#pragma mark Operations with Date
- (void)computeCurrentDate
{
    if (!isLongPressedFired)
    {
        self.endDateInitial = [NSDate date];
        self.endDateIntervalInitial = self.endDateInitial.timeIntervalSinceNow;
        
        if (self.period == 1)
        {
            self.startDateIntervalInitial = [[NSDate dateWithTimeInterval:-kOneDayPeriod sinceDate:self.endDateInitial] timeIntervalSinceDate:self.endDateInitial];
        }
        else if (self.period == 2)
        {
            self.startDateIntervalInitial = [[NSDate dateWithTimeInterval:-(kOneDayPeriod*2) sinceDate:self.endDateInitial] timeIntervalSinceDate:self.endDateInitial];
        }
        else if (self.period == 3)
        {
            self.startDateIntervalInitial = [[NSDate dateWithTimeInterval:-(kOneDayPeriod*3) sinceDate:self.endDateInitial] timeIntervalSinceDate:self.endDateInitial];
        }
        
        float dateDifference = self.endDateIntervalInitial - self.startDateIntervalInitial;
        float onePart = dateDifference / self.maximumValue;
        
        self.currentDateInterval = self.startDateIntervalInitial + (onePart * self.value);
        
        [self getRealCurrentDate];
    }
    else
    {
        float dateDifference = self.endDateIntervalInitial - self.startDateIntervalInitial;
        float onePart = dateDifference / self.maximumValue;
        
        self.currentDateInterval = self.startDateIntervalInitial + (onePart * self.value);
        
        [self getRealCurrentDate];
    }
}

- (NSTimeInterval)getRealCurrentDate
{
    if (!isLongPressedFired)
    {
        secondsFromGMT = [[NSTimeZone localTimeZone] secondsFromGMT];
        self.currentDateIntervalFixed = self.currentDateInterval + secondsFromGMT;
        
        [popTip updateText:[NSString stringWithFormat:@"%@", [NSDate dateWithTimeInterval:self.currentDateIntervalFixed sinceDate:self.endDateInitial]]];

        self.selectedDate = [NSDate dateWithTimeInterval:self.currentDateIntervalFixed sinceDate:self.endDateInitial];
        
        return self.currentDateIntervalFixed;
    }
    else
    {
        secondsFromGMT = [[NSTimeZone localTimeZone] secondsFromGMT];
        self.currentDateIntervalFixed = self.currentDateInterval + secondsFromGMT;

        [popTip updateText:[NSString stringWithFormat:@"%@", [NSDate dateWithTimeIntervalSinceNow:self.currentDateInterval + secondsFromGMT]]];
        
        self.selectedDate = [NSDate dateWithTimeIntervalSinceNow:self.currentDateInterval + secondsFromGMT];
        
        return self.currentDateInterval;
    }
}

#pragma mark Updates
- (void)updateEnable:(BOOL)isEnabled
{
    if (isEnabled)
    {
        updateTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(update) userInfo:nil repeats:YES];
    }
    else
    {
        [updateTimer invalidate];
        updateTimer = nil;
    }
}

- (void)update
{
    if (!isDragging)
    {
        [self computeCurrentDate];
        
        float dateDifference = self.endDateIntervalInitial - self.startDateIntervalInitial;
        float datePerPixel = selfWidth / dateDifference;
        [scrollWithDate updateWithOffset:1 * datePerPixel];
        [scrollWithVideo updateWithOffset:1.5 * datePerPixel];
        
        if ((int)previousCreatedDate.timeIntervalSinceNow == -(k24HoursDevider * 2) || (int)previousCreatedDate.timeIntervalSinceNow == -((k24HoursDevider * 2) + 1))
        {
            previousCreatedDate = [NSDate date];
            [scrollWithDate createNewViewWithDate:previousCreatedDate];
        }
    }
}

- (void)updateMarker
{
    float dateDifference = self.endDateIntervalInitial - self.startDateIntervalInitial;
    float datePerPixel = selfWidth / dateDifference;
    
    float x1 = self.selectedDate.timeIntervalSinceNow - secondsFromGMT;
    float x1dif = x1 - self.startDateIntervalInitial;
    float x1pos = x1dif * datePerPixel;
    
    [UIView animateWithDuration:0.1 animations:^{
        self.thumbControl.frame = CGRectMake(x1pos - self.thumbControl.frame.size.width * 0.5, self.thumbControl.frame.origin.y, self.thumbControl.frame.size.width, self.thumbControl.frame.size.height);
    }];
}

- (void)updateStaticMarker
{
    float endDateInterval = self.endDateIntervalInitial;
    
    if (0 > self.startDateIntervalInitial && 0 < endDateInterval)
    {
        float dateDifference = self.endDateIntervalInitial - self.startDateIntervalInitial;
        float datePerPixel = selfWidth / dateDifference;
        
        float x1 = 0;
        float x1dif = x1 - self.startDateIntervalInitial;
        float x1pos = x1dif * datePerPixel;
        
        [UIView animateWithDuration:0.1 animations:^{
            self.thumbControlStatic.frame = CGRectMake(x1pos - self.thumbControlStatic.frame.size.width * 0.5, self.thumbControlStatic.frame.origin.y, self.thumbControlStatic.frame.size.width, self.thumbControlStatic.frame.size.height);
        }];
    }
    else
    {
        [UIView animateWithDuration:0.1 animations:^{
            self.thumbControlStatic.hidden = YES;
        }];
    }
}

#pragma mark Long press gesture
-(void)handleLongPress
{
    isLongPressedFired = YES;
    currentTimeInterval = [NSDate date].timeIntervalSinceNow;
    
    // stop date update
    [self updateEnable:NO];
    
    // update start end date based on current selected date
    float testDevider = k24HoursDevider / 2;
    currentPressedDateInterval = self.currentDateInterval;
    NSDate *currentDate = [NSDate dateWithTimeIntervalSinceNow:self.currentDateInterval];
    
    self.endDateInitial = [[NSDate alloc] initWithTimeInterval:testDevider sinceDate:currentDate];
    
    previousCreatedDate = [NSDate dateWithTimeInterval:-k24HoursDevider / 2 sinceDate:self.endDateInitial];
    
    NSDate *startDate;
    
    if (self.period == 1)
    {
        startDate = [NSDate dateWithTimeInterval:-k24HoursDevider sinceDate:self.endDateInitial];
    }
    else if (self.period == 2)
    {
        startDate = [NSDate dateWithTimeInterval:-(k24HoursDevider*2) sinceDate:self.endDateInitial];
    }
    else if (self.period == 3)
    {
        startDate = [NSDate dateWithTimeInterval:-(k24HoursDevider*3) sinceDate:self.endDateInitial];
    }
    
    self.startDateIntervalInitial = startDate.timeIntervalSinceNow;
    self.endDateIntervalInitial = self.endDateInitial.timeIntervalSinceNow;
    
    // update scroll and labels
    [scrollWithVideo updateWithPeriod:self.period startDate:[NSDate dateWithTimeIntervalSinceNow:self.startDateIntervalInitial] endDate:self.endDateInitial andDelta:creationDate.timeIntervalSinceNow];
    [scrollWithVideo createSubviewsWithVideoFragments:self.mArrayWithVideoFragments];
    [scrollWithDate updateWithPeriod:self.period startDate:[NSDate dateWithTimeIntervalSinceNow:self.startDateIntervalInitial] endDate:self.endDateInitial isNeedHours:NO];
    
    // update time // hide marker
    [self updateStaticMarker];
    [self update];
    [self updateEnable:NO];
    
    [scrollWithDate createNewViewWithDate:[NSDate dateWithTimeInterval:0 sinceDate:self.endDateInitial]];
    previousCreatedDate = [NSDate dateWithTimeInterval:-secondsFromGMT sinceDate:self.endDateInitial];
}

-(void)handleLongPressFinished
{
    self.endDateInitial = [NSDate date];
    previousCreatedDate = [NSDate dateWithTimeInterval:-(k24HoursDevider * 2) sinceDate:self.endDateInitial];
    
    NSDate *startDate;
    
    if (self.period == 1)
    {
        startDate = [NSDate dateWithTimeInterval:-kOneDayPeriod sinceDate:self.endDateInitial];
    }
    else if (self.period == 2)
    {
        startDate = [NSDate dateWithTimeInterval:-(kOneDayPeriod*2) sinceDate:self.endDateInitial];
    }
    else if (self.period == 3)
    {
        startDate = [NSDate dateWithTimeInterval:-(kOneDayPeriod*3) sinceDate:self.endDateInitial];
    }
    
    self.startDateIntervalInitial = startDate.timeIntervalSinceNow;
    self.endDateIntervalInitial = self.endDateInitial.timeIntervalSinceNow;
    
    // update scroll and labels
    [scrollWithVideo updateWithPeriod:self.period startDate:[NSDate dateWithTimeIntervalSinceNow:self.startDateIntervalInitial] endDate:self.endDateInitial andDelta:creationDate.timeIntervalSinceNow];
    [scrollWithVideo createSubviewsWithVideoFragments:self.mArrayWithVideoFragments];
    [scrollWithDate updateWithPeriod:self.period startDate:[NSDate dateWithTimeIntervalSinceNow:self.startDateIntervalInitial] endDate:self.endDateInitial isNeedHours:YES];
    
    // update time // move marker
    [self updateMarker];
    
   self.thumbControlStatic.frame = CGRectMake(selfWidth - (selfHeight * 0.7) / 2, selfHeight / 2  - (selfHeight * 0.7) / 2, selfHeight * 0.7, selfHeight * 0.7);
    [UIView animateWithDuration:0.1 animations:^{
        self.thumbControlStatic.hidden = NO;
    }];
    
    [self update];
    [self updateEnable:YES];
}

@end