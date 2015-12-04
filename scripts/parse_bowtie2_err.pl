#!/usr/bin/env perl
###############################
# parse.pl 
#
# parses bowtie2 std err output
# 3/2012
# #############################

use File::Basename;
use Sort::Naturally;
use List::Util qw(sum);
use Math::Round;

@files = glob("$ARGV[0]/*.err");

%h = ();

foreach my $file (@files)
{
	open(CURRENT,$file);
	while(<CURRENT>)
	{
		chomp;
		$newname = basename($file);
		$newname =~ s/.err//g;
		$newname =~ s/^n_\d_/n_/g;

		$h{$newname}{bam_file} = $newname;
		if($_ =~ /(\d+) reads; of these:/)
		{
			$proc = $1;
			$h{$newname}{proc} = $proc;
		}
		elsif($_ =~ /^\s+(\d+) \(([\d\.]+)%\) aligned exactly 1 time/)
		{
			$aligned = $1;
			$h{$newname}{aligned} = $aligned;
			$pct = $2;
			$h{$newname}{pct_aligned} = $pct;
		}
		elsif($_ =~ /^\s+(\d+) \(([\d\.]+)%\) aligned 0 times/)
		{
			$failed = $1;
			$h{$newname}{failed} = $failed;
			$pct_failed = $2;
			$h{$newname}{pct_failed} = $pct_failed;
		}
		elsif($_ =~ /^\s+(\d+) \(([\d\.]+)%\) aligned >1 times/)
		{
			$multi = $1;
			$h{$newname}{multi} = $multi;
			$pct_multi = $2;
			$h{$newname}{pct_multi} = $pct_multi;
		}
		elsif($_ =~ /([\d\.]+)% overall alignment rate/)
		{
			$overall_pct = $1;
			#print "adding $overall_pct to $newname\n";
			push(@{$h{$newname}{pct_overall}},$overall_pct);
		}
		elsif($_ =~ /.*ERR.*/) #error in bowtie alignment
		{
			#print "ERR adding 0 to $newname\n";
			push(@{$h{$newname}{pct_overall}},0);
		}
	}
	$h{$newname}{total_aligned} = $h{$newname}{aligned}+$h{$newname}{multi};
}

print "sample\tprocessed\taligned_once\tpct_aligned_once\tfailed\tpct_failed\taligned_multi\tpct_multi\ttotal_aligned\tpct_aligned\n";
foreach my $f (sort {ncmp($a,$b)} keys %h)
{
	@temp = @{$h{$f}{pct_overall}};
	if(length(@temp) > 0)
	{
		$l = length(@temp);
		$mypct = mean(@{$h{$f}{pct_overall}});
	}
	else
	{
		#print "$f\t0 pct\n";
		$mypct=0;
	}
	print "$h{$f}{bam_file}\t$h{$f}{proc}\t$h{$f}{aligned}\t$h{$f}{pct_aligned}\t$h{$f}{failed}\t$h{$f}{pct_failed}\t$h{$f}{multi}\t$h{$f}{pct_multi}\t$h{$f}{total_aligned}\t$mypct\n";
}

sub mean {
	    return nearest(.01,sum(@_)/@_);
	 }
