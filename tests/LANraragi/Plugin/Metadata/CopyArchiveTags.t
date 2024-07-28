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

note('extract_archive_id returns undef if param doesn\'t contain a valid archive ID ...');
{
    is( LANraragi::Plugin::Metadata::CopyArchiveTags::extract_archive_id(undef), undef, 'param was undef' );

    is( LANraragi::Plugin::Metadata::CopyArchiveTags::extract_archive_id(''), undef, 'param was empty' );

    my $short_hex = substr( _random_archive_id(), 1 );

    is( LANraragi::Plugin::Metadata::CopyArchiveTags::extract_archive_id("http://127.0.0.1:3000/reader?id=${short_hex}"),
        undef, 'invalid id: too short hex number' );

    my $long_hex = 'fff' . _random_archive_id();

    is( LANraragi::Plugin::Metadata::CopyArchiveTags::extract_archive_id("http://127.0.0.1:3000/reader?id=${long_hex}"),
        undef, 'invalid id: too long hex number' );

}

note('extract_archive_id returns the ID in lowercase ...');
{
    my $archive_id = uc _random_archive_id();

    is( LANraragi::Plugin::Metadata::CopyArchiveTags::extract_archive_id("http://127.0.0.1:3000/reader?id=${archive_id}"),
        lc $archive_id,
        'lowercase ID'
    );
}

note('extract_archive_id parses oneshot_param ...');
{

    my $archive_id = _random_archive_id();
    is( LANraragi::Plugin::Metadata::CopyArchiveTags::extract_archive_id($archive_id), $archive_id, 'simple ID input' );

    $archive_id = _random_archive_id();
    is( LANraragi::Plugin::Metadata::CopyArchiveTags::extract_archive_id("   ${archive_id}    "), $archive_id, 'dirty input 1' );

    $archive_id = _random_archive_id();
    is( LANraragi::Plugin::Metadata::CopyArchiveTags::extract_archive_id("d=${archive_id}    "), $archive_id, 'dirty input 2' );

    $archive_id = _random_archive_id();
    is( LANraragi::Plugin::Metadata::CopyArchiveTags::extract_archive_id("http://127.0.0.1:3000/reader?id=${archive_id}"),
        $archive_id, 'reader URL - localhost' );

    $archive_id = _random_archive_id();
    is( LANraragi::Plugin::Metadata::CopyArchiveTags::extract_archive_id("http://127.0.0.1:3000/edit?id=${archive_id}"),
        $archive_id, 'editor URL - localhost' );

    $archive_id = _random_archive_id();
    is( LANraragi::Plugin::Metadata::CopyArchiveTags::extract_archive_id("http://lanraragi.pizza/reader?id=${archive_id}"),
        $archive_id, 'reader URL - hostname' );

    $archive_id = _random_archive_id();
    is( LANraragi::Plugin::Metadata::CopyArchiveTags::extract_archive_id("http://lanraragi.geek/edit?id=${archive_id}"),
        $archive_id, 'editor URL - hostname' );

}

note('internal_get_tags dies when oneshot_param is undefined ...');
{

    my $log_mock = get_logger_mock();
    my $params   = {
        'oneshot'         => undef,
        'copy_date_added' => undef,
        'lrr_info'        => { 'archive_id' => 'dummy' }
    };

    # Act
    trap { LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags( $log_mock, $params ); };

    is( $trap->exit,   undef, 'no exit code' );
    is( $trap->stdout, '',    'no STDOUT' );
    is( $trap->stderr, '',    'no STDERR' );
    like( $trap->die, qr/^oneshot_param doesn't contain a valid archive ID/, 'die message' );
}

note('internal_get_tags dies when oneshot_param is empty ...');
{

    my $log_mock = get_logger_mock();
    my $params   = {
        'oneshot'         => '',
        'copy_date_added' => undef,
        'lrr_info'        => { 'archive_id' => 'dummy' }
    };

    # Act
    trap { LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags( $log_mock, $params ); };

    is( $trap->exit,   undef, 'no exit code' );
    is( $trap->stdout, '',    'no STDOUT' );
    is( $trap->stderr, '',    'no STDERR' );
    like( $trap->die, qr/^oneshot_param doesn't contain a valid archive ID/, 'die message' );
}

note('internal_get_tags dies when oneshot_param doesn\'t contain a valid archive ID ...');
{

    my $log_mock = get_logger_mock();
    my $params   = {
        'oneshot'         => 'xpto',
        'copy_date_added' => undef,
        'lrr_info'        => { 'archive_id' => 'dummy' }
    };

    # Act
    trap { LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags( $log_mock, $params ); };

    is( $trap->exit,   undef, 'no exit code' );
    is( $trap->stdout, '',    'no STDOUT' );
    is( $trap->stderr, '',    'no STDERR' );
    like( $trap->die, qr/^oneshot_param doesn't contain a valid archive ID/, 'die message' );
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

note('internal_get_tags does not return date_added by default ...');
{
    my @log_messages;
    my $log_mock = get_logger_mock( \@log_messages );
    my $input_id = _random_archive_id();
    my $params   = {
        'oneshot'  => $input_id,
        'lrr_info' => { 'archive_id' => _random_archive_id() }
    };

    no warnings 'once', 'redefine';
    local *LANraragi::Utils::Database::get_tags = sub {
        return 'date_added:123,tag1,tag2';
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

    no warnings 'once', 'redefine';
    local *LANraragi::Utils::Database::get_tags = sub {
        return 'date_added:321,tag3,tag4';
    };

    # Act
    my %data = LANraragi::Plugin::Metadata::CopyArchiveTags::internal_get_tags( $log_mock, $params );

    cmp_deeply( \%data, { 'tags' => 'date_added:321,tag3,tag4' }, 'returned tags list' );

    cmp_deeply( \@log_messages, [ [ 'info', ignore, "Copying tags from archive \"${input_id}\"" ] ], 'log messages' );
}

done_testing();
