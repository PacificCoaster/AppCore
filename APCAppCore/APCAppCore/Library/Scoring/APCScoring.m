// 
//  APCScoring.m 
//  APCAppCore 
// 
// Copyright (c) 2015, Apple Inc. All rights reserved. 
// 
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// 
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
// 
// 2.  Redistributions in binary form must reproduce the above copyright notice, 
// this list of conditions and the following disclaimer in the documentation and/or 
// other materials provided with the distribution. 
// 
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors 
// may be used to endorse or promote products derived from this software without 
// specific prior written permission. No license is granted to the trademarks of 
// the copyright holders even if such marks are included in this software. 
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE 
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
// 
 
#import "APCScoring.h"
#import "APCAppCore.h"

NSString *const kDatasetDateKey        = @"datasetDateKey";
NSString *const kDatasetValueKey       = @"datasetValueKey";
NSString *const kDatasetRangeValueKey  = @"datasetRangeValueKey";

static NSString *const kDatasetSortKey        = @"datasetSortKey";
static NSString *const kDatasetValueKindKey   = @"datasetValueKindKey";
static NSString *const kDatasetValueNoDataKey = @"datasetValueNoDataKey";
static NSString *const kDatasetGroupByDay     = @"datasetGroupByDay";
static NSString *const kDatasetGroupByWeek    = @"datasetGroupByWeek";
static NSString *const kDatasetGroupByMonth   = @"datasetGroupByMonth";
static NSString *const kDatasetGroupByYear    = @"datasetGroupByYear";

@interface APCScoring()

@property (nonatomic, strong) NSMutableArray *dataPoints;
@property (nonatomic, strong) NSMutableArray *updatedDataPoints;
@property (nonatomic, strong) NSMutableArray *correlateDataPoints;
@property (nonatomic, strong) NSArray *timeline;

@property (nonatomic) NSUInteger current;
@property (nonatomic) NSUInteger correlatedCurrent;
@property (nonatomic) BOOL hasCorrelateDataPoints;
@property (nonatomic) BOOL usesHealthKitData;

@property (nonatomic, strong) NSString *taskId;
@property (nonatomic, strong) NSString *valueKey;
@property (nonatomic, strong) NSString *dataKey;
@property (nonatomic, strong) NSString *sortKey;

@property (nonatomic, strong) HKQuantityType *quantityType;
@property (nonatomic, strong) HKUnit *hkUnit;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

@implementation APCScoring

/*
 * @usage  APHScoring.h should be imported.
 *
 *   There are two ways to get data, Core Data and HealthKit. Each source can
 *
 *   For Core Data:
 *      APHScoring *scoring = [APHScoring alloc] initWithTaskId:taskId numberOfDays:-5 valueKey:@"value";
 *
 *   For HealthKit:
 *      APHScoring *scoring = [APHScoring alloc] initWithHealthKitQuantityType:[HKQuantityType ...] numberOfDays:-5
 *
 *   NSLog(@"Score Min: %f", [[scoring minimumDataPoint] doubleValue]);
 *   NSLog(@"Score Max: %f", [[scoring maximumDataPoint] doubleValue]);
 *   NSLog(@"Score Avg: %f", [[scoring averageDataPoint] doubleValue]);
 *
 *   NSDictionary *score = nil;
 *   while (score = [scoring nextObject]) {
 *       NSLog(@"Score: %f", [[score valueForKey:@"value"] doubleValue]);
 *   }
 */

- (void)sharedInit:(NSInteger)days
{
    _dataPoints = [NSMutableArray array];
    _updatedDataPoints = [NSMutableArray array];
    _correlateDataPoints = [NSMutableArray array];
    _hasCorrelateDataPoints = NO;
    _usesHealthKitData = YES;
    
    _quantityType = nil;
    _hkUnit = nil;
    
    _taskId = nil;
    _valueKey = nil;
    _dataKey = nil;
    _sortKey = nil;
    
    _customMaximumPoint = CGFLOAT_MAX;
    _customMinimumPoint = CGFLOAT_MIN;
    
    if (!self.dateFormatter) {
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
    }
    
    _timeline = [self configureTimelineForDays:days groupBy:APHTimelineGroupDay]; //[self configureTimelineForDays:days];
    
    [self generateEmptyDataset];
}

- (HKHealthStore *)healthStore
{
    return ((APCAppDelegate*) [UIApplication sharedApplication].delegate).dataSubstrate.healthStore;
}

/**
 * @brief   Returns an instance of APHScoring.
 *
 * @param   taskId          The ID of the task whoes data needs to be displayed
 *
 * @param   numberOfDays    Number of days that the data is needed. Negative will produce data
 *                          from past and positive will yeild future days.
 *
 * @param   valueKey        The key that is used for storing data
 *
 */

- (instancetype)initWithTask:(NSString *)taskId numberOfDays:(NSInteger)numberOfDays valueKey:(NSString *)valueKey latestOnly:(BOOL)latestOnly
{
    self = [self initWithTask:taskId
                 numberOfDays:numberOfDays
                     valueKey:valueKey
                      dataKey:nil
                      sortKey:nil
                   latestOnly:latestOnly
                      groupBy:APHTimelineGroupDay];
    return self;
}

- (instancetype)initWithTask:(NSString *)taskId numberOfDays:(NSInteger)numberOfDays valueKey:(NSString *)valueKey
{
    self = [self initWithTask:taskId numberOfDays:numberOfDays valueKey:valueKey dataKey:nil sortKey:nil groupBy:APHTimelineGroupDay];
    
    return self;
}

- (instancetype)initWithTask:(NSString *)taskId numberOfDays:(NSInteger)numberOfDays valueKey:(NSString *)valueKey dataKey:(NSString *)dataKey
{
    self = [self initWithTask:taskId numberOfDays:numberOfDays valueKey:valueKey dataKey:dataKey sortKey:nil groupBy:APHTimelineGroupDay];
    
    return self;
}

- (instancetype)initWithTask:(NSString *)taskId
                numberOfDays:(NSInteger)numberOfDays
                    valueKey:(NSString *)valueKey
                     dataKey:(NSString *)dataKey
                     sortKey:(NSString *)sortKey
{
    self = [self initWithTask:taskId
                 numberOfDays:numberOfDays
                     valueKey:valueKey
                      dataKey:dataKey
                      sortKey:sortKey
                   latestOnly:YES
                   groupBy:APHTimelineGroupDay];
    
    return self;
}

- (instancetype)initWithTask:(NSString *)taskId
                numberOfDays:(NSInteger)numberOfDays
                    valueKey:(NSString *)valueKey
                     dataKey:(NSString *)dataKey
                     sortKey:(NSString *)sortKey
                     groupBy:(APHTimelineGroups)groupBy
{
    self = [self initWithTask:taskId
                 numberOfDays:numberOfDays
                     valueKey:valueKey
                      dataKey:dataKey
                      sortKey:sortKey
                   latestOnly:YES
                      groupBy:groupBy];
    return self;
}

- (instancetype)initWithTask:(NSString *)taskId
                numberOfDays:(NSInteger)numberOfDays
                    valueKey:(NSString *)valueKey
                     dataKey:(NSString *)dataKey
                     sortKey:(NSString *)sortKey
                  latestOnly:(BOOL)latestOnly
                     groupBy:(APHTimelineGroups)groupBy
{
    self = [super init];
    
    if (self) {
        NSInteger days = numberOfDays + 1;
        [self sharedInit:days];
        
        _usesHealthKitData = NO;
        
        _taskId = taskId;
        _valueKey = valueKey;
        _dataKey = dataKey;
        _sortKey = sortKey;
        
        [self queryTaskId:taskId
                  forDays:days
                 valueKey:valueKey
                  dataKey:dataKey
                  sortKey:sortKey
               latestOnly:latestOnly
                  groupBy:groupBy
               completion:nil];
    }
    
    return self;
}

/**
 * @brief   Returns an instance of APHScoring.
 *
 * @param   quantityType    The HealthKit quantity type.
 *
 * @param   unit            The unit that is compatible with the the quantity type that is provided.
 *
 * @param   numberOfDays    Number of days that the data is needed. Negative will produce data
 *                          from past and positive will yeild future days.
 *
 */
- (instancetype)initWithHealthKitQuantityType:(HKQuantityType *)quantityType
                                         unit:(HKUnit *)unit
                                 numberOfDays:(NSInteger)numberOfDays
{
    self = [self initWithHealthKitQuantityType:quantityType
                                          unit:unit
                                  numberOfDays:numberOfDays
                                       groupBy:APHTimelineGroupDay];
    return self;
}

- (instancetype)initWithHealthKitQuantityType:(HKQuantityType *)quantityType
                                         unit:(HKUnit *)unit
                                 numberOfDays:(NSInteger)numberOfDays
                                      groupBy:(APHTimelineGroups) __unused groupBy
{
    self = [super init];
    
    if (self) {
        NSInteger days = numberOfDays + 1;
        [self sharedInit:days];
        
        // The very first thing that we need to make sure is that
        // the unit and quantity types are compatible
        if ([quantityType isCompatibleWithUnit:unit]) {
            _quantityType = quantityType;
            _hkUnit = unit;
            [self statsCollectionQueryForQuantityType:quantityType unit:unit forDays:days];
        } else {
            NSAssert([quantityType isCompatibleWithUnit:unit], @"The quantity and the unit must be compatible");
        }
    }
    
    return self;
}

- (void)updatePeriodForDays:(NSInteger)numberOfDays
                    groupBy:(APHTimelineGroups)groupBy
      withCompletionHandler:(void (^)(void))completion
{
    NSInteger days = numberOfDays + 1;
    
    if (self.usesHealthKitData) {
        if ([self.quantityType isCompatibleWithUnit:self.hkUnit]) {
            
            [self updateStatsCollectionForQuantityType:self.quantityType
                                                  unit:self.hkUnit
                                               forDays:days
                                               groupBy:groupBy
                                            completion:completion];
        } else {
            NSAssert([self.quantityType isCompatibleWithUnit:self.hkUnit], @"The quantity and the unit must be compatible");
        }
    } else {
        // Update the timeline based on the number of days requested.
        self.timeline = [self configureTimelineForDays:days groupBy:groupBy];
        
        // Update the generated dataset to be inline with the timeline.
        [self generateEmptyDataset];
        
        [self queryTaskId:self.taskId
                    forDays:days
                 valueKey:self.valueKey
                  dataKey:self.dataKey
                  sortKey:self.sortKey
               latestOnly:YES
                  groupBy:groupBy
               completion:completion];
    }
}

#pragma mark - Helpers

- (NSArray *)configureTimelineForDays:(NSInteger)days
{
    NSMutableArray *timeline = [NSMutableArray array];
    
    for (NSInteger day = days; day <= 0; day++) {
        NSDate *timelineDate = [self dateForSpan:day];
        [timeline addObject:timelineDate];
    }
    
    return timeline;
}

- (NSArray *)configureTimelineForDays:(NSInteger)days groupBy:(NSUInteger)groupBy
{
    NSMutableArray *timeline = [NSMutableArray array];
    
    if (groupBy == APHTimelineGroupDay) {
        for (NSInteger day = days; day <= 0; day++) {
            NSDate *timelineDate = [self dateForSpan:day];
            [timeline addObject:timelineDate];
        }
    } else if (groupBy == APHTimelineGroupWeek) {
        for (NSInteger day = days; day <= 0; day += 7) {
            NSDate *timelineDate = [self dateForSpan:day];
            [timeline addObject:timelineDate];
        }
    } else if (groupBy == APHTimelineGroupMonth) {
        for (NSInteger day = days; day <= 0; day += 30) {
            NSDate *timelineDate = [self dateForSpan:day];
            [timeline addObject:timelineDate];
        }
    } else {
        for (NSInteger day = days; day <= 0; day += 365) {
            NSDate *timelineDate = [self dateForSpan:day];
            [timeline addObject:timelineDate];
        }
    }
    
    return timeline;
}

- (void)generateEmptyDataset
{
    // clear out the datapoints
    [self.dataPoints removeAllObjects];
    
    for (NSDate *day in self.timeline) {
        NSDate *timelineDay = [[NSCalendar currentCalendar] dateBySettingHour:0
                                                                       minute:0
                                                                       second:0
                                                                       ofDate:day
                                                                      options:0];
        
        [self.dataPoints addObject:[self generateDataPointForDate:timelineDay
                                                        withValue:@(NSNotFound)
                                                      noDataValue:YES]];
    }
}

- (NSDictionary *)generateDataPointForDate:(NSDate *)pointDate
                                 withValue:(NSNumber *)pointValue
                               noDataValue:(BOOL)noDataValue
{
    NSInteger weekNumber  = [[[NSCalendar currentCalendar] components:NSCalendarUnitWeekOfYear fromDate:pointDate] weekOfYear];
    NSInteger monthNumber = [[[NSCalendar currentCalendar] components:NSCalendarUnitMonth fromDate:pointDate] month];
    NSInteger yearNumber  = [[[NSCalendar currentCalendar] components:NSCalendarUnitYear fromDate:pointDate] year];
    
    return @{
             kDatasetDateKey: pointDate,
             kDatasetValueKey: pointValue,
             kDatasetValueNoDataKey: @(noDataValue),
             kDatasetGroupByDay: pointDate,
             kDatasetGroupByWeek: @(weekNumber),
             kDatasetGroupByMonth: @(monthNumber),
             kDatasetGroupByYear: @(yearNumber)
             };
}

- (void)addDataPointToTimeline:(NSDictionary *)dataPoint
{
    if ([dataPoint[kDatasetValueKey] integerValue] != 0) {
        NSDate *pointDate = [[NSCalendar currentCalendar] dateBySettingHour:0
                                                                     minute:0
                                                                     second:0
                                                                     ofDate:[dataPoint valueForKey:kDatasetDateKey]
                                                                    options:0];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %@", kDatasetDateKey, pointDate];
        NSArray *matches = [self.dataPoints filteredArrayUsingPredicate:predicate];
        
        if ([matches count] > 0) {
            NSUInteger pointIndex = [self.dataPoints indexOfObject:[matches firstObject]];
            NSMutableDictionary *point = [[self.dataPoints objectAtIndex:pointIndex] mutableCopy];
            
            point[kDatasetValueKey] = dataPoint[kDatasetValueKey];
            point[kDatasetValueNoDataKey] = dataPoint[kDatasetValueNoDataKey];
            
            if (dataPoint[kDatasetRangeValueKey]) {
                point[kDatasetRangeValueKey] = dataPoint[kDatasetRangeValueKey];
            }
            
            [self.dataPoints replaceObjectAtIndex:pointIndex withObject:point];
        }
    }
}

#pragma mark - Queries
#pragma mark Core Data

- (void)queryTaskId:(NSString *)taskId
            forDays:(NSInteger)days
           valueKey:(NSString *)valueKey
            dataKey:(NSString *)dataKey
            sortKey:(NSString *)sortKey
         latestOnly:(BOOL)latestOnly
            groupBy:(APHTimelineGroups)groupBy
         completion:(void (^)(void))completion
{
    APCAppDelegate *appDelegate = (APCAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"startOn"
                                                                   ascending:YES];
    
    NSFetchRequest *request = [APCScheduledTask request];
    
    NSDate *startDate = [[NSCalendar currentCalendar] dateBySettingHour:0
                                                                 minute:0
                                                                 second:0
                                                                 ofDate:[self dateForSpan:days]
                                                                options:0];
    
    NSDate *endDate = [[NSCalendar currentCalendar] dateBySettingHour:23
                                                               minute:59
                                                               second:59
                                                               ofDate:[NSDate date]
                                                              options:0];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(task.taskID == %@) AND (startOn >= %@) AND (startOn <= %@)",
                              taskId, startDate, endDate];
    
    request.predicate = predicate;
    request.sortDescriptors = @[sortDescriptor];
    
    NSError *error = nil;
    
    NSManagedObjectContext * localContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    localContext.parentContext = appDelegate.dataSubstrate.persistentContext;
    
    NSArray *tasks = [localContext executeFetchRequest:request error:&error];
    
    for (APCScheduledTask *task in tasks) {
        if ([task.completed boolValue]) {
            NSArray *taskResults = [self retrieveResultSummaryFromResults:task.results latestOnly:latestOnly];
            
            for (NSDictionary *taskResult in taskResults) {
                if (taskResult) {
                    NSDate *pointDate = [[NSCalendar currentCalendar] dateBySettingHour:0
                                                                                 minute:0
                                                                                 second:0
                                                                                 ofDate:task.startOn
                                                                                options:0];
                    
                    id taskResultValue = [taskResult valueForKey:valueKey];
                    NSNumber *taskValue = nil;
                    
                    if ([taskResultValue isKindOfClass:[NSNull class]] || !taskResultValue) {
                        taskValue = @(NSNotFound);
                    } else {
                        taskValue = (NSNumber *)taskResultValue;
                    }
                    
                    NSMutableDictionary *dataPoint = nil;
                    
                    if (groupBy == APHTimelineGroupForInsights) {
                        dataPoint = [[self generateDataPointForDate:pointDate
                                                          withValue:taskValue
                                                        noDataValue:YES] mutableCopy];
                        dataPoint[@"raw"] = taskResult;
                    } else {
                        if (!dataKey) {
                            dataPoint = [[self generateDataPointForDate:pointDate
                                                              withValue:taskValue
                                                            noDataValue:YES] mutableCopy];
                            dataPoint[kDatasetSortKey] = (sortKey) ? [taskResult valueForKey:sortKey] : [NSNull null];
                            
                        } else {
                            NSDictionary *nestedData = [taskResult valueForKey:dataKey];
                            
                            if (nestedData) {
                                dataPoint = [[self generateDataPointForDate:pointDate
                                                                  withValue:taskValue
                                                                noDataValue:YES] mutableCopy];
                                dataPoint[kDatasetSortKey] = (sortKey) ? [taskResult valueForKey:sortKey] : [NSNull null];
                            }
                        }
                    }
                    [self.dataPoints addObject:dataPoint];
                }
            }
        }
    }
    
    if ([self.dataPoints count] != 0) {
        if (sortKey) {
            NSSortDescriptor *sortBy = [[NSSortDescriptor alloc] initWithKey:kDatasetSortKey ascending:YES];
            NSArray *sortedDataPoints = [self.dataPoints sortedArrayUsingDescriptors:@[sortBy]];
            
            self.dataPoints = [sortedDataPoints mutableCopy];
        }
        
        if (groupBy == APHTimelineGroupDay) {
            [self groupDatasetByDay];
        } else {
            [self groupDatasetbyPeriod:groupBy];
        }
    }
    
    if (completion) {
        completion();
    }
}

- (NSArray *)retrieveResultSummaryFromResults:(NSSet *)results latestOnly:(BOOL)latestOnly
{
    NSArray *scheduledTaskResults = [results allObjects];
    
    // sort the results in a decsending order,
    // in case there are more than one result for a meal time.
    NSSortDescriptor *sortByCreateAtDescending = [[NSSortDescriptor alloc] initWithKey:@"createdAt"
                                                                             ascending:NO];
    
    NSArray *sortedScheduleTaskresults = [scheduledTaskResults sortedArrayUsingDescriptors:@[sortByCreateAtDescending]];
    
    // We are iterating throught the results because:
    // a.) There could be more than one result
    // b.) In case the last result is nil, we will pick the next result that has a value.
    NSMutableArray *allResultSummaries = [NSMutableArray new];
    
    for (APCResult *result in sortedScheduleTaskresults) {
        NSString *resultSummary = [result resultSummary];
        
        if (resultSummary) {
            
            NSData *resultData = [resultSummary dataUsingEncoding:NSUTF8StringEncoding];
            NSError *error = nil;
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:resultData
                                                                   options:NSJSONReadingAllowFragments
                                                                     error:&error];
            
            [allResultSummaries addObject:result];
            
            if (latestOnly) {
                break;
            }
        }
    }
    
    return allResultSummaries;
}

- (void)groupDatasetByDay
{
    NSMutableArray *groupedDataset = [NSMutableArray array];
    NSArray *days = [self.dataPoints valueForKeyPath:@"@distinctUnionOfObjects.datasetDateKey"];
    
    for (NSString *day in days) {
        NSMutableDictionary *entry = [NSMutableDictionary dictionary];
        [entry setObject:day forKey:kDatasetDateKey];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(%K = %@) and (%K <> %@)", kDatasetDateKey, day, kDatasetValueKey, @(NSNotFound)];
        NSArray *groupItems = [self.dataPoints filteredArrayUsingPredicate:predicate];
        
        double itemSum = 0;
        double dayAverage = 0;
        
        for (NSDictionary *item in groupItems) {
            NSNumber *value = [item valueForKey:kDatasetValueKey];
            
            if ([value integerValue] != NSNotFound) {
                itemSum += [value doubleValue];
            }
        }
        
        if (groupItems.count != 0) {
            dayAverage = itemSum / groupItems.count;
        }
        
        if (dayAverage == 0) {
            dayAverage = NSNotFound;
        }
        
        // Set the min/max for the data
        APCRangePoint *rangePoint = [APCRangePoint new];
        
        if (dayAverage != NSNotFound) {
            NSNumber *dataMinValue = [groupItems valueForKeyPath:@"@min.datasetValueKey"];
            NSNumber *dataMaxValue = [groupItems valueForKeyPath:@"@max.datasetValueKey"];
            
            rangePoint.minimumValue = [dataMinValue floatValue];
            rangePoint.maximumValue = [dataMaxValue floatValue];
        }
        
        [entry setObject:@(dayAverage) forKey:kDatasetValueKey];
        [entry setObject:rangePoint forKey:kDatasetRangeValueKey];
        
        [groupedDataset addObject:entry];
    }
    
    // resort the grouped dataset by date
    NSSortDescriptor *sortByDate = [[NSSortDescriptor alloc] initWithKey:kDatasetDateKey
                                                               ascending:YES];
    [groupedDataset sortUsingDescriptors:@[sortByDate]];
    
    [self.dataPoints removeAllObjects];
    [self.dataPoints addObjectsFromArray:groupedDataset];
}

- (void)groupDatasetbyPeriod:(APHTimelineGroups)period
{
    NSDateComponents *groupDateComponents = [[NSDateComponents alloc] init];
    
    for (NSDate *groupStartDate in self.timeline) {
        NSDate *groupEndDate   = nil;
        
        // Set start and end date for the grouping period
        NSInteger weekNumber  = [[[NSCalendar currentCalendar] components:NSCalendarUnitWeekOfYear fromDate:groupStartDate] weekOfYear];
        NSInteger monthNumber = [[[NSCalendar currentCalendar] components:NSCalendarUnitMonth fromDate:groupStartDate] month];
        NSInteger yearNumber  = [[[NSCalendar currentCalendar] components:NSCalendarUnitYear fromDate:groupStartDate] year];
        
        if (period == APHTimelineGroupWeek) {
            groupDateComponents.weekday = 7;
            groupDateComponents.weekOfYear = weekNumber;
            groupDateComponents.year = yearNumber;
            
            groupEndDate = [[NSCalendar currentCalendar] dateFromComponents:groupDateComponents];
        } else if (period == APHTimelineGroupMonth) {
            groupDateComponents.month = monthNumber;
            groupEndDate = [[NSCalendar currentCalendar] dateFromComponents:groupDateComponents];
        } else { // defaults to Day
            groupEndDate = groupStartDate;
        }
        
        // filter data points that are between the start and end dates
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(%K >= %@) AND (%K <= %@)",
                                  kDatasetDateKey, groupStartDate,
                                  kDatasetDateKey, groupEndDate];
        NSArray *groupedPoints = [self.dataPoints filteredArrayUsingPredicate:predicate];
        
        double itemSum = 0;
        double dayAverage = 0;
        
        for (NSDictionary *dataPoint in groupedPoints) {
            NSNumber *value = [dataPoint valueForKey:kDatasetValueKey];
            
            if ([value integerValue] != NSNotFound) {
                itemSum += [value doubleValue];
            }
            
            if (groupedPoints.count != 0) {
                dayAverage = itemSum / groupedPoints.count;
            }
            
            if (dayAverage == 0) {
                dayAverage = NSNotFound;
            }
        }
    }
}


#pragma mark HealthKit

- (void)statsCollectionQueryForQuantityType:(HKQuantityType *)quantityType
                                       unit:(HKUnit *)unit
                                    forDays:(NSInteger)days
{
    NSDateComponents *interval = [[NSDateComponents alloc] init];
    interval.day = 1;
    
    NSDate *startDate = [[NSCalendar currentCalendar] dateBySettingHour:0
                                                                 minute:0
                                                                 second:0
                                                                 ofDate:[self dateForSpan:days]
                                                                options:0];
    
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:[NSDate date] options:HKQueryOptionStrictEndDate];
    
    BOOL isDecreteQuantity = ([quantityType aggregationStyle] == HKQuantityAggregationStyleDiscrete);
    
    HKStatisticsOptions queryOptions;
    
    if (isDecreteQuantity) {
        queryOptions = HKStatisticsOptionDiscreteAverage | HKStatisticsOptionDiscreteMax | HKStatisticsOptionDiscreteMin;
    } else {
        queryOptions = HKStatisticsOptionCumulativeSum;
    }
    
    HKStatisticsCollectionQuery *query = [[HKStatisticsCollectionQuery alloc] initWithQuantityType:quantityType
                                                                           quantitySamplePredicate:predicate
                                                                                           options:queryOptions
                                                                                        anchorDate:startDate
                                                                                intervalComponents:interval];
    
    // set the results handler
    query.initialResultsHandler = ^(HKStatisticsCollectionQuery * __unused query,
                                    HKStatisticsCollection *results,
                                    NSError *error) {
        if (!error) {
            NSDate *endDate = [[NSCalendar currentCalendar] dateBySettingHour:23
                                                                       minute:59
                                                                       second:59
                                                                       ofDate:[NSDate date]
                                                                      options:0];
            NSDate *beginDate = startDate;
            
            [results enumerateStatisticsFromDate:beginDate
                                          toDate:endDate
                                       withBlock:^(HKStatistics *result, BOOL * __unused stop) {
                                           HKQuantity *quantity;
                                           NSMutableDictionary *dataPoint = [NSMutableDictionary new];
                                           APCRangePoint *rangePoint = [APCRangePoint new];
                                           
                                           if (isDecreteQuantity) {
                                               quantity = result.averageQuantity;
                                               
                                               if (result.minimumQuantity) {
                                                   rangePoint.minimumValue = [result.minimumQuantity doubleValueForUnit:unit];
                                               }
                                               
                                               if (result.maximumQuantity) {
                                                   rangePoint.maximumValue = [result.maximumQuantity doubleValueForUnit:unit];
                                               }
                                               
                                               dataPoint[kDatasetRangeValueKey] = rangePoint;
                                           } else {
                                               quantity = result.sumQuantity;
                                           }
                                           
                                           NSDate *date = result.startDate;
                                           double value = [quantity doubleValueForUnit:unit];
                                           
                                           dataPoint[kDatasetDateKey] = date;
                                           dataPoint[kDatasetValueKey] = (!quantity) ? @(NSNotFound) : @(value);
                                           dataPoint[kDatasetValueNoDataKey] = (isDecreteQuantity) ? @(YES) : @(NO);
                                           
                                           [self addDataPointToTimeline:dataPoint];
                                       }];
            
            [self dataIsAvailableFromHealthKit];
        }
    };
    
    [self.healthStore executeQuery:query];
}

- (void)updateStatsCollectionForQuantityType:(HKQuantityType *)quantityType
                                        unit:(HKUnit *)unit
                                     forDays:(NSInteger)days
                                     groupBy:(APHTimelineGroups)groupBy
                                  completion:(void (^)(void))completion
{
    [self.updatedDataPoints removeAllObjects];
    
    NSDateComponents *interval = [[NSDateComponents alloc] init];
    
    // 5D, 1W, 1M, 3M, 6M, 1Y
    if (groupBy == APHTimelineGroupDay) {
        interval.day = 1;
    } else if (groupBy == APHTimelineGroupWeek) {
        interval.day = 7;
    } else if (groupBy == APHTimelineGroupMonth) {
        interval.month = 1;
    } else {
        interval.year = 1;
    }
    
    NSDate *startDate = [[NSCalendar currentCalendar] dateBySettingHour:0
                                                                 minute:0
                                                                 second:0
                                                                 ofDate:[self dateForSpan:days]
                                                                options:0];
    
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:[NSDate date] options:HKQueryOptionStrictEndDate];
    
    BOOL isDecreteQuantity = ([quantityType aggregationStyle] == HKQuantityAggregationStyleDiscrete);
    
    HKStatisticsOptions queryOptions;
    
    if (isDecreteQuantity) {
        queryOptions = HKStatisticsOptionDiscreteAverage;
    } else {
        queryOptions = HKStatisticsOptionCumulativeSum;
    }
    
    HKStatisticsCollectionQuery *query = [[HKStatisticsCollectionQuery alloc] initWithQuantityType:quantityType
                                                                           quantitySamplePredicate:predicate
                                                                                           options:queryOptions
                                                                                        anchorDate:startDate
                                                                                intervalComponents:interval];
    
    // set the results handler
    query.initialResultsHandler = ^(HKStatisticsCollectionQuery * __unused query, HKStatisticsCollection *results, NSError *error) {
        if (!error) {
            NSDate *endDate = [[NSCalendar currentCalendar] dateBySettingHour:23
                                                                       minute:59
                                                                       second:59
                                                                       ofDate:[NSDate date]
                                                                      options:0];
            NSDate *beginDate = startDate;
            
            [results enumerateStatisticsFromDate:beginDate
                                          toDate:endDate
                                       withBlock:^(HKStatistics *result, BOOL * __unused stop) {
                                           HKQuantity *quantity;
                                           
                                           if (isDecreteQuantity) {
                                               quantity = result.averageQuantity;
                                           } else {
                                               quantity = result.sumQuantity;
                                           }
                                           
                                           NSDate *date = result.startDate;
                                           double value = [quantity doubleValueForUnit:unit];
                                           
                                           NSDictionary *dataPoint = @{
                                                                       kDatasetDateKey: date,
                                                                       kDatasetValueKey: (!quantity) ? @(NSNotFound) : @(value),
                                                                       kDatasetValueNoDataKey: (isDecreteQuantity) ? @(YES) : @(NO)
                                                                       };
                                           
                                           //[self addDataPointToTimeline:dataPoint];
                                           [self.updatedDataPoints addObject:dataPoint];
                                       }];
            
            [self.dataPoints removeAllObjects];
            
            // Redo the timeline
            NSMutableArray *updatedTimeline = [NSMutableArray new];
            
            for (NSDictionary *point in self.updatedDataPoints) {
                [updatedTimeline addObject:[point valueForKey:kDatasetDateKey]];
            }
            
            self.timeline = updatedTimeline;
            [self.dataPoints addObjectsFromArray:self.updatedDataPoints];
            
            if (completion) {
                completion();
            }
        }
    };
    
    [self.healthStore executeQuery:query];
}

- (void)dataIsAvailableFromHealthKit
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:APCScoringHealthKitDataIsAvailableNotification
                                                            object:self.dataPoints];
    });
}

/**
 * @brief   Returns an NSDate that is past/future by the value of daySpan.
 *
 * @param   daySpan Number of days relative to current date.
 *                  If negative, date will be number of days in the past;
 *                  otherwise the date will be number of days in the future.
 *
 * @return  Returns the date as NSDate.
 */
- (NSDate *)dateForSpan:(NSInteger)daySpan
{
    NSDateComponents *components = [[NSDateComponents alloc] init];
    [components setDay:daySpan];
    
    NSDate *spanDate = [[NSCalendar currentCalendar] dateByAddingComponents:components
                                                                     toDate:[NSDate date]
                                                                    options:0];
    return spanDate;
}

#pragma mark - Min/Max/Avg

- (NSNumber *)minimumDataPoint
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K <> %@", kDatasetValueKey, @(NSNotFound)];
    NSArray *filteredArray = [self.dataPoints filteredArrayUsingPredicate:predicate];
    
    NSArray *rangeArray = [filteredArray valueForKey:kDatasetRangeValueKey];
    NSPredicate *rangePredicate = [NSPredicate predicateWithFormat:@"SELF <> %@", [NSNull null]];
    
    NSArray *rangePoints = [rangeArray filteredArrayUsingPredicate:rangePredicate];
    
    NSNumber *minValue = nil;
    
    if (rangePoints.count != 0) {
        minValue = [rangeArray valueForKeyPath:@"@min.minimumValue"];
    } else {
        minValue = [filteredArray valueForKeyPath:@"@min.datasetValueKey"];
    }
    
    return minValue;
}

- (NSNumber *)maximumDataPoint
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K <> %@", kDatasetValueKey, @(NSNotFound)];

    NSArray *filteredArray = [self.dataPoints filteredArrayUsingPredicate:predicate];
    NSArray *rangeArray = [filteredArray valueForKey:kDatasetRangeValueKey];
    NSPredicate *rangePredicate = [NSPredicate predicateWithFormat:@"SELF <> %@", [NSNull null]];
    
    NSArray *rangePoints = [rangeArray filteredArrayUsingPredicate:rangePredicate];
    
    NSNumber *maxValue = nil;
    
    if (rangePoints.count != 0) {
        maxValue = [rangeArray valueForKeyPath:@"@max.maximumValue"];
    } else {
        maxValue = [filteredArray valueForKeyPath:@"@max.datasetValueKey"];
    }
    
    return maxValue;
}

- (NSNumber *)averageDataPoint
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K <> %@", kDatasetValueKey, @(NSNotFound)];
    NSArray *filteredArray = [self.dataPoints filteredArrayUsingPredicate:predicate];
    
    NSNumber *avgValue = [filteredArray valueForKeyPath:@"@avg.datasetValueKey"];
    
    return avgValue;
}

#pragma mark - Object related methods

- (id)nextObject
{
    id nextPoint = nil;
    
    if (self.current < [self.dataPoints count]) {
        nextPoint = [self.dataPoints objectAtIndex:self.current++];
    } else {
        self.current = 0;
        nextPoint = [self.dataPoints objectAtIndex:self.current++];
    }

    return nextPoint;
}

- (id)nextCorrelatedObject
{
    id nextCorrelatedPoint = nil;
    
    if (self.correlatedCurrent < [self.correlateDataPoints count]) {
        nextCorrelatedPoint = [self.correlateDataPoints objectAtIndex:self.correlatedCurrent++];
    }
    
    return nextCorrelatedPoint;
}

- (NSArray *)allObjects
{
    return self.dataPoints;
}

- (NSNumber *)numberOfDataPoints
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K <> %@", kDatasetValueKey, @(NSNotFound)];
    NSArray *filteredArray = [self.dataPoints filteredArrayUsingPredicate:predicate];
    
    NSNumber *numberOfPoints = @(filteredArray.count);
    
    return numberOfPoints;
}

#pragma mark - Graph Datasource
#pragma mark Line

- (NSInteger)lineGraph:(APCLineGraphView *) __unused graphView numberOfPointsInPlot:(NSInteger)plotIndex
{
    NSInteger numberOfPoints = 0;
    
    if (plotIndex == 0) {
        numberOfPoints = [self.timeline count]; //[self.dataPoints count];
    } else {
        numberOfPoints = [self.correlateDataPoints count];
    }
    return numberOfPoints;
}

- (NSInteger)numberOfPlotsInLineGraph:(APCLineGraphView *) __unused graphView
{
    NSUInteger numberOfPlots = 1;
    
    if (self.hasCorrelateDataPoints) {
        numberOfPlots = 2;
    }
    return numberOfPlots;
}

- (CGFloat)minimumValueForLineGraph:(APCLineGraphView *) __unused graphView
{
    CGFloat factor = 0.2;
    CGFloat maxDataPoint = (self.customMaximumPoint == CGFLOAT_MAX) ? [[self maximumDataPoint] doubleValue] : self.customMaximumPoint;
    CGFloat minDataPoint = (self.customMinimumPoint == CGFLOAT_MIN) ? [[self minimumDataPoint] doubleValue] : self.customMinimumPoint;
    
    CGFloat minValue = (minDataPoint - factor*maxDataPoint)/(1-factor);
    
    return minValue;
}

- (CGFloat)maximumValueForLineGraph:(APCLineGraphView *) __unused graphView
{
    return (self.customMaximumPoint == CGFLOAT_MAX) ? [[self maximumDataPoint] doubleValue] : self.customMaximumPoint;
}

- (CGFloat)lineGraph:(APCLineGraphView *) __unused graphView plot:(NSInteger)plotIndex valueForPointAtIndex:(NSInteger) __unused pointIndex
{
    CGFloat value;
    
    if (plotIndex == 0) {
        NSDictionary *point = [self nextObject];
        value = [[point valueForKey:kDatasetValueKey] doubleValue];
    } else {
        NSDictionary *correlatedPoint = [self nextCorrelatedObject];
        value = [[correlatedPoint valueForKey:kDatasetValueKey] doubleValue];
    }
    
    return value;
}

- (NSString *)lineGraph:(APCLineGraphView *) __unused graphView titleForXAxisAtIndex:(NSInteger)pointIndex
{
    NSDate *titleDate = nil;
    
    titleDate = [[self.dataPoints objectAtIndex:pointIndex] valueForKey:kDatasetDateKey];

    if (pointIndex == 0) {
        [self.dateFormatter setDateFormat:@"MMM d"];
    } else {
        [self.dateFormatter setDateFormat:@"d"];
    }
    
    
    NSString *xAxisTitle = [self.dateFormatter stringFromDate:titleDate];
                            
    return xAxisTitle;
}

#pragma mark Discrete

- (NSInteger)discreteGraph:(APCDiscreteGraphView *) __unused graphView numberOfPointsInPlot:(NSInteger) __unused plotIndex
{
    return [self.timeline count];
}

- (APCRangePoint *)discreteGraph:(APCDiscreteGraphView *) __unused graphView plot:(NSInteger) __unused plotIndex valueForPointAtIndex:(NSInteger) __unused pointIndex
{
    APCRangePoint *value;
    
    NSDictionary *point = [self nextObject];
    value = [point valueForKey:kDatasetRangeValueKey];
    
    if (!value) {
        value = [APCRangePoint new];
    }
    return value;
}

- (NSString *)discreteGraph:(APCDiscreteGraphView *) __unused graphView titleForXAxisAtIndex:(NSInteger) __unused pointIndex
{
    NSDate *titleDate = nil;
    
    titleDate = [[self.dataPoints objectAtIndex:pointIndex] valueForKey:kDatasetDateKey];
    
    if (pointIndex == 0) {
        [self.dateFormatter setDateFormat:@"MMM d"];
    } else {
        [self.dateFormatter setDateFormat:@"d"];
    }
    
    
    NSString *xAxisTitle = [self.dateFormatter stringFromDate:titleDate];
    
    return xAxisTitle;
}

- (CGFloat)minimumValueForDiscreteGraph:(APCDiscreteGraphView *) __unused graphView
{
    CGFloat factor = 0.2;
    CGFloat maxDataPoint = (self.customMaximumPoint == CGFLOAT_MAX) ? [[self maximumDataPoint] doubleValue] : self.customMaximumPoint;
    CGFloat minDataPoint = (self.customMinimumPoint == CGFLOAT_MIN) ? [[self minimumDataPoint] doubleValue] : self.customMinimumPoint;
    
    CGFloat minValue = (minDataPoint - factor*maxDataPoint)/(1-factor);
    
    return minValue;
}

- (CGFloat)maximumValueForDiscreteGraph:(APCDiscreteGraphView *) __unused graphView
{
    return (self.customMaximumPoint == CGFLOAT_MAX) ? [[self maximumDataPoint] doubleValue] : self.customMaximumPoint;
}

@end
