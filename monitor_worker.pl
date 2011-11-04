#!/usr/bin/perl 
use strict;
use warnings;
use Data::Dumper;
use FindBin qw($Bin);
use lib $Bin;

use AMMS::SimpleConfig;
use AMMS::DBHelper;
use AMMS::Util;

die "\nplease check config parameter\n" unless init_gloabl_variable;

my $config  = AMMS::SimpleConfig->load("$Bin/monitor.conf");
print Dumper($config);
my $dbh     = $db_helper->get_db_handle;
my $basedir = $conf->getAttribute('BaseBinDir');

while ( my ( $market_name, $script ) = each %$config ) {
    my $market_id = &get_market_id($market_name);
	die "can't get market_id" unless $market_id;
    print &check_market_demo( $market_name, $script );
    my $task_ref = &get_doing_task($market_id);
    my $recv     = `ps aux|grep $script|grep -v grep`;
    my @workers = $recv =~ /$script\s+((?:find_app|new_app|update_app)\s+\d+)/g;
    foreach my $task (@$task_ref) {
        my ($has_task) = grep { /$task->{task_id}/ } @workers;
        if ( not $has_task ) {
            $dbh->do( "update task set status='undo' where task_id=?",
                undef, $task->{task_id} )
              or die $dbh->errstr;
          SWITCH: {
                $task->{task_type} eq "find_app"
                  && do { &rollback_find_app( $task->{task_id} ); last SWITCH; };
                $task->{task_type} eq "new_app"
                  && do { &rollback_new_app( $task->{task_id} ); last SWITCH; };
                $task->{task_type} eq "update_app"
                  && do { &rollback_update_app( $task->{task_id} ); last SWITCH; };
            }
        }
    }
}
exit(0);

sub get_market_id {
    my $market_name = shift;
    my $row =
      $dbh->selectrow_hashref( "select id from market where name=? limit 1",
        undef, $market_name );
    if ($row) {
        return $row->{id};
    }
    return undef;
}

sub check_market_demo {
    my $market_name = shift;
    my $script      = shift;
    my $recv        = `ps aux|grep $market_name |grep -v grep`;
    print $recv;
    if ( $recv !~ /task_generator\.pl/ ) {
		print $basedir. "/task_generator.pl $market_name","\n";
        system(  "perl $basedir/task_generator.pl $market_name &" );
    }
    foreach my $task_type (qw/find_app new_app update_app/) {
        system(
"perl $basedir/daemon.pl -t $task_type -c $basedir/default.cfg -m $market_name -p $script &"
        ) unless $recv =~ /$task_type/;
    }
}

sub rollback_update_app {
    my $task_id = shift;
    my $result  = &get_task_detail($task_id);
    foreach my $row (@$result) {
        $dbh->do( "update app_info where status='fail' where app_url_md5=?",
            undef, $row->{detail_id} )
          or die $dbh->errstr;
    }

}

sub get_task_detail {
    my $task_id = shift;
    my $sth = $dbh->prepare("select detail_id from task_detail where task_id=?")
      or die $dbh->errstr;
    $sth->execute($task_id) or die $sth->errstr;
    my @results;
    while ( my $row = $sth->fetchrow_hashref ) {
        push @results, \%$row;
    }
    return \@results;
}

sub rollback_new_app {
    my $task_id = shift;
    my $result  = &get_task_detail($task_id);
    foreach my $row (@$result) {
        $dbh->do( "update app_source set status='undo' where app_url_md5=?",
            undef, $row->{detail_id} )
          or die $dbh->errstr;
    }
}

sub rollback_find_app {
    my $task_id    = shift;
    my $feeder_ids = &get_task_detail($task_id);
    foreach my $row (@$feeder_ids) {
        $dbh->do( "update feeder set status='fail' where feeder_id=?",
            undef, $row->{detail_id} )
          or die $dbh->errstr;
    }
}

sub get_doing_task {
    my $market_id = shift;
    my $sql       = "select * from task where market_id=? and status='doing'";
    my $sth       = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute($market_id) or die $sth->errstr;
    my @result;
    while ( my $row = $sth->fetchrow_hashref ) {
        push @result, \%$row;
    }
    return \@result;
}
