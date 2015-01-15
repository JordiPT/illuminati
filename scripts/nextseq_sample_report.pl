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
					  			"help" => \$help); #string
usage() if $help;

#maybe add this to get read length? put in a file and parse?
#find Unaligned/fastqc -name "fastqc_data.txt" | xargs grep "Sequence length"

sub usage
{
   print "usage: nextseq_sample_report.pl [-h] -f FCID [-b bowtie2_err -d bamfile_dir]\n";
   print "\n";
   print "-f FCID - flowcell id to generate report for\n";
   print "\n";
   print "-b bowtie2 err dir - dir with bowtie2 std error files. If no alignment, enter none\n";
   print "\n";
   print "-d directory with bam files\n";
   print "\n";
   print "-h Print this message\n";
   print "\n";
   exit;
}

@fastqfiles = glob("Unaligned/*.fastq.gz");
@bamfiles = glob("$bamfile_dir/*.bam");

my %bwt_err = ();
if($bowtie2_err and $bowtie2_err ne "none")
{
	print "running parse_bowtie2_err.pl $bowtie2_err > bowtie2_err.txt\n";
	system("parse_bowtie2_err.pl $bowtie2_err > bowtie2_err.txt");

	open(bwt,"bowtie2_err.txt") or die $!;

	while(<bwt>)
	{
		chomp;
	#sample	processed	aligned_once	pct_aligned_once	failed	pct_failed	aligned_multi	pct_multi	total_aligned	singletons	pct_singletons	singletons_aligned_once	singletons_aligned_multi	pct_aligned
		($file,$processed,$aligned_once,$pct_aligned_once,$failed,$pct_failed,$aligned_multi,$pct_aligned_multi,$total_aligned,$pct_aligned) = split("\t",$_);
		if($file ne "sample")
		{
			$bwt_err{$file}{'total_reads'} = $processed;
			$bwt_err{$file}{'align_percent'} = $pct_aligned;
			#print "inserting into hash $file $processed $pct_aligned\n";
		}
	}
}
elsif($bowtie2_err eq "none")
{
	foreach my $file (@fastqfiles)
	{
		$modname = basename($file);
		$modname =~ s/_001.fastq.gz/.bam/g;
		$bwt_err{$modname}{'total_reads'} = "";
		$bwt_err{$modname}{'align_percent'} = "";
		push(@bamfiles,$modname);
		#print "inserting into hash $modname $processed $pct_aligned\n";
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


open(REPORT, ">Sample_Report.csv") or die "Can't open $file $!";
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

	#print "lane:$laneID\nisControl:$isControl\nindex:$indexSequences0\nindex:$indexSequences1\n";

	#print Dumper $decoded->{'samples'}[$i]; 

	#L13371-ATTACTCG-TAAGATTA_S6_L003_R1.bam
	for(my $j; $j <= $#bamfiles; $j++)
	{
		#print "$bamfiles[$j] $laneID $indexSequences0 $indexSequences1\n";
		$modname = basename($bamfiles[$j]);
		$modname1 = basename($bamfiles[$j]);
		$modname1 =~ s/.bam/_001.fastq.gz/g;
		$modname =~ s/.bam//g;

		if($modname =~ /_R1/)
		{
			$read = 1;
		}
		else
		{
			$read = 2;
		}

		if($isControl == 1)
		{
			if($bamfiles[$j] =~ /.*L00$laneID\.bam$/)
			{
				print REPORT "$modname1,$prnOrderNo,$orderType,$laneID,$sampleName,$libID,$indexSequences0,$indexSequences1,$read,$genomeVersion,$reqLabName,$bwt_err{$modname}{'total_reads'},$bwt_err{$modname}{'total_reads'},100.00,$bwt_err{$modname}{'align_percent'},paired,\n";
			}
		}
		elsif($bamfiles[$j] =~ /.*L00$laneID.*\.bam$/ and ($bamfiles[$j] =~ /.*$indexSequences0-$indexSequences1.*/ or $bamfiles[$j] =~ /.*$indexSequences0.*/))
		{
			print REPORT "$modname1,$prnOrderNo,$orderType,$laneID,$sampleName,$libID,$indexSequences0,$indexSequences1,$read,$genomeVersion,$reqLabName,$bwt_err{$modname}{'total_reads'},$bwt_err{$modname}{'total_reads'},100.00,$bwt_err{$modname}{'align_percent'},paired,\n";
		}
	}
}
print "mkdir -p $resultsPath\n";
print "cp Sample_Report.csv $resultsPath\n";
print "cp Unaligned/*fastq.gz $resultsPath\n";
print "cp -r Unaligned/fastqc $resultsPath\n";
print "mail -s $flowcell.nextseq.postrun.done mcm\@stowers.org </dev/null\n";
