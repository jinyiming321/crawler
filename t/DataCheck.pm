package DataCheck;

use strict;
use warnings;
use Encode;
use FileHandle;
use LWP::Simple;

sub CHECK_ATTR () {
    return qw(
        author
        app_url
        app_name
        icon
        price
        system_requirement
        min_os_version
        max_os_version
        resolution
        last_update
        size
        official_rating_stars
        official_rating_times
        app_qr
        note
        apk_url
        total_install_times
        official_rating_times
        description
        official_category
        trustgo_category_id
        related_app
        creenshot
        permission
        status
        category_id
    )
}

sub PRIOR_CHECK_ATTR () {
    return  qw();
}

sub NOT_CHECK(){
    0
}

sub CHECK_FUNC_SUITE (){
    1
}

sub new{
    my $class = shift;
    my %param = @_;

    my $self = [];

    # check args 'check_func' => sub {}
    foreach my $attr( CHECK_ATTR  ){
        push @{ $self->[NOT_CHECK] },$attr
            unless exists $param{check_value};
    }

    foreach my $check( keys %param ){
        $self->[CHECK_FUNC_SUITE]->{$check} = delete $param{$check};
    }

    bless $self,$class;
    return $self;
}

sub check{
    my $self = shift;
    my %args = @_;
    
    foreach my $key(keys %args){
        my $data = $args{$key};
        my $check = $self->[CHECK_FUNC_SUITE]->{$key};
        warn "check attr faild $key \n" unless $check->($data) ==1;
    }
}

1;

#use DataCheck;

