//
// UIScrollView+SVPullToRefresh.m
//
// Created by Sam Vermette on 23.04.12.
// Copyright (c) 2012 samvermette.com. All rights reserved.
//
// https://github.com/samvermette/SVPullToRefresh
//

#import <QuartzCore/QuartzCore.h>
#import "UIScrollView+SVPullToRefresh.h"

//fequal() and fequalzro() from http://stackoverflow.com/a/1614761/184130
#define fequal(a,b) (fabs((a) - (b)) < FLT_EPSILON)
#define fequalzero(a) (fabs(a) < FLT_EPSILON)

static CGFloat const SVPullToRefreshViewHeight = 60;


@interface SVPullToRefreshView ()

@property (nonatomic, copy) void (^pullToRefreshActionHandler)(void);

@property (nonatomic, assign) UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic, readwrite) SVPullToRefreshState state;
@property (nonatomic, readwrite) SVPullToRefreshPosition position;

@property (nonatomic, retain) NSMutableArray *viewForState;

@property (nonatomic, assign) UIScrollView * scrollView;
@property (nonatomic, readwrite) CGFloat originalTopInset;
@property (nonatomic, readwrite) CGFloat originalBottomInset;

@property (nonatomic, assign) BOOL wasTriggeredByUser;
@property (nonatomic, assign) BOOL showsPullToRefresh;
@property (nonatomic, assign) BOOL showsDateLabel;
@property(nonatomic, assign) BOOL isObserving;

- (void)resetScrollViewContentInset;
- (void)setScrollViewContentInsetForLoading;
- (void)setScrollViewContentInset:(UIEdgeInsets)insets;
- (void)rotateArrow:(float)degrees hide:(BOOL)hide;

@end



#pragma mark - UIScrollView (SVPullToRefresh)
#import <objc/runtime.h>

static char UIScrollViewPullToRefreshView;

@implementation UIScrollView (SVPullToRefresh)

@dynamic pullToRefreshView, showsPullToRefresh;

- (void)addPullToRefreshWithActionHandler:(void (^)(void))actionHandler position:(SVPullToRefreshPosition)position {
    
    if(!self.pullToRefreshView) {
        CGFloat yOrigin;
        switch (position) {
            case SVPullToRefreshPositionTop:
                yOrigin = -SVPullToRefreshViewHeight;
                break;
            case SVPullToRefreshPositionBottom:
                yOrigin = self.contentSize.height;
                break;
            default:
                return;
        }
        
        SVPullToRefreshView * view = [[SVPullToRefreshView alloc] initWithFrame:CGRectMake(0, yOrigin, self.bounds.size.width, SVPullToRefreshViewHeight)];
        view.pullToRefreshActionHandler = actionHandler;
        view.scrollView = self;
        [self addSubview:view];
        [view release];
        
        view.originalTopInset = view.scrollView.contentInset.top;
        view.originalBottomInset = view.scrollView.contentInset.bottom;
        
        view.position = position;
        self.pullToRefreshView = view;
        self.showsPullToRefresh = YES;
    }
    
}

- (void)addPullToRefreshWithActionHandler:(void (^)(void))actionHandler {
    [self addPullToRefreshWithActionHandler:actionHandler position:SVPullToRefreshPositionTop];
}

- (void)triggerPullToRefresh {
    
    if (self.pullToRefreshView.state == SVPullToRefreshStateLoading) {
        return;
    }
    
    self.pullToRefreshView.state = SVPullToRefreshStateTriggered;
    [self.pullToRefreshView startAnimating];
}

- (void)setPullToRefreshView:(SVPullToRefreshView *)pullToRefreshView {
    [self willChangeValueForKey:@"SVPullToRefreshView"];
    objc_setAssociatedObject(self, &UIScrollViewPullToRefreshView,
                             pullToRefreshView,
                             OBJC_ASSOCIATION_ASSIGN);
    [self didChangeValueForKey:@"SVPullToRefreshView"];
}

- (SVPullToRefreshView *)pullToRefreshView {
    return objc_getAssociatedObject(self, &UIScrollViewPullToRefreshView);
}

- (void)setShowsPullToRefresh:(BOOL)showsPullToRefresh {
    self.pullToRefreshView.hidden = !showsPullToRefresh;
    
    if(!showsPullToRefresh) {
        if (self.pullToRefreshView.isObserving) {
            [self removeObserver:self.pullToRefreshView forKeyPath:@"contentOffset"];
            [self removeObserver:self.pullToRefreshView forKeyPath:@"contentSize"];
            [self removeObserver:self.pullToRefreshView forKeyPath:@"frame"];
            [self.pullToRefreshView resetScrollViewContentInset];
            self.pullToRefreshView.isObserving = NO;
        }
    }
    else {
        if (!self.pullToRefreshView.isObserving) {
            [self addObserver:self.pullToRefreshView forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
            [self addObserver:self.pullToRefreshView forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
            [self addObserver:self.pullToRefreshView forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:nil];
            self.pullToRefreshView.isObserving = YES;
            
            CGFloat yOrigin = 0;
            switch (self.pullToRefreshView.position) {
                case SVPullToRefreshPositionTop:
                    yOrigin = -SVPullToRefreshViewHeight;
                    break;
                case SVPullToRefreshPositionBottom:
                    yOrigin = self.contentSize.height;
                    break;
            }
            
            self.pullToRefreshView.frame = CGRectMake(0, yOrigin, self.bounds.size.width, SVPullToRefreshViewHeight);
        }
    }
}

- (BOOL)showsPullToRefresh {
    return !self.pullToRefreshView.hidden;
}

@end

#pragma mark - SVPullToRefresh
@implementation SVPullToRefreshView

// public properties
@synthesize pullToRefreshActionHandler, arrowColor, activityIndicatorViewColor, activityIndicatorViewStyle, lastUpdatedDate, dateFormatter;

@synthesize state = _state;
@synthesize scrollView = _scrollView;
@synthesize showsPullToRefresh = _showsPullToRefresh;
@synthesize arrow = _arrow;
@synthesize activityIndicatorView = _activityIndicatorView;

@synthesize dateLabel = _dateLabel;

-(void) dealloc
{
    self.pullToRefreshActionHandler = nil;
    
    self.viewForState = nil;
    
    self.arrowColor = nil;
    self.activityIndicatorViewColor = nil;
    
    self.lastUpdatedDate = nil;
    self.dateFormatter = nil;
    
    [super dealloc];
}

- (id)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        
        // default styling values
        self.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.state = SVPullToRefreshStateStopped;
        self.showsDateLabel = NO;
        
        self.viewForState = [NSMutableArray arrayWithObjects:@"", @"", @"", @"", nil];
        self.wasTriggeredByUser = YES;
    }
    
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (self.superview && newSuperview == nil) {
        //use self.superview, not self.scrollView. Why self.scrollView == nil here?
        UIScrollView *scrollView = (UIScrollView *)self.superview;
        if (scrollView.showsPullToRefresh) {
            if (self.isObserving) {
                //If enter this branch, it is the moment just before "SVPullToRefreshView's dealloc", so remove observer here
                [scrollView removeObserver:self forKeyPath:@"contentOffset"];
                [scrollView removeObserver:self forKeyPath:@"contentSize"];
                [scrollView removeObserver:self forKeyPath:@"frame"];
                self.isObserving = NO;
            }
        }
    }
}

- (void)layoutSubviews {
    
    for(id otherView in self.viewForState) {
        if([otherView isKindOfClass:[UIView class]])
            [otherView removeFromSuperview];
    }
    
    id customView = [self.viewForState objectAtIndex:self.state];
    BOOL hasCustomView = [customView isKindOfClass:[UIView class]];
    
    self.arrow.hidden = hasCustomView;
    
    if(hasCustomView) {
        [self addSubview:customView];
        CGRect viewBounds = [customView bounds];
        CGPoint origin = CGPointMake(roundf((self.bounds.size.width-viewBounds.size.width)/2), roundf((self.bounds.size.height-viewBounds.size.height)/2));
        
        [customView setFrame:CGRectMake(origin.x, origin.y, viewBounds.size.width, viewBounds.size.height)];
    }
    else {
        switch (self.state) {
            case SVPullToRefreshStateAll:
            case SVPullToRefreshStateStopped:
                
                self.arrow.alpha = 1;
                [self.activityIndicatorView stopAnimating];
                switch (self.position) {
                    case SVPullToRefreshPositionTop:
                        [self rotateArrow:0 hide:NO];
                        break;
                    case SVPullToRefreshPositionBottom:
                        [self rotateArrow:(float)M_PI hide:NO];
                        break;
                }
                break;
                
            case SVPullToRefreshStateTriggered:
                switch (self.position) {
                    case SVPullToRefreshPositionTop:
                        [self rotateArrow:(float)M_PI hide:NO];
                        break;
                    case SVPullToRefreshPositionBottom:
                        [self rotateArrow:0 hide:NO];
                        break;
                }
                break;
                
            case SVPullToRefreshStateLoading:
                
                // begin activity ani.
                
                [self.activityIndicatorView startAnimating];
                
                switch (self.position) {
                    case SVPullToRefreshPositionTop:
                        [self rotateArrow:0 hide:YES];
                        break;
                    case SVPullToRefreshPositionBottom:
                        [self rotateArrow:(float)M_PI hide:YES];
                        break;
                }
                break;
        }
        
        CGFloat arrowX = (self.bounds.size.width / 2) - (self.arrow.bounds.size.width) / 2;
        self.arrow.frame = CGRectMake(arrowX,
                                      (self.bounds.size.height / 2) - (self.arrow.bounds.size.height / 2),
                                      self.arrow.bounds.size.width,
                                      self.arrow.bounds.size.height);
        
        self.activityIndicatorView.center = self.arrow.center;
    }
}

#pragma mark - Scroll View

- (void)resetScrollViewContentInset {
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    switch (self.position) {
        case SVPullToRefreshPositionTop:
            currentInsets.top = self.originalTopInset;
            break;
        case SVPullToRefreshPositionBottom:
            currentInsets.bottom = self.originalBottomInset;
            currentInsets.top = self.originalTopInset;
            break;
    }
    
    [self setScrollViewContentInset:currentInsets];
}

- (void)setScrollViewContentInsetForLoading {
    
    CGFloat offset = MAX(self.scrollView.contentOffset.y * -1, 0);
    
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    switch (self.position) {
        case SVPullToRefreshPositionTop:
            currentInsets.top = MIN(offset, self.originalTopInset + self.bounds.size.height);
            break;
        case SVPullToRefreshPositionBottom:
            currentInsets.bottom = MIN(offset, self.originalBottomInset + self.bounds.size.height);
            break;
    }
    
    [self setScrollViewContentInset:currentInsets];
}

- (void)setScrollViewContentInset:(UIEdgeInsets)contentInset {
    
    LC_FAST_ANIMATIONS(0.25, ^{
       
        self.scrollView.contentInset = contentInset;
    });
}

#pragma mark - Observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if([keyPath isEqualToString:@"contentOffset"])
        [self scrollViewDidScroll:[[change valueForKey:NSKeyValueChangeNewKey] CGPointValue]];
    else if([keyPath isEqualToString:@"contentSize"]) {
        [self layoutSubviews];
        
        CGFloat yOrigin;
        switch (self.position) {
            case SVPullToRefreshPositionTop:
                yOrigin = -SVPullToRefreshViewHeight;
                break;
            case SVPullToRefreshPositionBottom:
                yOrigin = MAX(self.scrollView.contentSize.height, self.scrollView.bounds.size.height);
                break;
        }
        
        LC_FAST_ANIMATIONS(0.25, ^{
           
            self.frame = CGRectMake(0, yOrigin, self.bounds.size.width, SVPullToRefreshViewHeight);
        });
        
    }
    else if([keyPath isEqualToString:@"frame"])
        [self layoutSubviews];

}

- (void)scrollViewDidScroll:(CGPoint)contentOffset {
    
    if(self.state != SVPullToRefreshStateLoading) {
        CGFloat scrollOffsetThreshold = 0;
        switch (self.position) {
            case SVPullToRefreshPositionTop:
                scrollOffsetThreshold = self.frame.origin.y - self.originalTopInset;
                break;
            case SVPullToRefreshPositionBottom:
                scrollOffsetThreshold = MAX(self.scrollView.contentSize.height - self.scrollView.bounds.size.height, 0.0f) + self.bounds.size.height + self.originalBottomInset;
                break;
        }
        
        if(!self.scrollView.isDragging && self.state == SVPullToRefreshStateTriggered)
            self.state = SVPullToRefreshStateLoading;
        else if(contentOffset.y < scrollOffsetThreshold && self.scrollView.isDragging && self.state == SVPullToRefreshStateStopped && self.position == SVPullToRefreshPositionTop)
            self.state = SVPullToRefreshStateTriggered;
        else if(contentOffset.y >= scrollOffsetThreshold && self.state != SVPullToRefreshStateStopped && self.position == SVPullToRefreshPositionTop)
            self.state = SVPullToRefreshStateStopped;
        else if(contentOffset.y > scrollOffsetThreshold && self.scrollView.isDragging && self.state == SVPullToRefreshStateStopped && self.position == SVPullToRefreshPositionBottom)
            self.state = SVPullToRefreshStateTriggered;
        else if(contentOffset.y <= scrollOffsetThreshold && self.state != SVPullToRefreshStateStopped && self.position == SVPullToRefreshPositionBottom)
            self.state = SVPullToRefreshStateStopped;
    } else {
        CGFloat offset;
        UIEdgeInsets contentInset;
        switch (self.position) {
            case SVPullToRefreshPositionTop:
                offset = MAX(self.scrollView.contentOffset.y * -1, 0.0f);
                offset = MIN(offset, self.originalTopInset + self.bounds.size.height);
                contentInset = self.scrollView.contentInset;
                
                LC_FAST_ANIMATIONS(0.25, ^{
                    
                    self.scrollView.contentInset = UIEdgeInsetsMake(offset, contentInset.left, contentInset.bottom, contentInset.right);
                });
                
                break;
            case SVPullToRefreshPositionBottom:
                
                if (self.scrollView.contentSize.height >= self.scrollView.bounds.size.height) {
                    offset = MAX(self.scrollView.contentSize.height - self.scrollView.bounds.size.height + self.bounds.size.height, 0.0f);
                    offset = MIN(offset, self.originalBottomInset + self.bounds.size.height);
                    contentInset = self.scrollView.contentInset;
                    
                    LC_FAST_ANIMATIONS(0.25, ^{

                        self.scrollView.contentInset = UIEdgeInsetsMake(contentInset.top, contentInset.left, offset, contentInset.right);
                    });
                    
                } else if (self.wasTriggeredByUser) {
                    offset = MIN(self.bounds.size.height, self.originalBottomInset + self.bounds.size.height);
                    contentInset = self.scrollView.contentInset;
                    
                    LC_FAST_ANIMATIONS(0.25, ^{

                        self.scrollView.contentInset = UIEdgeInsetsMake(-offset, contentInset.left, contentInset.bottom, contentInset.right);
                    });
                }
                break;
        }
    }
}

#pragma mark - Getters

- (SVPullToRefreshArrow *)arrow {
    if(!_arrow) {
		_arrow = [[SVPullToRefreshArrow alloc] initWithFrame:CGRectMake(0, self.bounds.size.height/2-19/2, 19, 19)];
		[self addSubview:_arrow];
        [_arrow release];
    }
    return _arrow;
}

- (UIActivityIndicatorView *)activityIndicatorView {
    if(!_activityIndicatorView) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicatorView.hidesWhenStopped = YES;
        [self addSubview:_activityIndicatorView];
        [_activityIndicatorView release];
    }
    return _activityIndicatorView;
}

- (NSDateFormatter *)dateFormatter {
    if(!dateFormatter) {
        dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setDateStyle:NSDateFormatterShortStyle];
		[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
		dateFormatter.locale = [NSLocale currentLocale];
    }
    return dateFormatter;
}

- (UIColor *)arrowColor {
	return self.arrow.arrowColor; // pass through
}

- (UIColor *)activityIndicatorViewColor {
    return self.activityIndicatorView.color;
}

- (UIActivityIndicatorViewStyle)activityIndicatorViewStyle {
    return self.activityIndicatorView.activityIndicatorViewStyle;
}

#pragma mark - Setters

- (void)setArrowColor:(UIColor *)newArrowColor {
	self.arrow.arrowColor = newArrowColor; // pass through
	[self.arrow setNeedsDisplay];
}



- (void)setCustomView:(UIView *)view forState:(SVPullToRefreshState)state {
    id viewPlaceholder = view;
    
    if(!viewPlaceholder)
        viewPlaceholder = @"";
    
    if(state == SVPullToRefreshStateAll)
        [self.viewForState replaceObjectsInRange:NSMakeRange(0, 3) withObjectsFromArray:@[viewPlaceholder, viewPlaceholder, viewPlaceholder]];
    else
        [self.viewForState replaceObjectAtIndex:state withObject:viewPlaceholder];
    
    [self setNeedsLayout];
}

- (void)setActivityIndicatorViewColor:(UIColor *)color {
    self.activityIndicatorView.color = color;
}

- (void)setActivityIndicatorViewStyle:(UIActivityIndicatorViewStyle)viewStyle {
    self.activityIndicatorView.activityIndicatorViewStyle = viewStyle;
}

- (void)setLastUpdatedDate:(NSDate *)newLastUpdatedDate {
    self.showsDateLabel = YES;
    self.dateLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Last Updated: %@",), newLastUpdatedDate?[self.dateFormatter stringFromDate:newLastUpdatedDate]:NSLocalizedString(@"Never",)];
}

- (void)setDateFormatter:(NSDateFormatter *)newDateFormatter {
	dateFormatter = newDateFormatter;
    self.dateLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Last Updated: %@",), self.lastUpdatedDate?[newDateFormatter stringFromDate:self.lastUpdatedDate]:NSLocalizedString(@"Never",)];
}

#pragma mark -

- (void)triggerRefresh {
    
    [self.scrollView triggerPullToRefresh];
}

- (void)startAnimating{
    
    switch (self.position) {
        case SVPullToRefreshPositionTop:
            
            if(fequalzero(self.scrollView.contentOffset.y + self.originalTopInset)){
                
                LC_FAST_ANIMATIONS(0.25, ^{
                   
                    [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x, -(self.frame.size.height+self.originalTopInset)) animated:NO];
                });
                
                self.wasTriggeredByUser = NO;
            }
            else
                self.wasTriggeredByUser = YES;
            
            break;
        case SVPullToRefreshPositionBottom:
            
            if((fequalzero(self.scrollView.contentOffset.y) && self.scrollView.contentSize.height < self.scrollView.bounds.size.height)
               || fequal(self.scrollView.contentOffset.y, self.scrollView.contentSize.height - self.scrollView.bounds.size.height)) {
                        LC_FAST_ANIMATIONS(0.25, ^{

                
                            [self.scrollView setContentOffset:(CGPoint){.y = MAX(self.scrollView.contentSize.height - self.scrollView.bounds.size.height, 0.0f) + self.frame.size.height} animated:NO];
                    
                        });
                self.wasTriggeredByUser = NO;
            }
            else
                self.wasTriggeredByUser = YES;
            
            break;
    }
    
    self.state = SVPullToRefreshStateLoading;
}

- (void)stopAnimating {
    
    if (self.state == SVPullToRefreshStateStopped) {
        return;
    }
    
    self.state = SVPullToRefreshStateStopped;
    
    switch (self.position) {
        case SVPullToRefreshPositionTop:
            if(!self.wasTriggeredByUser)
            {
                LC_FAST_ANIMATIONS(0.25, ^{

                    [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x, -self.originalTopInset) animated:NO];
                });
            }
            break;
        case SVPullToRefreshPositionBottom:
            if(!self.wasTriggeredByUser)
            {
                LC_FAST_ANIMATIONS(0.25, ^{

                [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x, self.scrollView.contentSize.height - self.scrollView.bounds.size.height + self.originalBottomInset) animated:NO];
                });
            }
            break;
    }
}

- (void)setState:(SVPullToRefreshState)newState {
    
    if(_state == newState)
        return;
    
    SVPullToRefreshState previousState = _state;
    _state = newState;
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
    
    switch (newState) {
        case SVPullToRefreshStateAll:
        case SVPullToRefreshStateStopped:
            [self resetScrollViewContentInset];
            break;
            
        case SVPullToRefreshStateTriggered:
            break;
            
        case SVPullToRefreshStateLoading:
            
            [self setScrollViewContentInsetForLoading];
            
            if(previousState == SVPullToRefreshStateTriggered && pullToRefreshActionHandler)
                pullToRefreshActionHandler();
            
            break;
    }
}

- (void)rotateArrow:(float)degrees hide:(BOOL)hide {

    self.arrow.layer.opacity = !hide;

    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        
        self.arrow.layer.transform = CATransform3DMakeRotation(degrees, 0, 0, 1);
        //[self.arrow setNeedsDisplay];//ios 4
    } completion:NULL];
    
    if (degrees != 0) {
        
        self.activityIndicatorView.alpha = 0;
        self.activityIndicatorView.transform = CGAffineTransformScale(self.activityIndicatorView.transform, 1.6, 1.6);
        
        [UIView animateWithDuration:0.5 animations:^{
            
            self.activityIndicatorView.alpha = 1;
            self.activityIndicatorView.transform = CGAffineTransformIdentity;
            
        }];
    }
}

@end


#pragma mark - SVPullToRefreshArrow

@implementation SVPullToRefreshArrow

@synthesize arrowColor;

-(void) dealloc
{
    [arrowColor release];
    [super dealloc];
}

-(id) initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        
        self.backgroundColor = [[UIColor colorWithPatternImage:[[UIImage imageNamed:@"MS_small_arrow.png" useCache:YES] imageWithTintColor:LC_RGBA(211, 211, 211, 1)]] colorWithAlphaComponent:1];
    }
    
    return self;
}

- (UIColor *)arrowColor {
	if (arrowColor) return arrowColor;
	return [UIColor grayColor]; // default Color
}

//- (void)drawRect:(CGRect)rect {
//	CGContextRef c = UIGraphicsGetCurrentContext();
//	
//	// the rects above the arrow
//	CGContextAddRect(c, CGRectMake(5, 0, 12, 4)); // to-do: use dynamic points
//	CGContextAddRect(c, CGRectMake(5, 6, 12, 4)); // currently fixed size: 22 x 48pt
//	CGContextAddRect(c, CGRectMake(5, 12, 12, 4));
//	CGContextAddRect(c, CGRectMake(5, 18, 12, 4));
//	CGContextAddRect(c, CGRectMake(5, 24, 12, 4));
//	CGContextAddRect(c, CGRectMake(5, 30, 12, 4));
//	
//	// the arrow
//	CGContextMoveToPoint(c, 0, 34);
//	CGContextAddLineToPoint(c, 11, 48);
//	CGContextAddLineToPoint(c, 22, 34);
//	CGContextAddLineToPoint(c, 0, 34);
//	CGContextClosePath(c);
//	
//	CGContextSaveGState(c);
//	CGContextClip(c);
//	
//	// Gradient Declaration
//	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
//	CGFloat alphaGradientLocations[] = {0, 0.8f};
//    
//	CGGradientRef alphaGradient = nil;
//    if([[[UIDevice currentDevice] systemVersion]floatValue] >= 5){
//        NSArray* alphaGradientColors = [NSArray arrayWithObjects:
//                                        (id)[self.arrowColor colorWithAlphaComponent:0].CGColor,
//                                        (id)[self.arrowColor colorWithAlphaComponent:1].CGColor,
//                                        nil];
//        alphaGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)alphaGradientColors, alphaGradientLocations);
//    }else{
//        const CGFloat * components = CGColorGetComponents([self.arrowColor CGColor]);
//        size_t numComponents = CGColorGetNumberOfComponents([self.arrowColor CGColor]);
//        CGFloat colors[8];
//        switch(numComponents){
//            case 2:{
//                colors[0] = colors[4] = components[0];
//                colors[1] = colors[5] = components[0];
//                colors[2] = colors[6] = components[0];
//                break;
//            }
//            case 4:{
//                colors[0] = colors[4] = components[0];
//                colors[1] = colors[5] = components[1];
//                colors[2] = colors[6] = components[2];
//                break;
//            }
//        }
//        colors[3] = 0;
//        colors[7] = 1;
//        alphaGradient = CGGradientCreateWithColorComponents(colorSpace,colors,alphaGradientLocations,2);
//    }
//	
//	
//	CGContextDrawLinearGradient(c, alphaGradient, CGPointZero, CGPointMake(0, rect.size.height), 0);
//    
//	CGContextRestoreGState(c);
//	
//	CGGradientRelease(alphaGradient);
//	CGColorSpaceRelease(colorSpace);
//}
@end
