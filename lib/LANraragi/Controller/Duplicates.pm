package LANraragi::Controller::Duplicates;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use URI::Escape;
use Redis;
use POSIX qw(strftime);
use Encode;

use Mojo::JSON qw(decode_json encode_json);

use LANraragi::Utils::Generic qw(generate_themes_header);

# Go through the archives in the content directory and build the template at the end.
sub index {

    my $self      = shift;
    my $redis_cfg = $self->LRR_CONF->get_redis_config;
    my $redis     = $self->LRR_CONF->get_redis;

    my $userlogged = $self->LRR_CONF->enable_pass == 0 || $self->session('is_logged');

    if ( $userlogged && $self->req->param('delete') ) {
        $self->LRR_LOGGER->debug("Cleared all detected duplicates!");
        $redis_cfg->del("duplicate_groups");
    }

    my %duplicate_groups = $redis_cfg->hgetall("duplicate_groups");
    my @duplicates;

    foreach my $key ( keys %duplicate_groups ) {

        # Decode the JSON-encoded array of IDs
        my $deserialized = decode_json( $duplicate_groups{$key} );
        my @ids          = @{$deserialized};

        my @archives;
        foreach my $id (@ids) {
            my %archive = $redis->hgetall($id);

            # Check if archive still exists
            if (%archive) {
                $archive{'arcid'}     = $id;
                $archive{'group_key'} = $key;

                if ( $archive{'tags'} =~ /date_added:(\d+)/ ) {
                    $archive{'date_added'} = strftime( "%Y-%m-%d %H:%M:%S", localtime($1) );
                }

                push @archives, \%archive;
            } else {

                # if dup size of group less than 2, its not a group anymore
                if ( scalar @ids <= 2 ) {
                    my $size = scalar @ids;
                    $self->LRR_LOGGER->debug("group $key: too small ($size) - removing key");
                    $redis_cfg->hdel( "duplicate_groups", $key );
                } else {

                    # archive vanished -> remove from dupes
                    @ids = grep { $_ ne $id } @ids;
                    $self->LRR_LOGGER->debug("group $key: archive $id vanished - removing from group");
                    $redis_cfg->hset( "duplicate_groups", $key, encode_json( \@ids ) );
                }
            }
        }
        push @duplicates, \@archives;
    }

    $redis->quit();

    $self->render(
        template   => "duplicates",
        title      => $self->LRR_CONF->get_htmltitle,
        duplicates => \@duplicates,
        csshead    => generate_themes_header($self)
    );
}

1;