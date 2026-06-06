#import <CoreBluetooth/CoreBluetooth.h>
#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#if !TARGET_OS_SIMULATOR
#import <RunmefitSDK/RunmefitSDK.h>
#endif

#import "STDeviceModel.h"

@interface PhoraGtl1BleManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

@property(nonatomic, assign) BOOL stateOn;
@property(nonatomic, copy) void (^updateState)(BOOL state);
@property(nonatomic, strong) CBCentralManager *centralManager;
@property(nonatomic, strong) NSMutableArray<STDeviceModel *> *deviceModels;
@property(nonatomic, copy) void (^updatePerpheral)(NSArray<STDeviceModel *> *deviceModels);
@property(nonatomic, strong) STDeviceModel *actDeviceModel;
@property(nonatomic, strong) CBCharacteristic *writeCharacter;
@property(nonatomic, copy) void (^updateConnect)(BOOL connect);

+ (instancetype)sharedInstance;
- (void)startScan;
- (void)stopScan;
- (void)connectPerpheral:(STDeviceModel *)deviceModel;
- (void)cancelPeripheral:(STDeviceModel *)deviceModel;
- (void)writeCommand:(NSData *)data;

@end
