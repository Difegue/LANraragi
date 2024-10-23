package LANraragi::Plugin::Metadata::CopyArchiveTags;

use strict;
use warnings;

use LANraragi::Model::Plugins;
use LANraragi::Utils::Database;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Tags    qw(join_tags_to_string split_tags_to_array);
use LANraragi::Utils::String  qw(trim);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name            => "Copy Archive Tags",
        type            => "metadata",
        namespace       => "copy-archive-tags",
        author          => "IceBreeze",
        version         => "1.2",
        description     => "Copy tags from another LRR archive given either the URI or the ID.",
        to_named_params => ['copy_date_added'],
        parameters      => {
            'copy_date_added' => {
                type => "bool",
                desc => "Enable to also copy the date (but it's up to you to remove the old one)"
            }
        },
        oneshot_arg => "LRR Gallery URL or ID:"
    );

}

sub get_tags {
    my ( undef, $lrr_info, $params ) = @_;

    my $logger = get_plugin_logger();

    my $lrr_gid = extract_archive_id( $params->{oneshot} );
    if ( !$lrr_gid ) {
        die "oneshot_param doesn't contain a valid archive ID\n";
    }

    if ( $lrr_gid eq $lrr_info->{'archive_id'} ) {
        die "You are using the current archive ID\n";
    }

    $logger->info("Copying tags from archive \"${lrr_gid}\"");

    my $tags = LANraragi::Utils::Database::get_tags($lrr_gid) || '';

    if ( !$params->{'copy_date_added'} ) {
        my @tags = split_tags_to_array($tags);
        $tags = join_tags_to_string( grep( !m/date_added/, @tags ) );
    }

    $logger->info( "Sending the following tags to LRR: " . ( $tags || '-' ) );

    return ( tags => $tags || '' );
}

sub extract_archive_id {
    my ($oneshot) = @_;
    return if ( !$oneshot || length($oneshot) < 40 );
    if ( ( lc $oneshot ) =~ m/([0-9a-f]{40,})/ ) {
        return $1 if length($1) == 40;
    }
    return;
}

1;
