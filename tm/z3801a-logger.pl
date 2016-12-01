#!/usr/bin/perl -w
#
# z3801a-logger.pl
# version 0.9 -- 6 January 2003
#
# Query HP Z3801A GPS-disciplined oscillator and log results
# 
# Copyright 2003 by John R. Ackermann  N8UR (jra@febo.com)
#
# This program may be copied, modified, distributed and used for 
# any legal purpose provided that (a) the copyright notice above as well
# as these terms are retained on all copies; (b) any modifications that 
# correct bugs or errors, or increase the program's functionality, are 
# sent via email to the author at the address above; and (c) such 
# modifications are made subject to these license terms.

# version 0.9a -- 1 February 2003
# Changed format of timestamp (to use only ":" as element separators)
# so that Stable32 won't think it's multiple fields.

use strict;
use vars qw( $OS_win $ob $port );
use POSIX qw(setsid);
use Getopt::Std;
use Device::SerialPort;

#----------
# handle signals and errors -- mainly to clear lockfile on termination
my $lockfile;
sub sig_handler {
	undef $ob;
	if (-e $lockfile) {unlink $lockfile;}
	close LOG;
	exit(0);
}

# there's got to be a better way!
$SIG{'HUP'} = 'sig_handler';
$SIG{'INT'} = 'sig_handler';
$SIG{'KILL'} = 'sig_handler';
$SIG{'STOP'} = 'sig_handler';
$SIG{'TERM'} = 'sig_handler';
#----------

#----------
# display usage
my $opt_string = 'dhi:f:p:';

sub usage() {
print STDERR << "EOF";

usage: $0 [-dh] -f logfile -i log_interval -p serial_port

-d	: run as daemon
-h	: this (help) message
-f	: logfile using full pathname;
	  for output to console, use "-f -"
-i	: logging interval in seconds
-p	: serial port ("ttyS1")

EOF
}
#----------

#----------
# daemonize
sub daemonize {
	chdir '/' or die "Can't chdir to /: $!";
	umask 0;
	open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
	open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
	open STDERR, '>/dev/null' or die "Can't write to /dev/null: $!";
	defined(my $pid = fork) or die "Can't fork: $!";
	exit if $pid;
	setsid or die "Can't start a new session: $!";
}
#----------

getopts( "$opt_string", \my %opt ) or usage() and exit;

# print usage
usage() and exit if $opt{h};

# run as daemon?
&daemonize if $opt{d};

# set variables to command line params
my $interval = $opt{i};
my $portbase = $opt{p};
my $logfile = $opt{f};

# initialize other variables
my $tint = 0;
my $last_tint = 0;
my $efc = "";
my $tunc = "";

#----------
# set up serial port
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

# end of message characters for serial input
$ob->are_match("\n","\r");
#----------

#----------
# set up logfile
open (LOG, ">>$logfile") ||
	die "Can't open logfile $logfile!\n";
# set nonbuffered mode
select(LOG), $| = 1;
#----------

#----------
# main loop
while (1) {

	#----------
	# get time interval
		$last_tint = $tint;
		$ob->lookclear;
		$tint = "";
		$ob->write(":PTIME:TINT?\n");
		until ("" ne $tint) {
			$tint = $ob->lookfor;
		}

		# is there a superfluous error message?
		if (index($tint,">") != -1) {
			$tint = substr($tint,index($tint,">") + 1);
		}

		# not sure why two of these are necessary...
		chomp $tint;
		chomp $tint;

		# fudge values to please Stable32
		#   -- tweak duplicates
		if ($tint == $last_tint) {
			my ($val1,$val2) = split /E/,$tint;
			$val1 = $val1 + 0.001;
			$tint = $val1 . "E" . $val2;
		}
		#   -- tweak zero values
		if ($tint == 0) {
			$tint = "1.000E-99";
			}
	#----------
	# get EFC
		$ob->lookclear;
		$efc = "";
		$ob->write(":DIAG:ROSC:EFC:ABS?\n");
		until ("" ne $efc) {
			$efc = $ob->lookfor;
		}

		# is there a superfluous error message?
		if (index($efc,">") != -1) {
			$efc = substr($efc,index($efc,">") + 1);
		}
		chomp $efc;
		chomp $efc;

	#----------
	# get predicted uncertainty
		$ob->lookclear;
		$tunc = "";
		$ob->write(":ROSC:HOLD:TUNC:PRED?\n");
		until ("" ne $tunc) {
			$tunc = $ob->lookfor;
		}

		# is there a superfluous error message?
		if (index($tunc,">") != -1) {
			$tunc = substr($tunc,index($tunc,">") + 1);
		}
		chomp $tunc;
		chomp $tunc;

		# get rid of ',0' at the end of the return
		substr($tunc,-2) = "";

	# print routine
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
		  = gmtime;

		printf LOG 
		  "%4.4u:%2.2u:%2.2u:%2.2u:%2.2u:%2.2u %0+.3E %6u %0+.3E\n",
		  $year+1900,$mon+1,$mday,$hour,$min,$sec,$tint,$efc,$tunc;

	# sleep for loop
	sleep $interval;
}	
#----------

exit 0;
