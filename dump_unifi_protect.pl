#!/usr/bin/perl

use warnings;
use strict;

use 5.018;
use Cwd;
use Data::Dumper;
use File::Basename qw( dirname );
use File::Find;
use File::Path qw (make_path remove_tree);
use Getopt::Long;
use JSON;
my $options;
my $cameras;
my $indir;
my $outdir;
my $infiles;

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
#/mnt/ubnt-protect-in/unifi-os/unifi-protect/video/2022/01/13/E063DA3FEC8C_0_rotating_1642077111078.ubv
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
    mkdir("./tmp",775) or die "Failure to do mkdir(./tmp,775) $!\n";
    chdir("tmp");
    run_cmd("remux -with-audio $vfile");
    find (
            {
                no_chdir    => 1,
                wanted      => \&renameFile,
            },
            '.',
        );
}

sub run_cmd {
    my $cmd = @_;
    print $cmd;
}

sub renameFile {
    my $src = $File::Find::name;
    return unless ($src =~ /.*\.mp4$/);

    print $src . "\n";
}

sub parseFile {
    my $filename = $File::Find::name;

    return unless ($filename =~ /.*\/video\/.*\.ubv$/);
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
