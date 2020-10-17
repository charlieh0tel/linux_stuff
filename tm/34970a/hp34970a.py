#!/usr/bin/env python3

import asyncio
import atexit
import calendar
import decimal
import serial
import sys
import time

import scpi
import scpi.transports.rs232
import scpi.transports.gpib.prologix
import scpi.wrapper


class HP34970a(scpi.SCPIDevice):
    async def configure_thermocouple(self, channels, probe_type='K', unit=None):
        await self.command("CONF:TEMP TCOUPLE,%s,%s" % (probe_type, self._channel_string(channels)))
        if unit is not None:
            await self.command("UNIT:TEMP %s,%s" % (unit, self._channel_string(channels)))
        
    async def configure_vdc(self, channels, vrange=None):
        await self.command("CONF:VOLT:DC %s" % self._channel_string(channels))
        if vrange is not None:
            await self.command("VOLT:DC:RANG %s,%s" % (vrange, self._channel_string(channels)))

    async def set_scan(self, channels):
        await self.command("ROUTE:SCAN %s" % self._channel_string(channels))
    
    async def set_instrument_time(self):
        now = time.gmtime()
        await self.command("SYSTEM:DATE %s" % time.strftime("%Y,%m,%d", now))
        # This will fail if we caught a leapsecond.
        await self.command("SYSTEM:TIME %s" % time.strftime("%H,%M,%S", now))

    async def get_instrument_time(self):
        # There is bug here if there is a rollover between calls.
        ymd = await self.ask("SYSTEM:DATE?")
        (hms, fraction_s) = (await self.ask("SYSTEM:TIME?")).split('.')
        return time.strptime(ymd + " " + hms, "%Y,%m,%d %H,%M,%S")

    @staticmethod
    def _channel_string(channels):
        return "(@%s)" % ",".join(map(str, channels))


def record(device):
    print("setting instrument time")
    device.set_instrument_time()

    inst_time = device.get_instrument_time()
    print("instrument time reads as (Zulu)", time.strftime("%m/%d/%Y %H:%M:%S", inst_time))

    device.configure_thermocouple([101], probe_type='K', unit='C')
    device.configure_vdc([118], vrange="1V")
    device.configure_vdc([120], vrange="10V")
    device.set_scan([101, 118, 120])

    #device.command("FORMAT:READ:ALAR ON")
    #device.command("FORMAT:READ:CHAN ON")
    device.command("FORMAT:READ:TIME ON")
    device.command("FORMAT:READ:TIME:TYPE ABS")
    device.command("FORMAT:READ:UNIT ON")

    if not device.wait_for_complete(1):
        print("setup failed")
        return
    
    while True:
        reading = device.ask("READ?")
        print(reading)
        time.sleep(1)


def main(argv):
    port = argv[1]
    gpib_address = argv[2]
    print("%s %s" % (port, gpib_address))
    if gpib_address == "RS232":
        transport = scpi.transports.rs232.get(
            port,
            baudrate=115200,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            rtscts=True,
            timeout=1)
    else:
        transport = scpi.transports.gpib.prologix.get(port)
        transport.set_address(int(gpib_address))

    protocol = scpi.SCPIProtocol(transport)
    aiodevice = HP34970a(protocol)
    device = scpi.wrapper.AIOWrapper(aiodevice)

    atexit.register(device.quit)

    (make, model, serial_num, software_version) = device.identify()
    print("%s %s\n" % (make, model))
    device.reset()

    try:
        record(device)
    finally:
        device.reset()
        device.reset()

if __name__ == "__main__":
    main(sys.argv)
