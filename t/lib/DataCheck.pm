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
        $self->[CHECK_FUNC_SUITE]->{$check} = delete $param{$check}{func};
    }

    bless $self,$class;
    return $self;
}

sub check{
    my $self = shift;
    my @args = @_;

    while( my ($attr,$func) = %$self->[CHECK_FUNC_SUITE] ){
            warn "check attr $attr failed \n" unless $func->(@_) == 1 ;
    }
}

1;

use DataCheck;

my %check_suite = (
    author      => sub {
        my $content = shift;
        return $content =~ m/安丰网/
    },
    app_name    => sub{
        my $data = shift;
        return $data =~ m//
    },
    official_category => sub {
        my $data = shift;
        return $data =~ m//
    },
    current_version => sub {
        my $data = shift;
        return $data =~ m//
    },
    size  => sub{
        my $data = shift;
        return $data =~ m//
    },
    price  => sub {
        my $data = shift;
        return $data =~ m//;
    },
    description => sub {
        my $data = shift;
        return $data =~ m//;
    },
    apk_url  => sub {
        my $data = shift;
        return $data = ~ m//;
    },
    last_update  => sub {
        my $data = shift;
        return $data =~ m//;
    },
    total_install_times  => sub {
        my $data = shift;
        return $data =~ m//;
    },
    app_qr => sub {
        my $data = shift;
        return $data =~ m//;
    },
    permission => sub {
        my $data = shift;
        return $data =~ m//;
    },
    screenshot => sub {
        my $data = shift;
        return $data =~ m//;
    },
    official_rating_stars => sub {
        my $data = shift;
        return $data =~ m//;
    },
    related_app => sub {

    },
    ico => sub {
        my $data = shift;
    },
);

