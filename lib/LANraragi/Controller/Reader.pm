package LANraragi::Controller::Reader;
use Mojo::Base 'Mojolicious::Controller';

use Encode;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;

use LANraragi::Model::Config;
use LANraragi::Model::Reader;

# This action will render a template
sub index {
    my $self = shift;

    if ( $self->req->param('id') ) {

        # We got a file name, let's get crackin'.
        my $id = $self->req->param('id');

        #Quick Redis check to see if the ID exists:
        my $redis = $self->LRR_CONF->get_redis();

        unless ( $redis->hexists( $id, "title" ) ) {
            $self->redirect_to('index');
        }

        #Get a computed archive name if the archive exists
        my $arcname = "";
        my $tags = $redis->hget( $id, "tags" );
        $arcname = $redis->hget( $id, "title" );

        if ( $tags =~ /artist:/ ) {
            $tags =~ /.*artist:([^,]*),.*/;
            $arcname = $arcname . " by " . $1;
        }

        $arcname = LANraragi::Utils::Database::redis_decode($arcname);

        my $force       = $self->req->param('force_reload')     || "0";
        my $thumbreload = $self->req->param('reload_thumbnail') || "0";
        my $imgpaths    = "";

        #Load a json matching pages to paths
        eval {
            $imgpaths =
              LANraragi::Model::Reader::build_reader_JSON( $self, $id, $force,
                $thumbreload );
        };
        my $err = $@;

        if ($err) {

            $self->render(
                template => "error",
                title    => $self->LRR_CONF->get_htmltitle,
                filename => $redis->hget( $id, "file" ),
                errorlog => $err
            );
            return;
        }

        $self->render(
            template   => "reader",
            arcname    => $arcname,
            id         => $id,
            imgpaths   => $imgpaths,
            cssdrop    => LANraragi::Utils::Generic::generate_themes,
            userlogged => $self->LRR_CONF->enable_pass == 0
              || $self->session('is_logged')
        );
    }
    else {
        # No parameters back the fuck off
        $self->redirect_to('index');
    }
}

1;
