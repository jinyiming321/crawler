#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use Encode;
use FileHandle;
use Carp;
use Test::More 'no_plan';
use lib '/root/crawler';
use DBI;
use Getopt::Long;

my $temp_html_dir = '/root/crawler/html/';

=pod
  use Getopt::Long;
  my $data   = "file.dat";
  my $length = 24;
  my $verbose;
  $result = GetOptions ("length=i" => \$length,    # numeric
                        "file=s"   => \$data,      # string
                        "verbose"  => \$verbose);  # flag
=cut

my ( $task_type,$config );
my $ret = GetOptions( 
    'task_type=s' => \$task_type,
    'config=s'    => \$config,
) ;
# $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
my $dsn  = 'DBI:mysql:database=amms;host=192.168.154.1;port=3306';
my $user = 'root';
my $pass = 'root';
my $feeder_url_match = '';
my $page_url_match='';
my $app_url_match='';
my $dbh = DBI->connect( $dsn,$user,$pass ) or die $DBI::errstr;

my $task_info = {};

get_task_info();
if( $task_type eq 'find_app' ){
    run_find_app();
}
if( $task_type eq 'new_app' ){
    run_new_app();
}


sub get_task_info{
    # http://anfone.com/sort/2.html
    my $sql =<<EOF;
    SELECT  DISTINCT a.task_id
    FROM 
    task a,
    task_detail b
    WHERE
    b.detail_info LIKE '%coolapk%' 
    AND a.task_type='$task_type';
EOF
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    while( my $ret = $sth->fetchrow_hashref ){
#        if( $ret->{detail_info} =~ m{anfone.com/sort/\d+\.html} ){
        if( $ret->{task_id} =~ m{\d+} ){
            $task_info->{$task_type}{ $ret->{task_id} } = 1;
        }
    }

}

sub run_find_app{
    my @task_id_list = keys %{ $task_info->{find_app} };
    for(@task_id_list){
        my $cmd = <<CMD;
        perl /root/crawler/coolapk.pl find_app $_ /root/crawler/default.cfg
CMD
#        my $ret = system($cmd);
        `$cmd`;
        my $status = $?;
         print $cmd;
        is($status,0,"run '$cmd' test");
    }

    my $sql =<<EOF;
    select count(*) from app_source where market_id = 14
EOF
    my $count = $dbh->selectrow_array($sql);
    print "-------------------------------------\n";
    print "total collect $count app\n";
}

sub run_new_app{
    my @task_id_list = keys %{ $task_info->{new_app} };
    for( my $i = 0;$i<=30;$i++){
        my $cmd = <<CMD;
        perl /root/crawler/coolapk.pl new_app $task_id_list[$i] /root/crawler/default.cfg
CMD
        print $cmd."\n";
        #sleep 5;
        `$cmd`;
        is($?,0,"run '$cmd' test");
    }
}
