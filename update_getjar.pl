#!/usr/bin/perl 
#===============================================================================
#
#         FILE: update_getjar.pl
#
#        USAGE: ./update_getjar.pl  
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
#      CREATED: 2011年11月04日 12时19分29秒
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use DBI;
use AMMS::Util;

# DBI:mysql:database=$database;host=$hostname;port=$port
my $dsn = "DBI:mysql:database=AMMS;host=localhost;port=3306";
my $user = "root";
my $pass = "root";
my $dbh = DBI->connect(
        $dsn,
        $user,
        $pass,
        );

sub update_rating_times{
    my $app_url_md5= shift;
    my $app_dir = '';
    my $apk_file = '';
    if( -e $apk_file ){
    }

};
        




