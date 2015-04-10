#!/usr/bin/env perl
##############################
# move_folders.pl
#
# move old data for a flowcell to date/time stamped folders (for running pipeline again with a b c etc fake lims flowcells)
# give it a flowcell id and a thing to append to end of file names, or it will use date/time stamp.
#
# 9/2013
# Madelaine Gogol
##########################

use strict;
use warnings;
use Getopt::Long;

my ($help,$flowcell,$append,$orig,$nextseq);
my @files = ("SampleSheet.csv","config.txt","flowcell_info.yaml","Unaligned","Aligned","Sample_Report.csv","qsub_db","lims_data.json");
my @nextseq_files = ("SampleSheet.csv","qsub_bcl2fastq2.sh","Unaligned","Aligned","Sample_Report.csv","qsub_db","lims_data.json");

my $result = GetOptions ("flowcell=s" => \$flowcell, #string
                       "append=s" =>\$append, #string
						  	"nextseq" =>\$nextseq, #string
					  			"help" => \$help); #string
usage() if $help;

sub usage
{
   print "usage: move_folders.pl [-h] -f FCID [-a append]\n";
	print "--nextseq - if it's a nextseq flowcell\n";
   print "\n";
   print "-f FCID - flowcell id of folder on /n/ngs/data to move files/folders within\n";
   print "\n";
   print "-a append - string to put on the end of the files that we move.\n";
   print "\n";
   print "-h Print this message\n";
   print "\n";
   exit;
}

#$flowcell = $ARGV[0];
#$append = $ARGV[1];

if($append)
{
}
else
{
	$append= `date +%Y-%m-%d_%R`;
	chomp($append);
}

if($flowcell)
{
	if($nextseq)
	{
		foreach my $file (@nextseq_files)
		{
			$orig = `ls -d /n/ngs/data/*$flowcell/$file`;
			chomp($orig);
			if($orig)
			{
				print "mv $orig $orig.$append\n";
			}
		}
	}
	else
	{
		foreach my $file (@files)
		{
			$orig = `ls -d /n/ngs/data/*$flowcell/$file`;
			chomp($orig);
			if($orig)
			{
				print "mv $orig $orig.$append\n";
			}
		}
	}
}
else
{
	usage();
}
