#!/usr/bin/python

from __future__ import print_function
import sys
import pynmea2

def dump_file(filename):
    with pynmea2.NMEAFile(filename) as file:
        for msg in file:
            print("%r\n" % msg)

def main():
    dump_file(sys.argv[1])

if __name__ == "__main__":
    main()
