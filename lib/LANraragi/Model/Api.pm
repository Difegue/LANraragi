package LANraragi::Model::Api;

use strict;
use warnings;
use utf8;

use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json);

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;

use LANraragi::Model::Config;

# Functions used by the API.

# Generates an array of all the archive JSONs in the database that have existing files.
sub generate_archive_list {

    my $redis = LANraragi::Model::Config::get_redis;
    my @keys  = $redis->keys('????????????????????????????????????????');
    my @list  = ();

    foreach my $id (@keys) {
        if (-e $redis->hget($id, "file")) {
            my $arcdata = LANraragi::Utils::Database::build_archive_JSON( $redis, $id );
            push @list, $arcdata;
        }
    }

    $redis->quit;
    return @list;
}

sub generate_opds_catalog {

    my $mojo  = shift;
    my $redis = LANraragi::Model::Config::get_redis;
    my @keys  = ();
    
    # Detailed pages just return a single entry instead of all the archives.
    if ($mojo->req->param('id')) {
        @keys = ($mojo->req->param('id'));
    } else {
        @keys = $redis->keys('????????????????????????????????????????');
    }

    my @list  = ();

    foreach my $id (@keys) {
        my $file = $redis->hget($id, "file");
        if (-e $file) {
            my $arcdata = LANraragi::Utils::Database::build_archive_JSON($redis, $id);
            my $tags    = $arcdata->{tags};

            # Infer a few OPDS-related fields from the tags
            $arcdata->{dateadded} = LANraragi::Utils::Generic::get_tag_with_namespace("dateadded", $tags, "2010-01-10T10:01:11Z");
            $arcdata->{author}    = LANraragi::Utils::Generic::get_tag_with_namespace("artist", $tags, "");
            $arcdata->{language}  = LANraragi::Utils::Generic::get_tag_with_namespace("language", $tags, "");
            $arcdata->{circle}    = LANraragi::Utils::Generic::get_tag_with_namespace("group", $tags, "");
            $arcdata->{event}     = LANraragi::Utils::Generic::get_tag_with_namespace("event", $tags, "");

            # Application/zip is universally hated by all readers so it's better to use x-cbz and x-cbr here.
            if ( $file =~ /^(.*\/)*.+\.(rar|cbr)$/ ) {
                $arcdata->{mimetype} = "application/x-cbr";
            } else {
                $arcdata->{mimetype} = "application/x-cbz";
            }

            for (values %{$arcdata}) 
                { LANraragi::Utils::Generic::escape_xml($_); }

            push @list, $arcdata;
        }
    }

    $redis->quit;

    if ($mojo->req->param('id')) {
        @keys = ($mojo->req->param('id'));
    } else {
        @keys = $redis->keys('????????????????????????????????????????');
    }

    return $mojo->render_to_string(
        template => $mojo->req->param('id') ? "opds_entry" : "opds",
        arclist  => \@list,
        arc      => $mojo->req->param('id') ? $list[0] : "",
        title    => $mojo->LRR_CONF->get_htmltitle,
        motd     => $mojo->LRR_CONF->get_motd,
        version  => $mojo->LRR_VERSION
    );
}

# Return a list of archive IDs that have no tags.
# Tags added automatically by the autotagger are ignored.
sub find_untagged_archives {

    my $redis   = LANraragi::Model::Config::get_redis;
    my @keys    = $redis->keys('????????????????????????????????????????');
    my @untagged;

    #Parse the archive list.
    foreach my $id (@keys) {
        my $zipfile = $redis->hget( $id, "file" );
        if ( -e $zipfile ) {

            my $title = $redis->hget( $id, "title" );
            $title = LANraragi::Utils::Database::redis_decode($title);

            my $tagstr = $redis->hget($id, "tags");
            $tagstr = LANraragi::Utils::Database::redis_decode($tagstr);
            my @tags = split(/,\s?/, $tagstr);
            my $nondefaulttags = 0;
            
            foreach my $t (@tags) {
                LANraragi::Utils::Generic::remove_spaces($t);
                LANraragi::Utils::Generic::remove_newlines($t);
                
                # the following are the only namespaces that LANraragi::Utils::Database::parse_name adds
                $nondefaulttags += 1 unless $t =~ /(artist|parody|series|language|event|group):.*/
            }
            
            #If the archive has no tags, or the tags namespaces are only from
            #filename parsing (probably), add it to the list.
            if (!@tags || $nondefaulttags == 0) {
                push @untagged, $id;
            }
        }
    }
    $redis->quit;
    return @untagged;
}

sub serve_thumbnail {

    my ($self, $id) = @_;
    my $dirname     = LANraragi::Model::Config::get_userdir;

    #Thumbnails are stored in the content directory, thumb subfolder.
    my $thumbname = $dirname . "/thumb/" . $id . ".jpg";

    unless ( -e $thumbname ) {
        $thumbname =
          LANraragi::Utils::Archive::extract_thumbnail( $dirname, $id );
    }

    #Simply serve the thumbnail.
    #If it doesn't exist, serve an error placeholder instead.
    if ( -e $thumbname ) {
        $self->render_file( filepath => $thumbname );
    }
    else {
        $self->render_file( filepath => "./public/img/noThumb.png" );
    }
}

sub use_plugin {

    my ($self, $id) = @_;
    my $plugname    = $self->req->param('plugin');
    my $oneshotarg  = $self->req->param('arg');
    
    my $plugin = LANraragi::Utils::Plugins::get_plugin($plugname);
    my @args   = ();

    if ($plugin) {

        #Get the matching globalargs in Redis
        @args = LANraragi::Utils::Plugins::get_plugin_parameters($plugname);

        #Execute the plugin, appending the custom args at the end
        my %plugin_result;
        eval {
            %plugin_result = LANraragi::Model::Plugins::exec_plugin_on_file( $plugin, $id,
            $oneshotarg, @args );
        };

        if ($@) {
            $plugin_result{error} = $@;
        }

        #Returns the fetched tags in a JSON response.
        $self->render(
            json => {
                operation => "fetch_tags",
                success   => ( exists $plugin_result{error} ? 0 : 1 ),
                message   => $plugin_result{error},
                tags      => $plugin_result{new_tags},
                title =>
                  ( exists $plugin_result{title} ? $plugin_result{title} : "" )
            }
        );
        return;
    }

    $self->render(
        json => {
            operation => "fetch_tags",
            success   => 0,
            message   => "Plugin not found on system."
        }
    );
}

1;