#!/usr/bin/perl -w

use strict;
use vars qw($ob $port);
use Getopt::Std;
use Device::SerialPort;

my $lockfile;
sub sig_handler {
    undef $ob;
    if (-e $lockfile) {unlink $lockfile;}
    exit(0);
}

$SIG{'HUP'} = 'sig_handler';
$SIG{'INT'} = 'sig_handler';
$SIG{'KILL'} = 'sig_handler';
$SIG{'STOP'} = 'sig_handler';
$SIG{'TERM'} = 'sig_handler';

my $opt_string = 'hp:';

sub usage() {
print STDERR << "EOF";

usage: $0 [-h] -p serial_port

-h	: this (help) message
-p	: serial port ("ttyS1")

EOF
}

getopts( "$opt_string", \my %opt ) or usage() and exit;

usage() and exit if $opt{h};
usage() and exit if ! defined $opt{p};

my $portbase = $opt{p};

my $quiet = "1";
my $port = "/dev/" . $portbase;
$lockfile = "/var/lock/LCK.." . $portbase;

$ob = Device::SerialPort->new ($port,$quiet,$lockfile);
	die "Can't open serial port $port!\n" unless ($ob);
$ob->baudrate(19200)	|| die "fail setting baud after 0";
$ob->parity("odd")	|| die "fail setting parity";
$ob->databits(7)	|| die "fail setting databits";
$ob->stopbits(1)	|| die "fail setting stopbits";
$ob->handshake("none")	|| die "fail setting handshake";
$ob->write_settings || die "no settings";

$ob->are_match("sci\n", "\r");

$ob->write("*CLS\n");


while (1) {
    $ob->write(":SYSTEM:STATUS?\n");
    my ($count_in, $output) = $ob->read(1024);
    print $output;
}

exit 0;

