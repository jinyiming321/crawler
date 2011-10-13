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
my $task_num;

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
my $pl;
my $ret = GetOptions( 
    'task_type=s' => \$task_type,
    'config=s'    => \$config,
    'task_num=s'    => \$task_num,
    'pl=s'          => \$pl
) ;
#my$dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
#my $dsn  = 'DBI:mysql:database=amms;host=192.168.154.1;port=3306';
my $dsn  = 'DBI:mysql:database=AMMS;host=localhost;port=3306';
my $user = 'root';
my $pass = 'root';
my $feeder_url_match = '';
my $page_url_match='';
my $app_url_match='';
my $dbh = DBI->connect( $dsn,$user,$pass ) or die $DBI::errstr;

my $task_info = {};

if( $task_type eq 'fix_app' ){
    my $sql =<<EOF;
    select distinct b.task_id from app_source a ,task_detail b where
        a.app_url=b.detail_info and a.status in ('fail','doing')
EOF
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    while(my $row = $sth->fetchrow_hashref ){
        $task_info->{'new_app'}->{$row->{task_id}} = 1;
    }
    run_new_app();
}else{
    get_task_info();
}
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
    b.detail_info LIKE '%opera%' 
    AND a.task_type='$task_type'
    and a.status not like '%done%';
EOF
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    while( my $ret = $sth->fetchrow_hashref ){
            $task_info->{$task_type}{ $ret->{task_id} } = 1;
    }
}

sub run_find_app{
    my @task_id_list = keys %{ $task_info->{find_app} };
    for(@task_id_list){
        my $cmd = <<CMD;
        perl /root/crawler/$pl find_app $_ /root/crawler/default.cfg
CMD
#        my $ret = system($cmd);
        `$cmd`;
        my $status = $?;
         print $cmd;
        is($status,0,"run '$cmd' test");
    }

    my $sql =<<EOF;
    select count(*) from app_source where market_id = 20
EOF
    my $count = $dbh->selectrow_array($sql);
    print "-------------------------------------\n";
    print "total collect $count app\n";
}

sub run_new_app{
    my @task_id_list = keys %{ $task_info->{new_app} };
    map{
        my $cmd =<<CMD;
        perl /root/crawler/$pl new_app $_ /root/crawler/default.cfg
CMD
    print "run cmd :$cmd\n";
    `$cmd`;
    is($?,0,"run '$cmd' test");
    } @task_id_list;
}
