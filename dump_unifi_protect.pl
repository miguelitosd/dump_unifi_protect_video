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
);

$outdir="." if (!defined($outdir));

unless (-r $indir) {
    die "ERROR: Cannot read from dir=$indir  $!\n";
}

unless (-w $outdir) {
    die "ERROR: Cannot write to dir=$outdir  $!\n";
}

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

find (
        {
                no_chdir => 1,
                wanted   => \&parseFile,
        },
        $indir,
);

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

print "
Source ubv files processed:     $totUbv
Destination mp4 files created:  $totMp4
Time:                           $tookTime seconds
";

# End body

sub run_cmd {
    my @cmd = @_;

    debug("run_cmd: @cmd");
    my ($stdin, $stdout, $stderr, $exit_code);
    my $run = run3( @cmd, \$stdin, \$stdout, \$stderr);

}

sub renameFile {
    my $src = $File::Find::name;
    return unless ($src =~ /.*\.mp4$/);

    $src =~ s/\.\///g;
    my $dst = $src;

#/mnt/ubnt-protect-out/video/2021/06/01/FCECDA8FAD1D/2022-01-31T13.57.29-08.00.mp4
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

sub parseFile {
    my $filename = $File::Find::name;

    return unless ($filename =~ /.*\/video\/.*\.ubv$/);
    return if ($filename =~ /_timelapse_/);
    $infiles->{$filename} = 1;
}

sub verbose {
    return unless $verbose;
    say $_[0];
}

sub debug {
    return unless $debug;
    say $_[0];
}
