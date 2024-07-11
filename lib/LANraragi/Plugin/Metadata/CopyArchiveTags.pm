package LANraragi::Plugin::Metadata::CopyArchiveTags;

use strict;
use warnings;

use LANraragi::Model::Plugins;
use LANraragi::Utils::Database qw(get_archive_tags);
use LANraragi::Utils::Logging  qw(get_plugin_logger);
use LANraragi::Utils::Tags     qw(join_tags_to_string);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "CopyArchiveTags",
        type        => "metadata",
        namespace   => "copy-archive-tags",
        author      => "IceBreeze",
        version     => "1.0",
        description => "Copy tags from another LRR archive given either the URI or the ID.",
        parameters  => [
            {   type => "bool",
                name => 'copy_date_added',
                desc => "Enable to also copy the date (but it's up to you to remove the old one)"
            }
        ],
        oneshot_arg => "LRR Gallery URI or ID:"
    );

}

sub get_tags {
    my $params = read_params(@_);
    my $logger = get_plugin_logger();

    # should be handled in the caller
    my %hashdata = eval { internal_get_tags( $logger, $params ); };
    if ($@) {
        $logger->error($@);
        return ( error => $@ );
    }

    $logger->info( "Sending the following tags to LRR: " . ( $hashdata{tags} || '-' ) );
    return %hashdata;
}

sub internal_get_tags {
    my ( $logger, $params ) = @_;

    my $lrr_gid = $params->{'oneshot'};
    $lrr_gid =~ s/^.*id=//i;    # extract the ID from the URI if necessary

    if ( $lrr_gid eq $params->{'lrr_info'}{'archive_id'} ) {
        die "You are using the current archive ID\n";
    }

    $logger->info("Copying tags from archive \"${lrr_gid}\"");

    my $tags;
    if ( $params->{'copy_date_added'} ) {
        $tags = get_archive_tags($lrr_gid);
    } else {
        my @tags = get_archive_tags($lrr_gid);
        $tags = join_tags_to_string( grep( !m/date_added/, @tags ) );
    }

    my %hashdata = ( tags => $tags );

    return %hashdata;
}

sub read_params {
    my %plugin_info = plugin_info();
    my $lrr_info    = $_[1];
    my @param_cfg   = @{ $plugin_info{parameters} };

    my %params;
    $params{lrr_info} = $lrr_info;
    $params{oneshot}  = $lrr_info->{oneshot_param};
    for ( my $i = 0; $i < scalar @param_cfg; $i++ ) {
        my $value = $_[ $i + 2 ] || $param_cfg[$i]->{default};
        $params{ $param_cfg[$i]->{name} } = $value;
    }
    return \%params;
}

1;
