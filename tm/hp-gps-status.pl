#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Std;
use Device::SerialPort;
use Curses;

my $opt_string = 'hp:z';

sub usage() {
print STDERR << "EOF";

usage: $0 [-h] -p serial_port

-h	: this (help) message
-p	: serial port ("/dev/ttyS1")
-z	: use 7 bits, 19200 baud, odd parity

EOF
}

getopts( "$opt_string", \my %opt ) or usage() and exit;

usage() and exit if $opt{h};
usage() and exit if ! defined $opt{p};

my $portdev = $opt{p};
my $quiet = 1;

my $port = Device::SerialPort->new($portdev, $quiet)
    || die "Can't open serial port $portdev!\n";
if ($opt{z}) {
    $port->baudrate(19200)	 || die "fail setting baud after 0";
    $port->parity("odd")	 || die "fail setting parity";
    $port->databits(7)		 || die "fail setting databits";
} else {
    # The default is 9600 on 58503B.
    $port->baudrate(19200)	 || die "fail setting baud after 0";
    $port->parity("none")	 || die "fail setting parity";
    $port->databits(8)		 || die "fail setting databits";
}
$port->stopbits(1)	 || die "fail setting stopbits";
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
	    shift @lines;	# echoed command
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
