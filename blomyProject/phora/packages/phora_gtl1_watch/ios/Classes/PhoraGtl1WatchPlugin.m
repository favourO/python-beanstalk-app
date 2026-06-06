#import "PhoraGtl1WatchPlugin.h"

#import <TargetConditionals.h>

#if TARGET_OS_SIMULATOR

@interface PhoraGtl1WatchPlugin ()
@property(nonatomic, strong) FlutterMethodChannel *methodChannel;
@property(nonatomic, strong) FlutterEventChannel *eventChannel;
@property(nonatomic, copy) FlutterEventSink eventSink;
@end

@implementation PhoraGtl1WatchPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  PhoraGtl1WatchPlugin *instance = [[PhoraGtl1WatchPlugin alloc] init];
  instance.methodChannel = [FlutterMethodChannel methodChannelWithName:@"phora/gtl1_watch"
                                                       binaryMessenger:[registrar messenger]];
  instance.eventChannel = [FlutterEventChannel eventChannelWithName:@"phora/gtl1_watch/events"
                                                    binaryMessenger:[registrar messenger]];
  [registrar addMethodCallDelegate:instance channel:instance.methodChannel];
  [instance.eventChannel setStreamHandler:instance];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([@"scanDevices" isEqualToString:call.method]) {
    result(@[]);
    return;
  }
  if ([@"disconnect" isEqualToString:call.method]) {
    result(nil);
    return;
  }
  if ([@"getPhoneNotificationsEnabled" isEqualToString:call.method]) {
    result(@YES);
    return;
  }
  if ([@"setPhoneNotificationsEnabled" isEqualToString:call.method]) {
    result(nil);
    return;
  }
  result([FlutterError errorWithCode:@"simulator_unavailable"
                              message:@"Phora Wear pairing requires a physical iOS device."
                              details:nil]);
}

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
  self.eventSink = events;
  return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
  self.eventSink = nil;
  return nil;
}

@end

#else

#import <objc/runtime.h>
#import <RunmefitSDK/RunmefitSDK.h>

#import "PhoraGtl1BleManager.h"

@interface PhoraGtl1WatchPlugin ()
@property(nonatomic, strong) FlutterMethodChannel *methodChannel;
@property(nonatomic, strong) FlutterEventChannel *eventChannel;
@property(nonatomic, copy) FlutterEventSink eventSink;
@property(nonatomic, strong) NSMutableArray<STDeviceModel *> *scanResults;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, FlutterResult> *pendingResults;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, id> *pendingPayloads;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *syncAccumulator;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *receivedSyncTypes;
@property(nonatomic, strong) NSArray<NSNumber *> *syncQueue;
@property(nonatomic, assign) NSInteger syncIndex;
@property(nonatomic, assign) NSInteger syncCommandToken;
@property(nonatomic, copy) NSString *syncDate;
@end

@implementation PhoraGtl1WatchPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  PhoraGtl1WatchPlugin *instance = [[PhoraGtl1WatchPlugin alloc] init];
  instance.methodChannel = [FlutterMethodChannel methodChannelWithName:@"phora/gtl1_watch"
                                                       binaryMessenger:[registrar messenger]];
  instance.eventChannel = [FlutterEventChannel eventChannelWithName:@"phora/gtl1_watch/events"
                                                    binaryMessenger:[registrar messenger]];
  [registrar addMethodCallDelegate:instance channel:instance.methodChannel];
  [instance.eventChannel setStreamHandler:instance];
}

- (instancetype)init {
  if (self = [super init]) {
    _scanResults = [[NSMutableArray alloc] init];
    _pendingResults = [[NSMutableDictionary alloc] init];
    _pendingPayloads = [[NSMutableDictionary alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onSdkNotification:)
                                                 name:Nof_Revice_Data_Key
                                               object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([@"scanDevices" isEqualToString:call.method]) {
    [self scanDevices:result];
    return;
  }
  if ([@"connect" isEqualToString:call.method]) {
    [self connect:call.arguments result:result];
    return;
  }
  if ([@"disconnect" isEqualToString:call.method]) {
    STDeviceModel *device = [PhoraGtl1BleManager sharedInstance].actDeviceModel;
    if (device) {
      [[PhoraGtl1BleManager sharedInstance] cancelPeripheral:device];
    }
    result(nil);
    return;
  }
  if ([@"syncDeviceTime" isEqualToString:call.method]) {
    PhoraGtl1BleManager *manager = [PhoraGtl1BleManager sharedInstance];
    if (!manager.actDeviceModel ||
        manager.actDeviceModel.peripheral.state != CBPeripheralStateConnected ||
        !manager.writeCharacter) {
      result([FlutterError errorWithCode:@"not_connected"
                                  message:@"Phora Wear is not ready for time sync."
                                  details:nil]);
      return;
    }
    [manager writeCommand:[STBlueToothSender writeDeviceDateTime]];
    NSLog(@"[PhoraWear] Sent app time to GTL1 watch.");
    result(nil);
    return;
  }
  if ([@"getBattery" isEqualToString:call.method]) {
    PhoraGtl1BleManager *manager = [PhoraGtl1BleManager sharedInstance];
    if (!manager.actDeviceModel ||
        manager.actDeviceModel.peripheral.state != CBPeripheralStateConnected ||
        !manager.writeCharacter) {
      result([FlutterError errorWithCode:@"not_connected"
                                  message:@"Phora Wear is not ready for battery read."
                                  details:nil]);
      return;
    }
    NSNumber *key = @(REV_Device_Battery);
    self.pendingResults[key] = [result copy];
    [manager writeCommand:[STBlueToothSender readDeviceBattery]];
    return;
  }
  if ([@"getCurrentHealth" isEqualToString:call.method]) {
    PhoraGtl1BleManager *manager = [PhoraGtl1BleManager sharedInstance];
    if (!manager.actDeviceModel ||
        manager.actDeviceModel.peripheral.state != CBPeripheralStateConnected ||
        !manager.writeCharacter) {
      result([FlutterError errorWithCode:@"not_connected"
                                  message:@"Phora Wear is not ready for current health read."
                                  details:nil]);
      return;
    }
    NSNumber *key = @(REV_Health_Current);
    self.pendingResults[key] = [result copy];
    [manager writeCommand:[STBlueToothSender readCurrentHealth]];
    return;
  }
  if ([@"syncToday" isEqualToString:call.method]) {
    NSString *today = [self yyyyMMddStringFromDate:[NSDate date]];
    [self beginSyncForDate:today result:result];
    return;
  }
  if ([@"syncDate" isEqualToString:call.method]) {
    NSString *date = call.arguments[@"date"];
    [self beginSyncForDate:[self compactDate:date] result:result];
    return;
  }
  if ([@"syncRange" isEqualToString:call.method]) {
    [self syncRange:call.arguments result:result];
    return;
  }
  if ([@"getFemaleHealth" isEqualToString:call.method]) {
    NSNumber *key = @(REV_Women_Health);
    self.pendingResults[key] = [result copy];
    [[PhoraGtl1BleManager sharedInstance] writeCommand:[STBlueToothSender readDeviceWomenHealth]];
    return;
  }
  if ([@"setFemaleHealth" isEqualToString:call.method]) {
    NSString *lastPeriodDate = [self compactDate:call.arguments[@"lastPeriodDate"]];
    NSNumber *key = @(SET_Women_Health);
    self.pendingResults[key] = [result copy];
    [[PhoraGtl1BleManager sharedInstance]
        writeCommand:[STBlueToothSender writeDeviceWomenHealth:[call.arguments[@"periodDays"] intValue]
                                                         Cycle:[call.arguments[@"cycleDays"] intValue]
                                                      LastDate:lastPeriodDate]];
    return;
  }
  if ([@"getPhoneNotificationsEnabled" isEqualToString:call.method]) {
    NSNumber *key = @(REV_State_Notification);
    self.pendingResults[key] = [result copy];
    [[PhoraGtl1BleManager sharedInstance] writeCommand:[STBlueToothSender readMessageNotice]];
    return;
  }
  if ([@"setPhoneNotificationsEnabled" isEqualToString:call.method]) {
    BOOL enabled = [call.arguments[@"enabled"] boolValue];
    STMessageNotice *notice = [[STMessageNotice alloc] init];
    notice.isAll = enabled;
    notice.isIncoming = enabled;
    notice.isSms = enabled;
    notice.isEmail = enabled;
    notice.isTwitter = enabled;
    notice.isFacebook = enabled;
    notice.isWhatsapp = enabled;
    notice.isLine = enabled;
    notice.isSkype = enabled;
    notice.isQq = enabled;
    notice.isWechat = enabled;
    notice.isInstagram = enabled;
    notice.isLinkedin = enabled;
    notice.isMessager = enabled;
    notice.isVk = enabled;
    notice.isViber = enabled;
    notice.isTelegram = enabled;
    notice.isKakaoTalk = enabled;
    notice.isOther = enabled;
    NSNumber *key = @(SET_State_Notification);
    self.pendingResults[key] = [result copy];
    [[PhoraGtl1BleManager sharedInstance] writeCommand:[STBlueToothSender writeMessageNotice:notice]];
    return;
  }
  result(FlutterMethodNotImplemented);
}

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
  self.eventSink = events;
  return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
  self.eventSink = nil;
  return nil;
}

- (void)scanDevices:(FlutterResult)result {
  __weak typeof(self) weakSelf = self;
  [self.scanResults removeAllObjects];
  [PhoraGtl1BleManager sharedInstance].updatePerpheral = ^(NSArray<STDeviceModel *> *deviceModels) {
    weakSelf.scanResults = [deviceModels mutableCopy];
  };
  [[PhoraGtl1BleManager sharedInstance] startScan];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [[PhoraGtl1BleManager sharedInstance] stopScan];
    NSMutableArray *mapped = [[NSMutableArray alloc] init];
    for (STDeviceModel *device in weakSelf.scanResults) {
      [mapped addObject:@{
        @"id" : device.mac ?: @"",
        @"name" : device.name ?: @"GTL1 Watch",
        @"rssi" : device.rssi ?: @0,
        @"metadata" : @{
          @"connected" : @([device isEqual:[PhoraGtl1BleManager sharedInstance].actDeviceModel]),
          @"manufacturerMac" : device.mac ?: @"",
          @"manufacturerPrefix" : @"0001",
          @"isStarmax" : @YES
        }
      }];
    }
    result(mapped);
  });
}

- (void)connect:(NSDictionary *)arguments result:(FlutterResult)result {
  NSString *deviceId = arguments[@"deviceId"];
  STDeviceModel *target = nil;
  for (STDeviceModel *device in self.scanResults) {
    if ([device.mac isEqualToString:deviceId]) {
      target = device;
      break;
    }
  }
  if (!target) {
    result([FlutterError errorWithCode:@"not_found" message:@"Device not found in latest scan" details:nil]);
    return;
  }
  __weak typeof(self) weakSelf = self;
  __block BOOL completed = NO;
  [PhoraGtl1BleManager sharedInstance].updateConnect = ^(BOOL connect) {
    if (connect) {
      if (completed) {
        return;
      }
      completed = YES;
      result(@{ @"status" : @"connected" });
      [weakSelf emitEvent:@{
        @"type" : @"connection",
        @"state" : @"connected",
        @"deviceId" : target.mac ?: @"",
        @"name" : target.name ?: @"GTL1 Watch"
      }];
    } else {
      if (!completed) {
        completed = YES;
        result([FlutterError errorWithCode:@"connect_failed"
                                    message:@"Phora Wear connection failed before notifications were ready."
                                    details:nil]);
      }
      [weakSelf emitEvent:@{ @"type" : @"connection", @"state" : @"disconnected" }];
    }
  };
  [[PhoraGtl1BleManager sharedInstance] connectPerpheral:target];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (completed) {
      return;
    }
    completed = YES;
    [[PhoraGtl1BleManager sharedInstance] cancelPeripheral:target];
    result([FlutterError errorWithCode:@"connect_timeout"
                                message:@"Timed out connecting to Phora Wear. Keep the watch nearby and try again."
                                details:nil]);
  });
}

- (void)syncRange:(NSDictionary *)arguments result:(FlutterResult)result {
  NSString *start = [self compactDate:arguments[@"start"]];
  NSString *end = [self compactDate:arguments[@"end"]];
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  formatter.dateFormat = @"yyyyMMdd";
  NSDate *cursor = [formatter dateFromString:start];
  NSDate *finalDate = [formatter dateFromString:end];
  if (!cursor || !finalDate) {
    result([FlutterError errorWithCode:@"invalid_args" message:@"start/end must be YYYY-MM-DD" details:nil]);
    return;
  }
  NSMutableArray *items = [[NSMutableArray alloc] init];
  __weak typeof(self) weakSelf = self;
  void (^syncNext)(NSDate *) = ^(NSDate *date) {
    if ([date compare:finalDate] == NSOrderedDescending) {
      result(items);
      return;
    }
    NSString *dateString = [formatter stringFromDate:date];
    [weakSelf beginSyncForDate:dateString result:^(id _Nullable payload) {
      if ([payload isKindOfClass:[FlutterError class]]) {
        result(payload);
        return;
      }
      [items addObject:payload];
      NSDate *next = [date dateByAddingTimeInterval:24 * 60 * 60];
      syncNext(next);
    }];
  };
  syncNext(cursor);
}

- (void)beginSyncForDate:(NSString *)compactDate result:(FlutterResult)result {
  if (!compactDate.length) {
    result([FlutterError errorWithCode:@"invalid_args" message:@"date is required" details:nil]);
    return;
  }
  self.syncDate = compactDate;
  self.syncAccumulator = [@{
    @"date" : [self dashedDate:compactDate],
    @"steps" : @0,
    @"caloriesKcal" : @0,
    @"distanceMeters" : @0,
    @"heartRate" : [@{ @"resting" : @0, @"avg" : @0, @"min" : @0, @"max" : @0 } mutableCopy],
    @"sleep" : [@{ @"totalMinutes" : @0, @"deepMinutes" : @0, @"lightMinutes" : @0, @"awakeMinutes" : @0 } mutableCopy],
    @"bloodOxygen" : [@{ @"avg" : @0, @"min" : @0 } mutableCopy],
    @"temperature" : [@{ @"avg" : @0 } mutableCopy],
    @"stress" : [@{ @"avg" : @0 } mutableCopy],
    @"raw" : [NSMutableDictionary dictionary]
  } mutableCopy];
  self.syncQueue = @[ @(REV_History_Step), @(REV_History_NewSleep), @(REV_History_HR), @(REV_History_BQ), @(REV_History_Pressure), @(REV_History_Temp) ];
  self.receivedSyncTypes = [[NSMutableSet alloc] init];
  self.syncIndex = 0;
  self.syncCommandToken += 1;
  self.pendingResults[@(999001)] = [result copy];
  [self sendNextSyncCommand];
}

- (void)sendNextSyncCommand {
  if (self.syncIndex >= self.syncQueue.count) {
    FlutterResult result = self.pendingResults[@(999001)];
    [self.pendingResults removeObjectForKey:@(999001)];
    NSMutableDictionary *payload = [self.syncAccumulator mutableCopy];
    payload[@"sourceDevice"] = [PhoraGtl1BleManager sharedInstance].actDeviceModel.name ?: @"gtl1_watch";
    payload[@"syncTimestamp"] = [[NSDate date] description];
    result(payload);
    self.syncAccumulator = nil;
    self.receivedSyncTypes = nil;
    self.syncQueue = nil;
    self.syncDate = nil;
    self.syncCommandToken += 1;
    return;
  }
  NSNumber *code = self.syncQueue[self.syncIndex];
  NSInteger commandIndex = self.syncIndex;
  NSInteger commandToken = self.syncCommandToken;
  NSData *command = nil;
  switch (code.integerValue) {
    case REV_History_Step:
      command = [STBlueToothSender readStepAndSleepHistoryWithDate:self.syncDate];
      break;
    case REV_History_NewSleep:
      command = [STBlueToothSender readNewSleepHistoryWithDate:self.syncDate];
      break;
    case REV_History_HR:
      command = [STBlueToothSender readHeartRateHistoryWithDate:self.syncDate];
      break;
    case REV_History_BQ:
      command = [STBlueToothSender readBloodOxygenHistoryWithDate:self.syncDate];
      break;
    case REV_History_Pressure:
      command = [STBlueToothSender readPhysicalPressureHistoryWithDate:self.syncDate];
      break;
    case REV_History_Temp:
      command = [STBlueToothSender readTemperatureHistoryWithDate:self.syncDate];
      break;
    default:
      break;
  }
  if (command) {
    [[PhoraGtl1BleManager sharedInstance] writeCommand:command];
    [self scheduleSyncCommandTimeoutForCode:code index:commandIndex token:commandToken];
  } else {
    self.syncIndex += 1;
    [self sendNextSyncCommand];
  }
}

- (void)scheduleSyncCommandTimeoutForCode:(NSNumber *)code index:(NSInteger)index token:(NSInteger)token {
  NSTimeInterval timeoutSeconds =
      (code.integerValue == REV_History_Step || code.integerValue == REV_History_NewSleep) ? 12.0 : 8.0;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (!self.syncAccumulator || self.syncIndex != index || self.syncCommandToken != token) {
      return;
    }
    NSNumber *expected = self.syncQueue[index];
    if (![expected isEqualToNumber:code]) {
      return;
    }
    NSMutableDictionary *raw = self.syncAccumulator[@"raw"];
    NSMutableArray *timeouts = raw[@"syncTimeouts"];
    if (![timeouts isKindOfClass:[NSMutableArray class]]) {
      timeouts = [[NSMutableArray alloc] init];
      raw[@"syncTimeouts"] = timeouts;
    }
    [timeouts addObject:@{ @"revType" : code, @"date" : self.syncDate ?: @"" }];
    NSLog(@"[PhoraWear][sync-now] GTL1 history command timed out. revType=%@ date=%@", code, self.syncDate);
    self.syncIndex += 1;
    [self sendNextSyncCommand];
  });
}

- (void)onSdkNotification:(NSNotification *)note {
  NSNumber *revType = note.userInfo[ST_RevType_Key];
  id responseObject = note.object;

  if (revType.integerValue == REV_RealTime_DATA) {
    NSDictionary *serialized = [self serializedDictionaryFromObject:responseObject];
    if (serialized.count) {
      [self emitEvent:@{ @"type" : @"realtime", @"raw" : serialized }];
    }
  }

  FlutterResult pending = self.pendingResults[revType];
  if (pending) {
    if (revType.integerValue == REV_Health_Current) {
      NSDictionary *dictionary = [self serializedDictionaryFromObject:responseObject];
      NSString *today = [self dashedDate:[self yyyyMMddStringFromDate:[NSDate date]]];
      pending(@{
        @"date" : today,
        @"steps" : dictionary[(NSString *)ST_GetCurrentValueStepKey] ?: @0,
        @"caloriesKcal" : @([self normalizeCalories:[dictionary[(NSString *)ST_GetCurrentValueCalorieKey] doubleValue]]),
        @"distanceMeters" : dictionary[(NSString *)ST_GetCurrentValueDistanceKey] ?: @0,
        @"heartRate" : @{
          @"resting" : dictionary[(NSString *)ST_GetCurrentValueHRKey] ?: @0,
          @"avg" : dictionary[(NSString *)ST_GetCurrentValueHRKey] ?: @0,
          @"min" : dictionary[(NSString *)ST_GetCurrentValueHRKey] ?: @0,
          @"max" : dictionary[(NSString *)ST_GetCurrentValueHRKey] ?: @0
        },
        @"sleep" : @{
          @"totalMinutes" : dictionary[(NSString *)ST_GetCurrentValueSleepKey] ?: @0,
          @"deepMinutes" : dictionary[(NSString *)ST_GetCurrentValueDeepSleepKey] ?: @0,
          @"lightMinutes" : dictionary[(NSString *)ST_GetCurrentValueLightSleepKey] ?: @0,
          @"awakeMinutes" : @0
        },
        @"bloodOxygen" : @{
          @"avg" : dictionary[(NSString *)ST_GetCurrentValueBOKey] ?: @0,
          @"min" : dictionary[(NSString *)ST_GetCurrentValueBOKey] ?: @0
        },
        @"temperature" : @{
          @"avg" : @([self normalizeTemperature:[dictionary[(NSString *)ST_GetCurrentValueTemperatureKey] doubleValue]])
        },
        @"stress" : @{
          @"avg" : dictionary[(NSString *)ST_GetCurrentValueHPKey] ?: @0
        },
        @"sourceDevice" : [PhoraGtl1BleManager sharedInstance].actDeviceModel.name ?: @"gtl1_watch",
        @"syncTimestamp" : [[NSDate date] description],
        @"raw" : @{ @"currentHealth" : dictionary }
      });
      [self.pendingResults removeObjectForKey:revType];
      return;
    }
    if (revType.integerValue == REV_Device_Battery) {
      NSDictionary *dictionary = [self serializedDictionaryFromObject:responseObject];
      pending(@{
        @"level" : dictionary[(NSString *)ST_GetElectricityKey] ?: dictionary[@"electricity"] ?: @0,
        @"isCharging" : dictionary[(NSString *)ST_GetElectricityStateKey] ?: dictionary[@"electricityState"] ?: @NO
      });
      [self.pendingResults removeObjectForKey:revType];
      return;
    }
    if (revType.integerValue == REV_Women_Health) {
      NSDictionary *dictionary = [self serializedDictionaryFromObject:responseObject];
      pending(@{
        @"periodDays" : dictionary[@"numberOfDays"] ?: dictionary[@"days"] ?: @0,
        @"cycleDays" : dictionary[@"cycleDays"] ?: dictionary[@"cycle"] ?: @0,
        @"lastPeriodDate" : [self buildDateFromDictionary:dictionary] ?: @"1970-01-01"
      });
      [self.pendingResults removeObjectForKey:revType];
      return;
    }
    if (revType.integerValue == REV_State_Notification) {
      NSDictionary *dictionary = [self serializedDictionaryFromObject:responseObject];
      pending(@([self phoneNotificationsEnabledFromDictionary:dictionary]));
      [self.pendingResults removeObjectForKey:revType];
      return;
    }
    if (revType.integerValue == SET_State_Notification) {
      pending(nil);
      [self.pendingResults removeObjectForKey:revType];
      return;
    }
    if (revType.integerValue == SET_Women_Health) {
      pending(nil);
      [self.pendingResults removeObjectForKey:revType];
      return;
    }
  }

  if (self.syncAccumulator && self.syncIndex < self.syncQueue.count) {
    NSNumber *expected = self.syncQueue[self.syncIndex];
    BOOL isKnownSyncType = [self.syncQueue containsObject:revType];
    BOOL alreadyReceived = [self.receivedSyncTypes containsObject:revType];
    if (isKnownSyncType && !alreadyReceived) {
      [self consumeSyncPayload:responseObject revType:revType.integerValue];
      [self.receivedSyncTypes addObject:revType];
      if ([expected isEqualToNumber:revType]) {
        self.syncIndex += 1;
        self.syncCommandToken += 1;
        [self sendNextSyncCommand];
      }
    }
  }
}

- (void)consumeSyncPayload:(id)payload revType:(NSInteger)revType {
  NSDictionary *dictionary = [self serializedDictionaryFromObject:payload];
  NSMutableDictionary *raw = self.syncAccumulator[@"raw"];
  NSString *rawKey = [NSString stringWithFormat:@"rev_%ld", (long)revType];
  NSDictionary *summary = [self recordSummaryFromDictionary:dictionary];
  raw[rawKey] = summary;
  NSLog(@"[PhoraWear][sync-now] GTL1 history response revType=%ld summary=%@", (long)revType, summary);
  switch (revType) {
    case REV_History_Step: {
      NSArray *items = [self recordItemsFromDictionary:dictionary];
      NSInteger steps = 0;
      double calories = 0;
      double distanceMeters = 0;
      NSInteger interval = [dictionary[(NSString *)ST_GetRecordIntervalKey] integerValue];
      if (interval <= 0) interval = 10;
      NSInteger deep = 0;
      NSInteger light = 0;
      NSInteger awake = 0;
      NSMutableArray *samples = [[NSMutableArray alloc] init];
      NSMutableArray *sleepSamples = [[NSMutableArray alloc] init];
      for (NSDictionary *item in items) {
        NSInteger value = [item[(NSString *)ST_GetRecordValueStepKey] integerValue];
        double itemCalories = [self normalizeCalories:[item[(NSString *)ST_GetRecordValueCalorieKey] doubleValue]];
        double itemDistance = [item[(NSString *)ST_GetRecordValueDistanceKey] doubleValue];
        NSInteger sleepStatus = [item[(NSString *)ST_GetRecordValueSleepKey] integerValue];
        steps += value;
        calories += itemCalories;
        distanceMeters += itemDistance;
        [samples addObject:@{
          @"hour" : item[(NSString *)ST_HourKey] ?: @0,
          @"minute" : item[(NSString *)ST_MinuteKey] ?: @0,
          @"steps" : @(value),
          @"calorie" : @(itemCalories),
          @"distance" : @(itemDistance)
        }];
        if (sleepStatus <= 0) {
          continue;
        }
        if (sleepStatus == 1 || sleepStatus == 2 || sleepStatus == 130) light += interval;
        if (sleepStatus == 3 || sleepStatus == 5 || sleepStatus == 131 || sleepStatus == 133) deep += interval;
        if (sleepStatus == 4 || sleepStatus == 132) awake += interval;
        [sleepSamples addObject:@{
          @"hour" : item[(NSString *)ST_HourKey] ?: @0,
          @"minute" : item[(NSString *)ST_MinuteKey] ?: @0,
          @"status" : @(sleepStatus),
          @"source" : @"step_sleep_history"
        }];
      }
      self.syncAccumulator[@"steps"] = @(steps);
      self.syncAccumulator[@"caloriesKcal"] = @(calories);
      self.syncAccumulator[@"distanceMeters"] = @(distanceMeters);
      if ((deep + light + awake) > 0) {
        self.syncAccumulator[@"sleep"] = [@{
          @"totalMinutes" : @(deep + light + awake),
          @"deepMinutes" : @(deep),
          @"lightMinutes" : @(light),
          @"awakeMinutes" : @(awake)
        } mutableCopy];
        raw[@"stepSleepSamples"] = sleepSamples;
      }
      raw[@"stepSamples"] = samples;
      break;
    }
    case REV_History_NewSleep: {
      NSInteger interval = [dictionary[(NSString *)ST_GetRecordIntervalKey] integerValue];
      if (interval <= 0) interval = 10;
      NSArray<NSNumber *> *values = [self numericRecordValuesFromDictionary:dictionary];
      NSInteger deep = 0;
      NSInteger light = 0;
      NSInteger awake = 0;
      NSMutableArray *samples = [[NSMutableArray alloc] init];
      for (NSUInteger index = 0; index < values.count; index += 1) {
        NSInteger status = values[index].integerValue;
        if (status == 2 || status == 130) light += interval;
        if (status == 3 || status == 5 || status == 131 || status == 133) deep += interval;
        if (status == 4 || status == 132) awake += interval;
        if (status == 0) {
          continue;
        }
        [samples addObject:@{
          @"index" : @(index),
          @"minuteOfDay" : @(index * interval),
          @"status" : @(status)
        }];
      }
      if ((deep + light + awake) > 0 || [self.syncAccumulator[@"sleep"][@"totalMinutes"] integerValue] <= 0) {
        self.syncAccumulator[@"sleep"] = [@{
          @"totalMinutes" : @(deep + light + awake),
          @"deepMinutes" : @(deep),
          @"lightMinutes" : @(light),
          @"awakeMinutes" : @(awake)
        } mutableCopy];
      }
      raw[@"sleepSamples"] = samples;
      break;
    }
    case REV_History_HR: {
      [self assignIntegerSeries:[self numericRecordValuesFromDictionary:dictionary]
                     target:self.syncAccumulator[@"heartRate"]
                   rawKey:@"heartRateSamples"];
      break;
    }
    case REV_History_BQ: {
      [self assignMinAvgSeries:[self numericRecordValuesFromDictionary:dictionary]
                        target:self.syncAccumulator[@"bloodOxygen"]
                        rawKey:@"bloodOxygenSamples"];
      break;
    }
    case REV_History_Pressure: {
      NSArray<NSNumber *> *recordValues = [self numericRecordValuesFromDictionary:dictionary];
      NSMutableArray *values = [[NSMutableArray alloc] init];
      NSMutableArray *samples = [[NSMutableArray alloc] init];
      for (NSUInteger index = 0; index < recordValues.count; index += 1) {
        NSNumber *value = recordValues[index];
        if (value.integerValue <= 0) {
          continue;
        }
        [values addObject:value];
        [samples addObject:@{ @"index" : @(index), @"value" : value }];
      }
      self.syncAccumulator[@"stress"] = [@{ @"avg" : @([self averageOfNumbers:values]) } mutableCopy];
      raw[@"stressSamples"] = samples;
      break;
    }
    case REV_History_Temp: {
      NSArray<NSNumber *> *recordValues = [self numericRecordValuesFromDictionary:dictionary];
      NSMutableArray *values = [[NSMutableArray alloc] init];
      NSMutableArray *samples = [[NSMutableArray alloc] init];
      for (NSUInteger index = 0; index < recordValues.count; index += 1) {
        double value = [self normalizeTemperature:recordValues[index].doubleValue];
        if (![self isPlausibleBodyTemperature:value]) {
          continue;
        }
        [values addObject:@(value)];
        [samples addObject:@{ @"index" : @(index), @"value" : @(value) }];
      }
      self.syncAccumulator[@"temperature"] = [@{ @"avg" : @([self averageOfNumbers:values]) } mutableCopy];
      raw[@"temperatureSamples"] = samples;
      break;
    }
    default:
      break;
  }
}

- (NSArray *)recordItemsFromDictionary:(NSDictionary *)dictionary {
  id items = [self recordValueFromDictionary:dictionary];
  if ([items isKindOfClass:[NSArray class]]) {
    return items;
  }
  return @[];
}

- (id)recordValueFromDictionary:(NSDictionary *)dictionary {
  id value = dictionary[(NSString *)ST_GetRecordValueDataKey];
  if (!value) value = dictionary[@"recordValueData"];
  if (!value) value = dictionary[@"data"];
  return value;
}

- (NSDictionary *)recordSummaryFromDictionary:(NSDictionary *)dictionary {
  NSArray<NSNumber *> *values = [self numericRecordValuesFromDictionary:dictionary];
  NSInteger nonZeroCount = 0;
  NSMutableArray *firstNonZero = [[NSMutableArray alloc] init];
  for (NSUInteger index = 0; index < values.count; index += 1) {
    NSNumber *value = values[index];
    if (value.doubleValue == 0) {
      continue;
    }
    nonZeroCount += 1;
    if (firstNonZero.count < 12) {
      [firstNonZero addObject:@{ @"index" : @(index), @"value" : value }];
    }
  }
  id rawValue = [self recordValueFromDictionary:dictionary];
  NSString *valueType = rawValue ? NSStringFromClass([rawValue class]) : @"nil";
  return @{
    @"date" : dictionary[(NSString *)ST_GetRecordDateTimeKey] ?: dictionary[@"recordDateTime"] ?: @"",
    @"interval" : dictionary[(NSString *)ST_GetRecordIntervalKey] ?: dictionary[@"recordInterval"] ?: @0,
    @"valueType" : valueType,
    @"valueCount" : @(values.count),
    @"nonZeroCount" : @(nonZeroCount),
    @"firstNonZero" : firstNonZero
  };
}

- (NSArray<NSNumber *> *)numericRecordValuesFromDictionary:(NSDictionary *)dictionary {
  id value = [self recordValueFromDictionary:dictionary];
  NSMutableArray<NSNumber *> *numbers = [[NSMutableArray alloc] init];
  if ([value isKindOfClass:[NSArray class]]) {
    for (id item in (NSArray *)value) {
      if ([item isKindOfClass:[NSDictionary class]]) {
        id itemValue = item[@"value"] ?: item[(NSString *)ST_GetRecordValueSleepKey];
        if ([itemValue respondsToSelector:@selector(doubleValue)]) {
          [numbers addObject:@([itemValue doubleValue])];
        }
      } else if ([item respondsToSelector:@selector(doubleValue)]) {
        [numbers addObject:@([item doubleValue])];
      }
    }
    return numbers;
  }
  if ([value isKindOfClass:[NSNumber class]]) {
    return @[ value ];
  }
  if (![value isKindOfClass:[NSString class]]) {
    return @[];
  }
  NSArray<NSString *> *parts = [(NSString *)value componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  for (NSString *part in parts) {
    if (!part.length) {
      continue;
    }
    NSScanner *scanner = [NSScanner scannerWithString:part];
    double parsed = 0;
    if ([scanner scanDouble:&parsed]) {
      [numbers addObject:@(parsed)];
    }
  }
  return numbers;
}

- (void)assignIntegerSeries:(NSArray<NSNumber *> *)values
                     target:(NSMutableDictionary *)target
                     rawKey:(NSString *)rawKey {
  NSMutableArray *filtered = [[NSMutableArray alloc] init];
  NSMutableArray *samples = [[NSMutableArray alloc] init];
  for (NSUInteger index = 0; index < values.count; index += 1) {
    NSNumber *value = values[index];
    if (value.integerValue <= 0) {
      continue;
    }
    [filtered addObject:value];
    [samples addObject:@{ @"index" : @(index), @"value" : value }];
  }
  NSInteger min = filtered.count ? [[filtered valueForKeyPath:@"@min.self"] integerValue] : 0;
  NSInteger max = filtered.count ? [[filtered valueForKeyPath:@"@max.self"] integerValue] : 0;
  NSInteger avg = [self averageOfNumbers:filtered];
  target[@"resting"] = @(min);
  target[@"avg"] = @(avg);
  target[@"min"] = @(min);
  target[@"max"] = @(max);
  self.syncAccumulator[@"raw"][rawKey] = samples;
}

- (void)assignMinAvgSeries:(NSArray<NSNumber *> *)values
                    target:(NSMutableDictionary *)target
                    rawKey:(NSString *)rawKey {
  NSMutableArray *filtered = [[NSMutableArray alloc] init];
  NSMutableArray *samples = [[NSMutableArray alloc] init];
  for (NSUInteger index = 0; index < values.count; index += 1) {
    NSNumber *value = values[index];
    if (value.integerValue <= 0) {
      continue;
    }
    [filtered addObject:value];
    [samples addObject:@{ @"index" : @(index), @"value" : value }];
  }
  NSInteger min = filtered.count ? [[filtered valueForKeyPath:@"@min.self"] integerValue] : 0;
  NSInteger avg = [self averageOfNumbers:filtered];
  target[@"avg"] = @(avg);
  target[@"min"] = @(min);
  self.syncAccumulator[@"raw"][rawKey] = samples;
}

- (NSDictionary *)timeSample:(NSDictionary *)item value:(NSNumber *)value {
  return @{
    @"hour" : item[(NSString *)ST_HourKey] ?: @0,
    @"minute" : item[(NSString *)ST_MinuteKey] ?: @0,
    @"value" : value ?: @0
  };
}

- (NSInteger)averageOfNumbers:(NSArray<NSNumber *> *)numbers {
  if (!numbers.count) return 0;
  double total = 0;
  for (NSNumber *number in numbers) {
    total += number.doubleValue;
  }
  return (NSInteger)round(total / numbers.count);
}

- (double)normalizeTemperature:(double)value {
  return value >= 100 ? value / 10.0 : value;
}

- (double)normalizeCalories:(double)value {
  return value > 1000 ? value / 100.0 : value;
}

- (BOOL)isPlausibleBodyTemperature:(double)value {
  return value >= 30.0 && value <= 45.0;
}

- (NSDictionary *)serializedDictionaryFromObject:(id)object {
  if (!object) return @{};
  if ([object isKindOfClass:[NSDictionary class]]) {
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    for (id key in [(NSDictionary *)object allKeys]) {
      result[[key description]] = [self serializeAny:[(NSDictionary *)object objectForKey:key]];
    }
    return result;
  }
  if ([object isKindOfClass:[NSArray class]]) {
    return @{ (NSString *)ST_GetRecordValueDataKey : [self serializeAny:object] };
  }
  return [self dictionaryFromSelectors:object];
}

- (id)serializeAny:(id)value {
  if (!value || value == [NSNull null]) return [NSNull null];
  if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) return value;
  if ([value isKindOfClass:[NSArray class]]) {
    NSMutableArray *items = [[NSMutableArray alloc] init];
    for (id item in (NSArray *)value) {
      [items addObject:[self serializeAny:item]];
    }
    return items;
  }
  if ([value isKindOfClass:[NSDictionary class]]) {
    return [self serializedDictionaryFromObject:value];
  }
  return [self dictionaryFromSelectors:value];
}

- (NSDictionary *)dictionaryFromSelectors:(id)object {
  NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
  NSArray<NSString *> *selectors = @[
    @"year", @"month", @"day", @"hour", @"minute", @"status",
    @"numberOfDays", @"cycleDays", @"value", @"steps", @"calorie", @"distance",
    @"data", @"recordValueData", @"recordDateTime", @"recordInterval"
  ];
  for (NSString *selectorName in selectors) {
    SEL selector = NSSelectorFromString(selectorName);
    if ([object respondsToSelector:selector]) {
      id value = [object valueForKey:selectorName];
      if (value) {
        result[selectorName] = [self serializeAny:value];
      }
    }
  }
  unsigned int count = 0;
  objc_property_t *properties = class_copyPropertyList([object class], &count);
  for (unsigned int i = 0; i < count; i++) {
    const char *name = property_getName(properties[i]);
    if (!name) continue;
    NSString *key = [NSString stringWithUTF8String:name];
    id value = nil;
    @try {
      value = [object valueForKey:key];
    } @catch (NSException *exception) {
      value = nil;
    }
    if (value) {
      result[key] = [self serializeAny:value];
    }
  }
  free(properties);
  return result;
}

- (NSString *)buildDateFromDictionary:(NSDictionary *)dictionary {
  NSNumber *year = dictionary[@"year"];
  NSNumber *month = dictionary[@"month"];
  NSNumber *day = dictionary[@"day"];
  if (!year || !month || !day) return nil;
  return [NSString stringWithFormat:@"%04ld-%02ld-%02ld", (long)year.integerValue, (long)month.integerValue, (long)day.integerValue];
}

- (BOOL)phoneNotificationsEnabledFromDictionary:(NSDictionary *)dictionary {
  NSArray<NSString *> *keys = @[
    @"isAll", @"isIncoming", @"isSms", @"isEmail", @"isTwitter", @"isFacebook",
    @"isWhatsapp", @"isLine", @"isSkype", @"isQq", @"isWechat", @"isInstagram",
    @"isLinkedin", @"isMessager", @"isVk", @"isViber", @"isTelegram",
    @"isKakaoTalk", @"isOther"
  ];
  for (NSString *key in keys) {
    if ([dictionary[key] respondsToSelector:@selector(boolValue)] && [dictionary[key] boolValue]) {
      return YES;
    }
  }
  return NO;
}

- (NSString *)compactDate:(NSString *)rawDate {
  return [[rawDate ?: @"" stringByReplacingOccurrencesOfString:@"-" withString:@""] copy];
}

- (NSString *)dashedDate:(NSString *)compactDate {
  if (compactDate.length != 8) return compactDate ?: @"";
  return [NSString stringWithFormat:@"%@-%@-%@",
                                    [compactDate substringToIndex:4],
                                    [compactDate substringWithRange:NSMakeRange(4, 2)],
                                    [compactDate substringFromIndex:6]];
}

- (NSString *)yyyyMMddStringFromDate:(NSDate *)date {
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  formatter.dateFormat = @"yyyyMMdd";
  return [formatter stringFromDate:date];
}

- (void)emitEvent:(NSDictionary *)event {
  if (self.eventSink) {
    self.eventSink(event);
  }
}

@end

#endif
