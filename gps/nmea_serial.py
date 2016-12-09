#!/usr/bin/python

from __future__ import print_function
import sys
import serial
import pynmea2

def dump_serial(filename):
    with serial.Serial(filename) as port:
        reader = pynmea2.NMEAStreamReader(port)
        while True:
            try:
                for msg in reader.next():
                    print("%r\n" % msg)
            except KeyboardInterrupt:
                break
            except:
                print("Could not parse record\n");

def main():
    dump_serial(sys.argv[1])

if __name__ == "__main__":
    main()
    
