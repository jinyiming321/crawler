#!/usr/bin/perl 
#===============================================================================
#
#         FILE: killer.pl
#
#        USAGE: ./killer.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: JamesKing (www.perlwiki.info), jinyiming456@gmail.com
#      COMPANY: China
#      VERSION: 1.0
#      CREATED: 2011年10月14日 00时14分01秒
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use Data::Dumper;

my @pids = `ps -ef|grep perl|grep -v grep|grep -v vi|awk '{ print \$2}'`;
foreach my $pid(@pids){
    $pid=~ s/^\s+$//g;
    print "kill -9 $pid\n";
    `kill -9 $pid`;
}


