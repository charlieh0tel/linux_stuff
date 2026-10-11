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

# version 0.9b -- 5 February 2003
# Another version of timestamp, to match iso8601

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
$SIG{'TERM'} = 'sig_handler';
#----------

#----------
# display usage
my $opt_string = 'dhi:f:p:b:F:';

sub usage() {
print STDERR << "EOF";

usage: $0 [-dh] [-b baud] [-F framing] -f logfile -i log_interval -p serial_port

-d	: run as daemon
-h	: this (help) message
-f	: logfile using full pathname;
	  for output to console, use "-f -"
-i	: logging interval in seconds
-p	: serial port ("ttyS1")
-b	: baud rate (default 19200)
-F	: framing, databits/parity/stopbits (default 7O1; Z3805A is 8N1)

EOF
}
#----------

#----------
# daemonize
sub daemonize {
	chdir '/' or die "Can't chdir to /: $!";
	umask 022;
	open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
	open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
	open STDERR, '>/dev/null' or die "Can't write to /dev/null: $!";
	defined(my $pid = fork) or die "Can't fork: $!";
	exit if $pid;
	setsid or die "Can't start a new session: $!";
}
#----------

getopts( "$opt_string", \my %opt ) or usage() and exit 1;

# print usage
usage() and exit if $opt{h};
usage() and exit 1
	unless defined $opt{i} && defined $opt{p} && defined $opt{f};

# set variables to command line params
my $interval = $opt{i};
my $portbase = $opt{p};
my $logfile = $opt{f};
my $baud = $opt{b} // 19200;
my $framing = uc($opt{F} // "7O1");

die "Interval must be a positive integer\n" unless $interval =~ /^[1-9]\d*$/;
die "Baud must be a positive integer\n" unless $baud =~ /^[1-9]\d*$/;
my ($databits, $parity, $stopbits) = $framing =~ /^([5-8])([NOE])([12])$/
	or die "Framing must look like 7O1 or 8N1\n";
$parity = { N => "none", O => "odd", E => "even" }->{$parity};

# initialize other variables
my $tint = 0;
my $last_tint = 0;
my $efc = "";
my $tunc = "";

#----------
# set up logfile
open (LOG, ">>$logfile") ||
	die "Can't open logfile $logfile!\n";
# set nonbuffered mode
select(LOG), $| = 1;
#----------

#----------
# set up serial port
my $quiet = "1";
my $port = "/dev/" . $portbase;
die "Can't access serial port $port!\n" unless -r $port && -w $port;

# run as daemon?
&daemonize if $opt{d};

$lockfile = "/var/lock/LCK.." . $portbase;

$ob = Device::SerialPort->new ($port,$quiet,$lockfile);
	die "Can't open serial port $port!\n" unless ($ob);
$ob->baudrate($baud)	|| die "fail setting baud";
$ob->parity($parity)	|| die "fail setting parity";
$ob->databits($databits)	|| die "fail setting databits";
$ob->stopbits($stopbits)	|| die "fail setting stopbits";
$ob->handshake("none")	|| die "fail setting handshake";
$ob->read_const_time(100);
$ob->write_settings || die "no settings";

# end of message characters for serial input
$ob->are_match("\n","\r");
#----------

#----------
# send a query and wait up to about 5 seconds for a reply
sub query {
	my ($cmd) = @_;
	$ob->purge_rx;
	$ob->lookclear;
	$ob->write("$cmd\n");
	for (1 .. 50) {
		my $reply = $ob->lookfor;
		return undef unless defined $reply;
		if ($reply eq "") {
			select(undef, undef, undef, 0.1);
			next;
		}

		# is there a superfluous error message?
		if (index($reply,">") != -1) {
			$reply = substr($reply,index($reply,">") + 1);
		}

		# not sure why two of these are necessary...
		chomp $reply;
		chomp $reply;

		# skip the echoed command (the Z3805A echoes, the Z3801A doesn't)
		$reply =~ s/^\s+|\s+\z//g;
		next if $reply eq "" || lc($reply) eq lc($cmd);
		return $reply;
	}
	return undef;
}
#----------

#----------
# main loop
while (1) {

	#----------
	# get time interval
		$last_tint = $tint;
		$tint = query(":PTIME:TINT?");

		# skip this sample if the unit didn't answer
		unless (defined $tint) {
			$tint = $last_tint;
			sleep $interval;
			next;
		}

		# fudge values to please Stable32
		#   -- tweak duplicates
		if ($tint == $last_tint) {
			my ($val1,$val2) = split /E/,$tint;
			$val1 = $val1 + 0.001;
			$tint = defined $val2 ? $val1 . "E" . $val2 : $val1;
		}
		#   -- tweak zero values
		if ($tint == 0) {
			$tint = "1.000E-99";
			}
	#----------
	# get EFC
		$efc = query(":DIAG:ROSC:EFC:ABS?");

	#----------
	# get predicted uncertainty
		$tunc = query(":ROSC:HOLD:TUNC:PRED?");

		unless (defined $efc && defined $tunc) {
			sleep $interval;
			next;
		}

		# get rid of ',0' at the end of the return
		$tunc =~ s/,0\z//;

	# print routine
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
		  = gmtime;

		printf LOG 
		  "%4.4u-%2.2u-%2.2uT%2.2u:%2.2u:%2.2u %0+.3E %6u %0+.3E\n",
		  $year+1900,$mon+1,$mday,$hour,$min,$sec,$tint,$efc,$tunc;

	# sleep for loop
	sleep $interval;
}	
#----------

exit 0;
