#!/usr/bin/python

import time

import usbtmc

_AGILENT_USB_VID=0x0957
_AGILENT_USB_53230A_PID=0x1907

_TI=(2,1)

def _ConfigureInput(counter, n):
    counter.write("INP%d:COUP DC" % n)
    counter.write("INP%d:IMP 50" % n)
    counter.write("INP%d:LEV:ABS 2.5" % n)
    counter.write("INP%d:NREJ ON" % n)

def main():
    counter = usbtmc.Instrument(_AGILENT_USB_VID, _AGILENT_USB_53230A_PID)
    counter.timeout = 5.
    counter.open()
    try:
        counter.clear()
        print "Resetting counter"
        counter.write("*RST")
        counter.write("*RST")
        print "*IDN?", counter.ask("*IDN?")
        print "Configuring input #1"
        _ConfigureInput(counter, 1)
        print "Configuring input #2"
        _ConfigureInput(counter, 2)
        #print "Checking input configurations"
        #print "INP1:LEV?", counter.ask("INP1:LEV?")
        #print "INP2:LEV?", counter.ask("INP2:LEV?")
        print "Configuring time interval mode"
        counter.write("CONF:TINT (@%d),(@%d)" % _TI)
        count = 0
        while True:
            reading = float(counter.ask("READ?"))
            print count, reading
            count = count + 1
    except Exception, e:
        print e
    finally:
        counter.close()
        

if __name__ == "__main__":
    main()
    
    
