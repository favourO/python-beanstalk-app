#import <CoreBluetooth/CoreBluetooth.h>
#import <Foundation/Foundation.h>

@interface STDeviceModel : NSObject

@property(nonatomic, strong) CBPeripheral *peripheral;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSString *mac;
@property(nonatomic, strong) NSNumber *rssi;

@end
