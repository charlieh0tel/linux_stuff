#!/usr/bin/perl -w

use strict;
use warnings;

use Getopt::Std;
use Device::SerialPort;
use Curses;
use Expect;

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
my $quiet = "1";

my $port = tie(*FH, 'Device::SerialPort', $portdev, $quiet)
    || die "Can't open serial port $portdev!\n";
if ($opt{z}) {
    $port->baudrate(19200)	 || die "fail setting baud after 0";
    $port->parity("odd")	 || die "fail setting parity";
    $port->databits(7)	 || die "fail setting databits";
} else {
    # The default is 9600 on 58503B.
    $port->baudrate(19200)	 || die "fail setting baud after 0";
    $port->parity("none")	 || die "fail setting parity";
    $port->databits(8)	 || die "fail setting databits";
}
$port->stopbits(1)	 || die "fail setting stopbits";
$port->handshake("none") || die "fail setting handshake";
$port->write_settings    || die "no settings";

my $timeout = 5;
my $status = 0;

my $win = new Curses;

my $exp = Expect->exp_init(\*FH);
$exp->send("*CLS\n");

$exp->expect($timeout,
	     [
	      qr'E-[0-9][0-9][0-9]> $',
	      sub {
		  my $fh = shift;
		  $fh->send("*CLS\n");
		  $status = 0;
		  exp_continue;
	      }
	     ],
	     [
	      qr'scpi > $',
	      sub {
		  my $fh = shift;
		  if ($status) {
		      my @lines = split(/\n/, $fh->before());
		      shift @lines;
		      my $status_screen = join("\n", @lines);
		      $status_screen =~ s/\r//g;
		      $win->clear;
		      $win->addstr(0, 0, $status_screen);
		      $win->refresh;
		  }
		  $fh->send(":SYSTEM:STATUS?\n");
		  $status = 1;
		  exp_continue;
	      }
	     ],
	     [
	      timeout =>
	      sub {
		  my $fh = shift;
		  $fh->send("*CLS\n");
		  $status = 0;
		  exp_continue;
	      }
	     ],
    );

exit 0;
