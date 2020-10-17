#!/usr/bin/env python3

import asyncio
import atexit
import serial
import sys
import time

import scpi
import scpi.transports.rs232
import scpi.transports.gpib.prologix
import scpi.wrapper

def record(adevice):
    print("setting instrument time")
    now = time.gmtime()
    adevice.command("SYSTEM:DATE %s" % time.strftime("%Y,%m,%d", now))
    # this will fail if we catch a leapsecond.
    adevice.command("SYSTEM:TIME %s" % time.strftime("%H,%M,%S", now))

    (y, mo, d) = adevice.ask("SYSTEM:DATE?").split(',')
    (h, m, s) = adevice.ask("SYSTEM:TIME?").split(',')
    print("instrument time reads as %s/%s/%s %s:%s:%s"
          % (mo, d, y, h, m, s))

    adevice.command("CONF:TEMP TCOUPLE,K,(@101)")
    adevice.command("UNIT:TEMP C")
    adevice.command("CONF:VOLT:DC (@118, 120)")
    adevice.command("VOLT:DC:RANG 1V,(@118)")
    adevice.command("VOLT:DC:RANG 10V,(@120)")

    adevice.command("ROUTE:SCAN (@101, 118, 120)")

    #adevice.command("FORMAT:READ:ALAR ON")
    #adevice.command("FORMAT:READ:CHAN ON")
    adevice.command("FORMAT:READ:TIME ON")
    adevice.command("FORMAT:READ:TIME:TYPE ABS")
    adevice.command("FORMAT:READ:UNIT ON")

    if not adevice.wait_for_complete(1):
        print("setup failed")
        return
    
    while True:
        reading = adevice.ask("READ?")
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
    aiodevice = scpi.SCPIDevice(protocol)
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
