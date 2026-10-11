#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Std;
use Device::SerialPort;
use Curses;

my $opt_string = 'hp:zb:F:';

sub usage() {
print STDERR << "EOF";

usage: $0 [-h] [-z] [-b baud] [-F framing] -p serial_port

-h	: this (help) message
-p	: serial port ("/dev/ttyS1")
-z	: use 7 bits, 19200 baud, odd parity (Z3801A); same as -F 7O1
-b	: baud rate (default 19200)
-F	: framing, databits/parity/stopbits (default 8N1)

EOF
}

getopts( "$opt_string", \my %opt ) or usage() and exit 1;

usage() and exit if $opt{h};
usage() and exit 1 if ! defined $opt{p};

my $portdev = $opt{p};
my $baud = $opt{b} // 19200;
my $framing = uc($opt{F} // ($opt{z} ? "7O1" : "8N1"));

die "Baud must be a positive integer\n" unless $baud =~ /^[1-9]\d*$/;
my ($databits, $parity, $stopbits) = $framing =~ /^([5-8])([NOE])([12])$/
    or die "Framing must look like 7O1 or 8N1\n";
$parity = { N => "none", O => "odd", E => "even" }->{$parity};
my $quiet = 1;

my $port = Device::SerialPort->new($portdev, $quiet)
    || die "Can't open serial port $portdev!\n";
$port->baudrate($baud)	 || die "fail setting baud";
$port->parity($parity)	 || die "fail setting parity";
$port->databits($databits)	 || die "fail setting databits";
$port->stopbits($stopbits)	 || die "fail setting stopbits";
$port->handshake("none") || die "fail setting handshake";
$port->write_settings    || die "no settings";

# Non-blocking-ish reads: each read() call waits at most 100ms.
$port->read_const_time(100);
$port->read_char_time(0);

my $timeout_ms = 5000;
my $win = new Curses;

sub cleanup {
    endwin;
    undef $port;
}

END { cleanup }

$SIG{INT} = $SIG{TERM} = sub {
    $SIG{INT} = $SIG{TERM} = 'DEFAULT';
    cleanup;
    exit 1;
};

# Drain any stale input, then prime with *CLS.
$port->read(4096);
$port->write("*CLS\n");

my $buf = '';
my $elapsed = 0;
my $expecting_status = 0;

while (1) {
    my ($n, $chunk) = $port->read(256);
    if ($n) {
	$buf .= $chunk;
	$elapsed = 0;
    } else {
	$elapsed += 100;
    }

    if ($buf =~ /E-\d{3}> \z/) {
	$port->write("*CLS\n");
	$buf = '';
	$expecting_status = 0;
    } elsif ($buf =~ /scpi > \z/) {
	if ($expecting_status) {
	    my @lines = split(/\n/, $buf);
	    pop @lines;		# the prompt line
	    shift @lines	# echoed command (the Z3801A doesn't echo)
		if @lines && $lines[0] =~ /^\s*:SYSTEM:STATUS\?\s*$/i;
	    my $screen = join("\n", @lines);
	    $screen =~ s/\r//g;
	    $win->clear;
	    $win->addstr(0, 0, $screen);
	    $win->refresh;
	}
	$port->write(":SYSTEM:STATUS?\n");
	$buf = '';
	$expecting_status = 1;
    } elsif ($elapsed >= $timeout_ms) {
	$port->write("*CLS\n");
	$buf = '';
	$expecting_status = 0;
	$elapsed = 0;
    }
}
