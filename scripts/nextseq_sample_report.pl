#!/usr/bin/env perl
# hacky sample report generator for nextseq
# given a flowcell id and bowtie2 err file?
# works for dual or single index, paired reads.

use JSON;
use Sort::Naturally;
use Data::Dumper;
use Getopt::Long;
use File::Basename;

my $bowtie2_err = "Aligned/bowtie2";
my $bamfile_dir = "Aligned/bowtie2";
my $result = GetOptions ("flowcell=s" => \$flowcell, #string
                       "bowtie2_err=s" =>\$bowtie2_err, #string
                       "dir_bamfiles=s" =>\$bamfile_dir, #string
                       "work_dir=s" => \$base_dir,
					  			"help" => \$help); #string
usage() if $help;

sub usage
{
   print "usage: nextseq_sample_report.pl [-h] -f FCID [-b bowtie2_err -d bamfile_dir -w work_dir]\n";
   print "\n";
   print "-f FCID - flowcell id to generate report for\n";
   print "\n";
   print "-b bowtie2 err dir - dir with bowtie2 std error files. If no alignment, enter none\n";
   print "\n";
   print "-d directory with bam files\n";
   print "\n";
   print "-w working flowcell base directory";
   print "\n";
   print "-h Print this message\n";
   print "\n";
   exit;
}
print $base_dir;
my %bwt_err = ();


#ugly hack to get sequence length and number of sequences - mainly for when there's no bowtie results.
`find $base_dir/Unaligned/all/fastqc -name "fastqc_data.txt" | xargs grep "Sequence length" > $base_dir/sequence_length.txt`;
`find $base_dir/Unaligned/all/fastqc -name "fastqc_data.txt" | xargs grep "Total Sequences" > $base_dir/total_sequences.txt`;

open(seqlength,"$base_dir/sequence_length.txt") or die $!;
while(<seqlength>)
{
	chomp;
	($firstpart,$seqlengthpart) = split(":",$_);
	($dirname,@junk) = split("_fastqc",$firstpart);
	$dirname =~ s/^.*\///g;
	$seqlength = $seqlengthpart;
	$seqlength =~ s/^Sequence\slength\s//g;
	$seqlength =~ s/\t+//g;
	$bwt_err{$dirname}{"sequence_length"} = $seqlength;
}

open(totalseq,"$base_dir/total_sequences.txt") or die $!;
while(<totalseq>)
{
	chomp;
	($firstpart,$totalseqpart) = split(":",$_);
	($dirname,@junk) = split("_fastqc",$firstpart);
	$dirname =~ s/^.*\///g;
	$total_sequences = $totalseqpart;
	$total_sequences =~ s/^Total\sSequences\s//g;
	$total_sequences =~ s/\t+//g;
	print "adding to hash :$dirname: :$total_sequences:\n";
	$bwt_err{$dirname}{"total_sequences"} = $total_sequences;
}

@fastqfiles = glob("$base_dir/Unaligned/*.fastq.gz");
@bamfiles = glob("$bamfile_dir/*.bam");



if($bowtie2_err and $bowtie2_err ne "none")
{
	print "running parse_bowtie2_err.pl $bowtie2_err > $base_dir/bowtie2_err.txt\n";
	system("parse_bowtie2_err.pl $bowtie2_err > $base_dir/bowtie2_err.txt");

	open(bwt,"$base_dir/bowtie2_err.txt") or die $!;

	while(<bwt>)
	{
		chomp;
	#sample	processed	aligned_once	pct_aligned_once	failed	pct_failed	aligned_multi	pct_multi	total_aligned	singletons	pct_singletons	singletons_aligned_once	singletons_aligned_multi	pct_aligned
		($file,$processed,$aligned_once,$pct_aligned_once,$failed,$pct_failed,$aligned_multi,$pct_aligned_multi,$total_aligned,$pct_aligned) = split("\t",$_);
		if($file ne "sample")
		{
			$bwt_err{$file}{'total_reads'} = $processed;
			$bwt_err{$file}{'align_percent'} = $pct_aligned;
			print "inserting into hash $file $processed $pct_aligned\n";
		}
	}
}
elsif($bowtie2_err eq "none")
{
	foreach my $file (@fastqfiles)
	{
		$modname = basename($file);
		$modname =~ s/.fastq.gz/.bam/g;
		$bwt_err{$modname}{'total_reads'} = "";
		$bwt_err{$modname}{'align_percent'} = "";
		push(@bamfiles,$modname);
		print "inserting into hash $modname $processed $pct_aligned\n";
	}
}
else
{
	print "Unknown bowtie dir $bowtie2_err\n";
}

open(REPORT, ">$base_dir/Sample_Report.csv") or die "Can't open $file $!";
print "flowcell:$flowcell\n";
my $result = `perl /n/ngs/tools/lims/lims_data.pl $flowcell`;
my $decoded = decode_json($result);
@t = @{$decoded->{'samples'}};


print REPORT "output,order,order type,lane,sample name,library id,illumina index,custom barcode,read,reference,lab,total reads,pass filter reads,pass filter percent,align percent,type,read length\n";

for(my $i = 0; $i <= $#t; $i++)
{
	#print "i:$i\n";
	$isControl = $decoded->{'samples'}[$i]->{'isControl'};
	$orderType = $decoded->{'samples'}[$i]->{'orderType'};
	$readType = $decoded->{'samples'}[$i]->{'readType'};
	$readLength = $decoded->{'samples'}[$i]->{'readLength'};
	$sampleName = $decoded->{'samples'}[$i]->{'sampleName'};
	$indexSequences0 = $decoded->{'samples'}[$i]->{'indexSequences'}[0];
	$indexSequences1 = $decoded->{'samples'}[$i]->{'indexSequences'}[1];
	$libID = $decoded->{'samples'}[$i]->{'libID'};
	$prnOrderNo = $decoded->{'samples'}[$i]->{'prnOrderNo'};
	$laneID = $decoded->{'samples'}[$i]->{'laneID'};
	$genomeVersion = $decoded->{'samples'}[$i]->{'genomeVersion'};
	$reqLabName = $decoded->{'samples'}[$i]->{'reqLabName'};
	$resultsPath = $decoded->{'samples'}[$i]->{'resultsPath'};

	$readLength =~ s/bp$//g;
	$readLength =~ s/.*-//g;
	$readLength = $readLength+1;
	
	if($laneID == 1)
	{
		#for each thing in bwt err
		foreach my $k (sort {ncmp($a,$b)} keys(%bwt_err))
		{
			print "k:$k\n";
			if($k =~ /n_1_$indexSequences0/)
			{
				$read = 1;
			}
			elsif($k =~ /n_2_$indexSequences0/)
			{
				$read = 2;
			}

			if($k =~ /^n_\d_$indexSequences0-$indexSequences1/)
			{
				print REPORT "$k.fastq.gz,$prnOrderNo,$orderType,$laneID,$sampleName,$libID,$indexSequences0,$indexSequences1,$read,$genomeVersion,$reqLabName,$bwt_err{$k}{'total_sequences'},$bwt_err{$k}{'total_sequences'},100.00,$bwt_err{$k}{'align_percent'},paired,$readLength\n";
			}
			elsif($k =~ /^n_\d_$indexSequences0$/)
			{
				print REPORT "$k.fastq.gz,$prnOrderNo,$orderType,$laneID,$sampleName,$libID,$indexSequences0,$indexSequences1,$read,$genomeVersion,$reqLabName,$bwt_err{$k}{'total_sequences'},$bwt_err{$k}{'total_sequences'},100.00,$bwt_err{$k}{'align_percent'},paired,$readLength\n";
			}
		}
	}
}
