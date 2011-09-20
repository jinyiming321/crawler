#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use Encode;
use FileHandle;
use Carp;
use Test::More 'no_plan';
use lib '/root/crawler'
use DBI;
use 

my $temp_html_dir = '/root/crawler/html';

=pod
  use Getopt::Long;
  my $data   = "file.dat";
  my $length = 24;
  my $verbose;
  $result = GetOptions ("length=i" => \$length,    # numeric
                        "file=s"   => \$data,      # string
                        "verbose"  => \$verbose);  # flag
=cut

my ( $task_type,$config ) = shift;
my $ret = GetOptions( 
    'task_type=s' => \$task_type,
    'config=s'    => \$config,
) or die $@;

my $dsn  = '';
my $user = '';
my $pass = '';
my $dbh = DBI->connect( $dsn,$user,$pass ) or die $@;

sub check_extra_page_list{
    my $sql =<<EOF;
    select 
EOF
    
}

sub get_content{

}

