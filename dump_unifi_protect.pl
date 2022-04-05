#!/usr/bin/perl

use warnings;
use strict;

use 5.018;
use Cwd;
use Data::Dumper;
use File::Basename qw( dirname );
use File::Copy;
use File::Find;
use File::Path qw (make_path remove_tree);
use Getopt::Long;
use IPC::Run3;
use JSON;

my $options;
my $cameras;
my $indir;
my $outdir;
my $infiles;
my $totUbv = 0;
my $totMp4 = 0;

$| = 1;

my $startTime = time();
umask 022;

GetOptions(
    'verbose'       => \my $verbose,
    'debug'         => \my $debug,
    'cameras=s'     => \my $cjson,
    'input=s'       => \$indir,
    'output=s'      => \$outdir,
    'help'          => sub { &help; },
);

$outdir="." if (!defined($outdir));

# Output message and exit 1 if the input and output dirs weren't set
if ((!defined($indir)) or (!defined($outdir))) {
    print "ERROR: the --input and --output args (and path for each) are required\n";
    &help;
    exit 1;
}

# Error out if we can't read from the input dir
unless (-r $indir) {
    die "ERROR: Cannot read from dir=$indir  $!\n";
}

# Error out if we can't write to the output dir
unless (-w $outdir) {
    die "ERROR: Cannot write to dir=$outdir  $!\n";
}

# If we were passed a cameras.json file, parse said info and get the camera names.
#  Store them in a hashref so the mac address (which is used in the filenames) is an easy
#  lookup to return the configured name
if ( (defined($cjson)) and (-r $cjson)) {
    debug("Loading camera names from $cjson");
    my $jtxt;
    open my $jin, '<', $cjson or die "Failure while trying to read file=$cjson: $!\n";
    while (defined(my $line = readline $jin)) {
        $jtxt .= $line;
    }
    close $jin;
    my $json = decode_json($jtxt);
    while (my $d = pop @$json) {
        if ((defined($d->{'name'})) and (defined($d->{'mac'}))) {
            $cameras->{$d->{'mac'}} = $d->{'name'};
        }
    }
}

# use File::Find to walk the input directory and call the parseFile subroutine per file
find (
        {
                no_chdir => 1,
                wanted   => \&parseFile,
        },
        $indir,
);

# Walk the hashref we built off parseFile and do work on files
#  The basic logic is:
#  * Pull out just the file name
#  * Build the name of the output path as the $output path + /video/ + year/ + month/ + day/ + Camera name
#    (use mac address from input file if we didn't get a cameras.json or there isn't a matching mac address)
#  * If the output path we just got doesn't exist, do a math_path (mkdir -p)
#  * chdir into the output path
#  * Create a subdir tmp, chdir into there
#  * Run the remux command against the source file
#  * Do a new find in the tmp dir (remux can result in multiple files) and for each file, rename from the long name to just the time
#  * chdir out of the tmp subdir and remove_tree('/tmp') (rm -rf tmp);
foreach my $vfile (sort keys %$infiles) {
    my $name = $vfile;
    $name =~ s/.*\/video\//\/video\//;
    my $outputDir = "${outdir}$name";
    $outputDir = dirname($outputDir);
    my $cwd = cwd;
    if ( ! -d $outputDir ) {
        debug("make_path($outputDir,{chmod => 0775})");
        make_path($outputDir, { chmod => 0775}) or die "Failure to do make_path($outputDir,{chmod=>0775}) $!\n";
    }
    chdir($outputDir);
    # Use a tmp subdir for remux output so we can do another file for renames to camera names
    if ( ! -d 'tmp' ) { mkdir('tmp',0775) or die "Failure to do mkdir(./tmp,775) $!\n"; }
    chdir('tmp');
    $totUbv++;
    run_cmd("remux -with-audio $vfile");

    find (
            {
                no_chdir    => 1,
                wanted      => \&renameFile,
            },
            '.',
        );
    chdir($outputDir);
    remove_tree('tmp');
}

my $endTime = time();
my $tookTime = $endTime - $startTime;

# Output simple stats of how many input (ubv) files, how many output (mp4) files, and how long the run took
print "
Source ubv files processed:     $totUbv
Destination mp4 files created:  $totMp4
Time:                           $tookTime seconds
";

# End body

# I like to use IPC::Run3 and wrap my commands in a simple sub
sub run_cmd {
    my @cmd = @_;

    debug("run_cmd: @cmd");
    my ($stdin, $stdout, $stderr, $exit_code);
    my $run = run3( @cmd, \$stdin, \$stdout, \$stderr);

}

# sub called by the 2nd find to figure out what final name the file should have
#  * Only process *.mp4 files
#  * Pull the first 12 characters (the mac address) of the filename
#  * Pull out the year/month/day info from the filename
#  * Get the string of the output directory to move the file to
#  * If we have the camera name from the cameras.json file, use that name in the directory, else stick to the mac address
#  * If that output directory isn't there yet, create it
#  * strip down the filename to just the timestamp
#  * Move the file to the destination subdir
#  Example output from debug move call:
#  Move FCECDA8FAD1D_0_rotating_2022-01-31T13.57.29-08.00.mp4, /mnt/ubnt-protect-out/video/2022/01/31/UVC G3 AD1D - Kitchen/13.57.29-08.00.mp4
sub renameFile {
    my $src = $File::Find::name;
    return unless ($src =~ /.*\.mp4$/);

    $src =~ s/\.\///g;
    my $dst = $src;
    my $mac = substr($src,0,12);
    (my $year, my $month, my $day) = ($src =~ /_(\d\d\d\d)-(\d\d)-(\d\d)T/);
    my $ddir = "${outdir}/video/${year}/${month}/${day}/${mac}";
    if (defined($cameras->{$mac})) {
        $ddir = "${outdir}/video/${year}/${month}/${day}/$cameras->{$mac}";
    }
    if ( ! -d $ddir ) {
        debug("make_path($ddir,{chmod => 0775})");
        make_path($ddir, { chmod => 0775}) or die "Failure to do make_path($ddir,{chmod=>0775}) $!\n";
    }
    $dst =~ s/.*\d\d\d\d-\d\d-\d\dT//g;
    $totMp4++;
    my $fullDst = $ddir . "/" . $dst;
    debug("Move $src, $fullDst");
    move($src,$fullDst) or die "ERROR: $!\n";;
}

# Called by the first find, only save ubv files that are under a /videos/ subdir and ignore those with
#   _timelapse_ in the filename.  Save list of files to a hashref we're going to use later.
sub parseFile {
    my $filename = $File::Find::name;

    return unless ($filename =~ /.*\/video\/.*\.ubv$/);
    return if ($filename =~ /_timelapse_/);
    $infiles->{$filename} = 1;
}

# Called to print verbose output when set
sub verbose {
    return unless $verbose;
    say $_[0];
}

# Called to print debug output when set
sub debug {
    return unless $debug;
    say $_[0];
}

sub help {
    print "HELP: $0 [OPTIONS] --input <Path to mount with ubv files> --output <Path to write out mp4 files>
OPTIONS:
--help      : Print this help message
--verbose   : Output helpful verbose messages
--debug     : Output far more messages for debugging
--cameras   : Optional filename of the cameras.json file from a protect backup
--input     : <REQUIRED> The root path to run the find down to find *.ubv files, must have read access
--output    : <REQUIRED> The path to create the mp4 output files, it will build a directory structure of
                \${output_path}/video/\${year}/\${month}/\${day}/\${camera_name}/\$TIMESTAMP.mp4
";
}
