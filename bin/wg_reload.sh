#!/bin/bash

IF=${1:-wg0}

wg syncconf "${IF}" <(wg-quick strip "${IF}")
