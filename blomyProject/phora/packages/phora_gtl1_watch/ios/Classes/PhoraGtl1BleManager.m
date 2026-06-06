#import "PhoraGtl1BleManager.h"

#if !TARGET_OS_SIMULATOR

static PhoraGtl1BleManager *manager = nil;

@implementation PhoraGtl1BleManager

+ (instancetype)sharedInstance {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    manager = [[PhoraGtl1BleManager alloc] init];
  });
  return manager;
}

- (instancetype)init {
  if (self = [super init]) {
    NSDictionary *options = @{CBCentralManagerOptionShowPowerAlertKey : @(YES)};
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:options];
    _deviceModels = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
  self.stateOn = (central.state == CBManagerStatePoweredOn);
  if (self.updateState) {
    self.updateState(self.stateOn);
  }
}

- (void)centralManager:(CBCentralManager *)central
    didDiscoverPeripheral:(CBPeripheral *)peripheral
        advertisementData:(NSDictionary<NSString *, id> *)advertisementData
                     RSSI:(NSNumber *)RSSI {
  NSString *macStr = @"";
  NSString *manufacturerStr = @"";
  NSData *data = advertisementData[@"kCBAdvDataManufacturerData"];
  if (data.length >= 6) {
    Byte macBuf[6] = {0};
    if (data.length > 8) {
      [data getBytes:macBuf range:NSMakeRange(2, 6)];
    } else {
      [data getBytes:macBuf range:NSMakeRange(data.length - 6, 6)];
    }
    NSMutableString *macAddress = [[NSMutableString alloc] init];
    for (int i = 0; i < 6; i++) {
      NSString *hexStr = [[NSString stringWithFormat:@"%02x", (macBuf[i]) & 0xff] uppercaseString];
      if (i == 0) {
        [macAddress appendString:hexStr];
      } else {
        [macAddress appendFormat:@":%@", hexStr];
      }
    }
    macStr = macAddress;

    Byte manufacturer[2] = {0};
    [data getBytes:manufacturer range:NSMakeRange(0, 2)];
    manufacturerStr = [NSString stringWithFormat:@"<%02x%02x>", (manufacturer[0]) & 0xff, (manufacturer[1]) & 0xff];
  }

  NSString *name = peripheral.name ?: @"GTL1 Watch";
  NSString *lowerName = [name lowercaseString];
  BOOL looksLikeGtl1 = [lowerName containsString:@"gtl1"] ||
                       [lowerName containsString:@"gtl"] ||
                       [lowerName containsString:@"runme"] ||
                       [lowerName containsString:@"starmax"] ||
                       [lowerName containsString:@"watch"];
  if (![manufacturerStr isEqualToString:@"<0001>"] && !looksLikeGtl1) {
    return;
  }
  if (!macStr.length) {
    macStr = peripheral.identifier.UUIDString ?: name;
  }

  if ([name hasSuffix:@"-0000"]) {
    return;
  }
  if ([self containsObject:name mac:macStr]) {
    return;
  }

  STDeviceModel *deviceModel = [[STDeviceModel alloc] init];
  deviceModel.peripheral = peripheral;
  deviceModel.name = name;
  deviceModel.mac = macStr;
  deviceModel.rssi = RSSI;
  [self.deviceModels addObject:deviceModel];
  if (self.updatePerpheral) {
    self.updatePerpheral(self.deviceModels);
  }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
  peripheral.delegate = self;
  for (STDeviceModel *deviceModel in self.deviceModels) {
    if ([deviceModel.peripheral isEqual:peripheral]) {
      self.actDeviceModel = deviceModel;
      break;
    }
  }
  [self stopScan];
  [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central
 didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
  if (self.updateConnect) {
    self.updateConnect(NO);
  }
}

- (void)centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
  if (self.updateConnect) {
    self.updateConnect(NO);
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
  for (CBService *service in peripheral.services) {
    [peripheral discoverCharacteristics:nil forService:service];
  }
}

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error {
  if (![service.UUID.UUIDString isEqualToString:UUID_Service]) {
    return;
  }
  for (CBCharacteristic *characteristic in service.characteristics) {
    NSString *uuidStr = characteristic.UUID.UUIDString;
    if ([uuidStr isEqualToString:UUID_Write_Char]) {
      self.writeCharacter = characteristic;
    }
    if ([uuidStr isEqualToString:UUID_Notify_Char]) {
      [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
  }
}

- (void)peripheral:(CBPeripheral *)peripheral
didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
  if (![characteristic.UUID.UUIDString isEqualToString:UUID_Notify_Char]) {
    return;
  }
  if (self.updateConnect) {
    self.updateConnect(error == nil && characteristic.isNotifying);
  }
}

- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
  if (error) {
    return;
  }
  [STBlueToothData.sharedInstance notifyRunmefit:peripheral
                                  WriteCharacter:self.writeCharacter
                                  Characteristic:characteristic
                                           Error:error
                                        Complete:^(NSError *_Nonnull notifyError, REV_TYPE revType, ERROR_TYPE errorType, id _Nonnull responseObject) {
                                          if (notifyError) {
                                            return;
                                          }
                                          NSDictionary *dict = @{
                                            ST_RevType_Key : @(revType),
                                            ST_ErrorType_Key : @(errorType)
                                          };
                                          [[NSNotificationCenter defaultCenter] postNotificationName:Nof_Revice_Data_Key
                                                                                              object:responseObject
                                                                                            userInfo:dict];
                                        }];
}

- (void)startScan {
  if (!self.stateOn) {
    return;
  }
  [self prepareScan];
}

- (void)stopScan {
  [self.centralManager stopScan];
}

- (void)connectPerpheral:(STDeviceModel *)deviceModel {
  if (deviceModel && self.stateOn) {
    [self.centralManager connectPeripheral:deviceModel.peripheral options:nil];
  } else if (self.updateConnect) {
    self.updateConnect(NO);
  }
}

- (void)cancelPeripheral:(STDeviceModel *)deviceModel {
  if (deviceModel && self.stateOn) {
    [self.centralManager cancelPeripheralConnection:deviceModel.peripheral];
  }
}

- (void)writeCommand:(NSData *)data {
  if (self.writeCharacter && data.length > 0) {
    [self.actDeviceModel.peripheral writeValue:data
                              forCharacteristic:self.writeCharacter
                                           type:CBCharacteristicWriteWithResponse];
  }
}

- (void)prepareScan {
  [self.deviceModels removeAllObjects];
  NSArray *uuidArr = @[ [CBUUID UUIDWithString:UUID_Service] ];
  NSArray *peripherals = [self.centralManager retrieveConnectedPeripheralsWithServices:uuidArr];
  for (CBPeripheral *peripheral in peripherals) {
    STDeviceModel *deviceModel = [[STDeviceModel alloc] init];
    deviceModel.peripheral = peripheral;
    deviceModel.name = peripheral.name ?: @"GTL1 Watch";
    deviceModel.mac = peripheral.identifier.UUIDString ?: @"connected";
    deviceModel.rssi = @0;
    [self.deviceModels addObject:deviceModel];
  }
  if (self.updatePerpheral) {
    self.updatePerpheral(self.deviceModels);
  }
  [self.centralManager scanForPeripheralsWithServices:nil options:nil];
}

- (BOOL)containsObject:(NSString *)name mac:(NSString *)mac {
  NSArray *names = [self.deviceModels valueForKeyPath:@"name"];
  NSArray *macs = [self.deviceModels valueForKeyPath:@"mac"];
  return [macs containsObject:mac] || [names containsObject:name];
}

@end

#else

@implementation PhoraGtl1BleManager

+ (instancetype)sharedInstance {
  static PhoraGtl1BleManager *manager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    manager = [[PhoraGtl1BleManager alloc] init];
  });
  return manager;
}

- (void)startScan {}
- (void)stopScan {}
- (void)connectPerpheral:(STDeviceModel *)deviceModel {}
- (void)cancelPeripheral:(STDeviceModel *)deviceModel {}
- (void)writeCommand:(NSData *)data {}

@end

#endif
