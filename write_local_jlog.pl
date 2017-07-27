#!/opt/msys/3rdParty/bin/perl -w

use strict;

# read the usage here - it's important!

sub usage {
  print <<END 
Usage: write_local_jlog.pl [OPTION]....

Write a local copy of a jlog to a file.

Options:

--source | -s <FILE> The jlog to read from, default is /var/log/ecelerity/event_hydrant.rt
--output | -o <FILE> The file to write to, default is /var/log/ecelerity/event_hydrant.csv
--daemonize | -d Whether or not to daemonize, default is false
--help | -h  This text

IMPORTANT: Once you run this, it will add a subscriber to the source JLog.  If you decide to stop running
this for an extended period of time/forever, you MUST IMMEDIATELY remove that subscriber with

  /opt/msys/jlog/bin/jlogctl -e csvwriter /var/log/ecelerity/event_hydrant.rt

Failure to do this will cause you to quickly run out of disk space.
END
}

use Getopt::Long;
use IO::File;
use JLog::Reader;
use POSIX;

my $source = "/var/log/ecelerity/event_hydrant.rt";
my $dest = "/var/log/ecelerity/event_hydrant.csv";
my $daemonize = '';

sub open_dest {
  my $dest = shift;
  my $fh = IO::File->new($dest, O_WRONLY|O_APPEND|O_CREAT);
  if (!defined $fh) {
    print STDERR "Failed to open $dest for appending, exiting.";
    exit(-1);
  }
  $fh->autoflush(1);
  return $fh;
}

my $outfh;
sub sighup_handler {
   undef $outfh;
   $outfh = open_dest($dest);
}

sub daemonize {
  fork and exit;
  POSIX::setsid();
  fork and exit;
  umask 0;
  chdir '/';
  open  STDIN, '<', '/dev/null';
  open STDOUT, '>', '/dev/null';
  open STDERR ,'>', '/dev/null';
}


my $help = '';
GetOptions("source|s=s" => \$source,
           "output|o=s" => \$dest,
           "daemonize|d!" => \$daemonize,
           "help|h!" => \$help);

if($help) {
  usage();
  exit(-1);
}

my $subscriber = "csvwriter";

$SIG{HUP} = \&sighup_handler;
if($daemonize) {
  print STDERR "daemonizing";
  daemonize();
}


$outfh = open_dest($dest);

my $r = JLog::Reader->new($source);
# ensure that our subscriber is set, technically this only needs
# to be done once, but there are no consequences to re-doing it.
$r->add_subscriber($subscriber);
$r->open($subscriber);
$r->auto_checkpoint(1);
# iterate, checking the jlog for new entries.  If we fail to find any,
# we will pause a second before trying again, to prevent busy-waiting
while(1) {
  my $line = $r->read;
  if(!$line) {
    sleep(1);
  } else {
    # do stuff with line
    $outfh->print($line);
  }
}



