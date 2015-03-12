#!/usr/bin/env perl
# hacky sample report generator for nextseq
# given a flowcell id and bowtie2 err file?
# works for dual or single index, paired reads.

use JSON;
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
`find $base_dir/Unaligned/fastqc -name "fastqc_data.txt" | xargs grep "Sequence length" > $base_dir/sequence_length.txt`;
`find $base_dir/Unaligned/fastqc -name "fastqc_data.txt" | xargs grep "Total Sequences" > $base_dir/total_sequences.txt`;

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

#sample   processed   aligned_once   pct_aligned_once  failed   pct_failed  aligned_multi  pct_multi   total_aligned  pct_aligned
#L13371-ATTACTCG-TAAGATTA_S6_L002_R1 902693   620303   68.72 174653   19.35 107737   11.94 728040   80.65
#L13367-ATTACTCG-GCCTCTAT_S2_L003_R1 782794   472167   60.32 205900   26.30 104727   13.38 576894   73.70
#L13386-CGCTCATT-CTTCGCCT_S21_L002_R2   790132   406611   51.46 319322   40.41 64199 8.13  470810   59.59

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
	$sampleName = $decoded->{'samples'}[$i]->{'sampleName'};
	$laneID = $decoded->{'samples'}[$i]->{'laneID'};
	$indexSequences0 = $decoded->{'samples'}[$i]->{'indexSequences'}[0];
	$indexSequences1 = $decoded->{'samples'}[$i]->{'indexSequences'}[1];
	$libID = $decoded->{'samples'}[$i]->{'libID'};
	$prnOrderNo = $decoded->{'samples'}[$i]->{'prnOrderNo'};
	$genomeVersion = $decoded->{'samples'}[$i]->{'genomeVersion'};
	$reqLabName = $decoded->{'samples'}[$i]->{'reqLabName'};
	$resultsPath = $decoded->{'samples'}[$i]->{'resultsPath'};

	print "lane:$laneID\nisControl:$isControl\nindex:$indexSequences0\nindex:$indexSequences1\n";

	#print Dumper $decoded->{'samples'}[$i];

	for(my $j; $j <= $#bamfiles; $j++)
	{
		$current_bamfile = basename($bamfiles[$j]);
		print "current_bamfile:$current_bamfile\n";
		#print "$bamfiles[$j] $laneID $indexSequences0 $indexSequences1\n";
		$modname = basename($bamfiles[$j]);
		$modname1 = basename($bamfiles[$j]);
		$modname1 =~ s/.bam/.fastq.gz/g;
		$modname =~ s/.bam//g;
		print "modname:$modname modname1:$modname1\n";


		if($modname =~ /n_\d_1_/)
		{
			$read = 1;
		}
		else
		{
			$read = 2;
		}

		if($isControl == 1)
		{
			if($current_bamfile =~ /^n_$laneID_.*bam$/)
			{
				print REPORT "$modname1,$prnOrderNo,$orderType,$laneID,$sampleName,$libID,$indexSequences0,$indexSequences1,$read,$genomeVersion,$reqLabName,$bwt_err{$modname}{'total_sequences'},$bwt_err{$modname}{'total_sequences'},100.00,$bwt_err{$modname}{'align_percent'},paired,$bwt_err{$modname}{'sequence_length'}\n";
			}
		}
		elsif($current_bamfile =~ /^n_$laneID_.*bam$/ and ($current_bamfile =~ /.*$indexSequences0-$indexSequences1.*/ or $current_bamfile =~ /.*$indexSequences0.*/))
		{
			print REPORT "$modname1,$prnOrderNo,$orderType,$laneID,$sampleName,$libID,$indexSequences0,$indexSequences1,$read,$genomeVersion,$reqLabName,$bwt_err{$modname}{'total_sequences'},$bwt_err{$modname}{'total_sequences'},100.00,$bwt_err{$modname}{'align_percent'},paired,$bwt_err{$modname}{'sequence_length'}\n";
		}
	}
}
#print "mkdir -p $resultsPath\n";
#print "cp Sample_Report.csv $resultsPath\n";
#print "cp Unaligned/*fastq.gz $resultsPath\n";
#print "cp -r Unaligned/fastqc $resultsPath\n";
#print "mail -s $flowcell.nextseq.postrun.done mcm\@stowers.org </dev/null\n";
