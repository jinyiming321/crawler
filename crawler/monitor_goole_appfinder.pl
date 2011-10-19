##monitor AMMS process, this script is in crontab every 10 minutes
use strict;
use AMMS::Config;

my $start=$ARGV[0];
my $end=$ARGV[1];
my $config=$ARGV[2];

die "usage: perl google_app_finder.pl start end config_file\n" if @ARGV <2;
# quit script if google app finder is already running
my $cmd="pid=`ps axu |grep google_word|grep -v grep |awk '{print \$2}'`; kill \$pid";
system($cmd);

my $conf = new AMMS::Config($config);
my $bin_dir=$conf->getAttribute("BaseBinDir");


while(1){
    &run_one_time;
    sleep(1*60*60);
}

sub run_one_time{
    my $num=$start;
    while( "$num" le  "$end" ){
        my $word_file="google_word$num";
        my $resp=`ps ax | grep "$word_file" | grep -v grep |wc -l`;
        
        ++$num;
        $resp=~s/[\r\n]/_n_n/g;
        if($resp=~/(\d+)/)
        {
            print "$word_file is still running\n" and next if($1>0);
        }

##start this script
        $cmd="perl $bin_dir/google_app_finder.pl $bin_dir/wordlist/$word_file &";
        warn "start $cmd";
        system($cmd);
    }
}

