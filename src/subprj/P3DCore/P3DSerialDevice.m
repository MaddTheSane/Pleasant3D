//
//  P3DSerialDevice.m
//  P3DCore
//
//  Created by Eberhard Rensch on 17.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free Software 
//  Foundation; either version 3 of the License, or (at your option) any later 
//  version.
// 
//  This program is distributed in the hope that it will be useful, but WITHOUT ANY 
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
//  PARTICULAR PURPOSE. See the GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License along with 
//  this program; if not, see <http://www.gnu.org/licenses>.
// 
//  Additional permission under GNU GPL version 3 section 7
// 
//  If you modify this Program, or any covered work, by linking or combining it 
//  with the P3DCore.framework (or a modified version of that framework), 
//  containing parts covered by the terms of Pleasant Software's software license, 
//  the licensors of this Program grant you additional permission to convey the 
//  resulting work.
//
#import "P3DSerialDevice.h"
#import "AvailableDevices.h"

@interface P3DSerialDevice (Private)
- (BOOL)openSerialPort;
- (void)closeSerialPort;
@end


@implementation P3DSerialDevice

@synthesize port, deviceName, deviceIsValid, quiet, errorMessage, activeMachineJob;
@dynamic driverClass, baudRate, deviceIsBusy;

- (id)initWithPort:(ORSSerialPort*)p
{
    self = [super init];
    if(self)
    {
        port = p;
        port.delegate = self;
    }
    return self;
}

- (void)dealloc
{
	[port close];
}

- (BOOL)registerDeviceIfValid
{
    PSLog(@"Machining",PSPrioNormal, @"Trying %@ on %@",[port name], [self className]);
    [port open];
    if(port.isOpen)
    {
        port.baudRate = @(self.baudRate);
        if([self validateSerialDevice])
        {
            deviceName = [self fetchDeviceName];
            self.deviceIsValid = YES;
        }
        else
            [port close];
    }
    return deviceIsValid;
}

- (NSError*)sendStringAsynchron:(NSString*)string
{
    NSError* error=nil;
	if ([string length]>0) {
        if([port isOpen]) {
            if(![port sendData:[string dataUsingEncoding:NSUTF8StringEncoding]] && ! quiet)
                PSErrorLog(@"Error writing to device - %@.", [error description]);
        }
    }
    return error;
}

- (NSInteger)baudRate
{
    return B38400;
}

#pragma mark -

// These methods must be overloaded
- (NSString*)fetchDeviceName
{
	return [port name];
}

- (BOOL)validateSerialDevice
{
	return NO;
}

// Return the driver class, this device driver is part of
- (Class)driverClass
{
	return nil;
}

+ (NSSet *)keyPathsForValuesAffectingDeviceIsBusy {
    return [NSSet setWithObjects:@"activeMachineJob", nil];
}

- (BOOL)deviceIsBusy
{
    return activeMachineJob!=nil;
}
     
#pragma mark ORSSerialPortDelegate
- (void)serialPortWasOpened:(ORSSerialPort *)serialPort {
     PSLog(@"Machining",PSPrioNormal, @"Port %@ opened on %@",[port name], [self className]);
}

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
    if(serialPort == port) {
        while([data length] > 0) {
            if(_dataBuffer==nil)
                _dataBuffer = [NSMutableData data];
            NSRange crRange = [data rangeOfData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0, data.length)];
            if(crRange.location != NSNotFound) {
                [_dataBuffer appendData:[data subdataWithRange:NSMakeRange(0, crRange.location+crRange.length)]];
                 
                NSString *receivedText = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                PSLog(@"devices", PSPrioNormal, @"Serial Port [%@] Data Received: %@", [port name], receivedText);
                
                _dataBuffer = nil;
            
                [activeMachineJob handleDeviceResponse:receivedText];
                if(crRange.location+crRange.length<data.length)
                    data = [data subdataWithRange:NSMakeRange(crRange.location+crRange.length, data.length-crRange.location-crRange.length)];
                else
                    data = nil;
            } else {
                [_dataBuffer appendData:data];
                data = nil;
            }
        }
    }
}


- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error {
    PSErrorLog(@"Port [%@] did encountrt Error: %@", [port name], [error description]);
}


- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort
{
    // TODO: Handle this
    if(serialPort == port)
        PSErrorLog(@"Port [%@] serialPortWasRemovedFromSystem. Not Handled!", [port name]);
}
@end
