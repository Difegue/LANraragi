use strict;
use warnings;
use utf8;
use Data::Dumper;

use Cwd qw( getcwd );

use Test::More;
use Test::Deep;
use Test::Trap;

my $cwd = getcwd();
require "$cwd/tests/mocks.pl";

use_ok('LANraragi::Plugin::Metadata::CopyArchiveTags');

sub _random_archive_id {
    my $rnd = '';
    $rnd .= sprintf( "%x", rand 16 ) for 1 .. 40;
    return $rnd;
}

note('testing that get_tags doesn\'t die ...');
{

    my $lrr_info = { 'oneshot_param' => _random_archive_id() };
    my @log_messages;
    my $log_mock = get_logger_mock( \@log_messages );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::CopyArchiveTags::get_plugin_logger = sub { return $log_mock };
    local *LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags = sub { die "Eep!\n"; };

    # Act
    my @error = LANraragi::Plugin::Metadata::CopyArchiveTags::get_tags( 'dummy', $lrr_info, 'dummy', 0, 'dummy' );

    cmp_deeply( \@error, [ 'error', "Eep!\n" ], 'returned error' );

    cmp_deeply( \@log_messages, [ [ 'error', $log_mock, "Eep!\n" ] ], 'log messages' );

}

note('testing get_tags returning an empty tag list ...');
{

    my $lrr_info = { 'oneshot_param' => _random_archive_id() };
    my @log_messages;

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::CopyArchiveTags::get_plugin_logger = sub { return get_logger_mock( \@log_messages ) };
    local *LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags = sub { return (); };
    local *LANraragi::Plugin::Metadata::CopyArchiveTags::read_params       = sub { return {}; };

    # Act
    my @rdata = LANraragi::Plugin::Metadata::CopyArchiveTags::get_tags( 'dummy', $lrr_info, 'dummy', 0, 'dummy' );

    cmp_deeply( \@rdata, [], 'returned data' );

    cmp_deeply( \@log_messages, [ [ 'info', ignore, 'Sending the following tags to LRR: -' ] ], 'log messages' );

}

note('testing get_tags returning a list of tags ...');
{

    my $lrr_info = { 'oneshot_param' => _random_archive_id() };
    my @log_messages;

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::CopyArchiveTags::get_plugin_logger = sub { return get_logger_mock( \@log_messages ) };
    local *LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags = sub { return ( 'tags' => 'one, two' ); };
    local *LANraragi::Plugin::Metadata::CopyArchiveTags::read_params       = sub { return {}; };

    # Act
    my @rdata = LANraragi::Plugin::Metadata::CopyArchiveTags::get_tags( 'dummy', $lrr_info, 'dummy', 0, 'dummy' );

    cmp_deeply( \@rdata, [ tags => 'one, two' ], 'returned data' );

    cmp_deeply( \@log_messages, [ [ 'info', ignore, 'Sending the following tags to LRR: one, two' ] ], 'log messages' );
}

note('internal_get_tags dies when search ID matches the current archive ID ...');
{

    my $log_mock    = get_logger_mock();
    my $the_only_id = _random_archive_id();
    my $params      = {
        'oneshot'         => $the_only_id,
        'copy_date_added' => undef,
        'lrr_info'        => { 'archive_id' => $the_only_id }
    };

    # Act
    trap { LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags( $log_mock, $params ); };

    is( $trap->exit,   undef, 'no exit code' );
    is( $trap->stdout, '',    'no STDOUT' );
    is( $trap->stderr, '',    'no STDERR' );
    like( $trap->die, qr/^You are using the current archive ID/, 'die message' );
}

note('internal_get_tags parses oneshot_param ...');
{
    my @log_messages;
    my $log_mock = get_logger_mock( \@log_messages );
    my $params   = { 'lrr_info' => { 'archive_id' => 'dummy' } };

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::CopyArchiveTags::get_archive_tags = sub { return 'dummy'; };

    # passing explicit ID
    my $user_input_key = _random_archive_id();
    $params->{'oneshot'} = $user_input_key;

    LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags( $log_mock, $params );

    cmp_deeply( \@log_messages, [ [ 'info', ignore, "Copying tags from archive \"$user_input_key\"" ] ], 'used explicit ID' );

    ### passing localhost reader uri
    @log_messages        = ();
    $user_input_key      = _random_archive_id();
    $params->{'oneshot'} = 'http://127.0.0.1:3000/reader?id=' . $user_input_key;

    LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags( $log_mock, $params );

    cmp_deeply(
        \@log_messages,
        [ [ 'info', ignore, "Copying tags from archive \"$user_input_key\"" ] ],
        'extracted from localhost reader URI'
    );

    ### passing localhost edit uri
    @log_messages        = ();
    $user_input_key      = _random_archive_id();
    $params->{'oneshot'} = 'http://127.0.0.1:3000/edit?id=' . $user_input_key;

    LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags( $log_mock, $params );

    cmp_deeply(
        \@log_messages,
        [ [ 'info', ignore, "Copying tags from archive \"$user_input_key\"" ] ],
        'extracted from localhost edit URI'
    );

    ### passing remote reader uri
    @log_messages        = ();
    $user_input_key      = _random_archive_id();
    $params->{'oneshot'} = 'http://lanraragi.pizza/reader?id=' . $user_input_key;

    LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags( $log_mock, $params );

    cmp_deeply(
        \@log_messages,
        [ [ 'info', ignore, "Copying tags from archive \"$user_input_key\"" ] ],
        'extracted from remote reader URI'
    );

    ### passing remote edit uri
    @log_messages        = ();
    $user_input_key      = _random_archive_id();
    $params->{'oneshot'} = 'http://lanraragi.geek/edit?id=' . $user_input_key;

    LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags( $log_mock, $params );

    cmp_deeply(
        \@log_messages,
        [ [ 'info', ignore, "Copying tags from archive \"$user_input_key\"" ] ],
        'extracted from remote edit URI'
    );

}

note('internal_get_tags does not return date_added by default ...');
{
    my @log_messages;
    my $log_mock = get_logger_mock( \@log_messages );
    my $input_id = _random_archive_id();
    my $params   = {
        'oneshot'  => $input_id,
        'lrr_info' => { 'archive_id' => _random_archive_id() }
    };
    my @tags_ok = ( 'date_added:123', 'tag1', 'tag2' );
    my $tags_ko = 'date_added:000,wrong1,wrong2';

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::CopyArchiveTags::get_archive_tags = sub {
        return wantarray ? @tags_ok : $tags_ko;
    };

    # Act
    my %data = LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags( $log_mock, $params );

    cmp_deeply( \%data, { 'tags' => 'tag1,tag2' }, 'returned tags list' );

    cmp_deeply( \@log_messages, [ [ 'info', ignore, "Copying tags from archive \"${input_id}\"" ] ], 'log messages' );
}

note('internal_get_tags returns date_added if asked ...');
{
    my @log_messages;
    my $log_mock = get_logger_mock( \@log_messages );
    my $input_id = _random_archive_id();
    my $params   = {
        'oneshot'         => $input_id,
        'copy_date_added' => 1,
        'lrr_info'        => { 'archive_id' => _random_archive_id() }
    };
    my @tags_ko = ( 'date_added:000', 'wrong3', 'wrong4' );
    my $tags_ok = 'date_added:321,tag3,tag4';

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::CopyArchiveTags::get_archive_tags = sub {
        return wantarray ? @tags_ko : $tags_ok;
    };

    # Act
    my %data = LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags( $log_mock, $params );

    cmp_deeply( \%data, { 'tags' => 'date_added:321,tag3,tag4' }, 'returned tags list' );

    cmp_deeply( \@log_messages, [ [ 'info', ignore, "Copying tags from archive \"${input_id}\"" ] ], 'log messages' );
}

done_testing();
