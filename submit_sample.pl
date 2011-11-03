#download url
BEGIN{unshift(@INC, $1) if ($0=~m/(.+)\//); $| = 1; }

use strict; 
use Data::Dumper;				
use AMMS::Util;
					
my $market;
my $conf_file="./default.cfg" unless defined($ARGV[0]);

die "\nplease check config parameter\n" unless init_gloabl_variable( $conf_file );

my $sample_dir=$conf->getAttribute('SampleFolder');
my $dbh=$db_helper->get_db_handle;

my $analytic_dir="/mnt/tslab";
my $cloud_dir="/mnt/cloud";
my $bakup_dir="/mnt/bakup";

#submit the app to analyzer
while(1)
{
    #check db handler  
    while( not $db_helper->is_connected)
    {
        ##reconnect
        $db_helper->connect_db();
        sleep(5);
    }

    &clean_table_data();
    &run_one_time();

    sleep(600);			# check the task every 10 minutes
}

sub clean_table_data{
    my $sql = qq{
        SELECT distinct a.task_id FROM task a,task_detail b 
        WHERE a.task_id=b.task_id AND a.status='done'
        AND TIMESTAMPDIFF( DAY,DATE(a.done_time), CURDATE() ) >=20
        order by task_id
    };
    my $sth = $dbh->prepare($sql);
    $sth->execute;

    my $del_task_sql = qq{
        delete from task where task_id = ?
    };
    my $del_task_detail_sql = qq{
        delete from task_detail where task_id= ?
    };

    my $task_sth = $dbh->prepare($del_task_sql);
    my $task_detail_sth = $dbh->prepare($del_task_detail_sql);

    while( my $hashref = $sth->fetchrow_hashref() ){
        $task_sth->execute( $hashref->{task_id} ) or die $DBI::errstr;       
        $task_detail_sth->execute( $hashref->{task_id} ) or die $DBI::errstr;
    }
}
 

sub run_one_time
{
    my $sql="select package_name, task_id from package where (status='undo' or status='fail') and worker_ip='".$conf->getAttribute('host')."' order by insert_time asc";
    my $sth=$dbh->prepare($sql);
    
    $sth->execute;

    warn "no package needed to submit\n" if($sth->rows==0);

    my $status;
    my $tarfile;
    my $tarfile;
    my $hash;
    while( $hash=$sth->fetchrow_hashref)
    {
        $status='success'; 
        $tarfile="$sample_dir/$hash->{package_name}";
        if( -e $tarfile ){
        	my $retry_times = 0;
            open(FH,">$tarfile.ready") or die "Can't create $tarfile ready file: $!";
            close(FH);

            $status='fail' and next unless &replace_old_app($tarfile);#save  local copy
            RE_COMMIT:{
                # check every system command
                unless( 
                        execute_cmd( "cp $tarfile $analytic_dir/")
                            or 
                        execute_cmd( "cp $tarfile $cloud_dir/" )
                            or 
                        execute_cmd( "cp $tarfile $bakup_dir/" )
                            or 
                        execute_cmd( "cp $tarfile.ready $analytic_dir/")
                            or 
                        execute_cmd( "cp $tarfile.ready $cloud_dir/" )
                ){
                    ++$retry_times;
                    $status = 'fail';
                    redo RE_COMMIT if $retry_times < 3
                }
            }
        }
        $dbh->do("update app_info, task_detail set delivery_time=now() where task_id=$hash->{task_id} and  app_info.app_url_md5 = task_detail.detail_id");
    }continue{
        if ($status eq 'success'){
            unlink($tarfile);           
        }else{
            unlink("$analytic_dir/$hash->{package_name}");           
            unlink("$cloud_dir/$hash->{package_name}");           
            unlink("$analytic_dir/".$hash->{package_name}.".ready");           
            unlink("$cloud_dir/".$hash->{package_name}.".ready");         
            $hash->{package_name}=~ m/(.+?)__/;
            my $market_name = $1;  
            my $market_info = $db_helper->get_market_info($market_name);

            my $sql2 =<<EOF;
            select 
            a.detail_id as app_url_md5
            from task_detail a,task b 
            where a.task_id= $hash->{task_id}
            and b.market_id = $market_info->{id}
            and b.task_type='new_app'
EOF
            my $sth = $dbh->prepare($sql2);
            $sth->execute;
            while( my $hashref = $sth->fetchrow_hashref ){
            	$dbh->do(
            	    "update app_info set status='fail' 
            	    where app_url_md5=$hashref->{app_url_md5}"
                );
            }

        }
        unlink("$tarfile.ready");
        $dbh->do("update package set status='$status',end_time=now() where task_id=$hash->{task_id}");
    }

}

sub replace_old_app{
    my $tarfile = shift;

    my $resp=`tar -tvf  $tarfile  |grep "^d"|awk '{if(\$6 !~ /res|apk|header|page|description/) print \$6}'`;
    $resp=~s/\n/  /g;
    my $cmd="cd ".$conf->getAttribute("TempFolder").";rm -rf $resp";
    return 0 unless execute_cmd($cmd);
    $cmd="cd $bakup_dir/markets;rm -rf $resp";
    return 0 unless execute_cmd($cmd);
    $cmd="tar xzvf $tarfile -C $bakup_dir/markets --no-same-owner";
    return execute_cmd($cmd);
}
