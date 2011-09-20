use DataCheck;

my %check_suite = (
    author      => sub {
        my $content = shift;
        print "hello author";
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

my $o = new DataCheck( %check_suite );
$o->check( 'author' => '安丰网' );

