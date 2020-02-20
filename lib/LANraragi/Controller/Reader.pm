package LANraragi::Controller::Reader;
use Mojo::Base 'Mojolicious::Controller';

use Encode;

use LANraragi::Utils::Generic qw(generate_themes_selector generate_themes_header);
use LANraragi::Utils::Database qw(redis_decode);

use LANraragi::Model::Reader;

# This action will render a template
sub index {
    my $self = shift;

    if ( $self->req->param('id') ) {

        # We got a file name, let's get crackin'.
        my $id = $self->req->param('id');

        #Quick Redis check to see if the ID exists:
        my $redis = $self->LRR_CONF->get_redis();

        unless ( $redis->exists($id) ) {
            $self->redirect_to('index');
        }

        #Get a computed archive name if the archive exists
        my $arcname  = $redis->hget( $id, "title" );
        my $tags     = $redis->hget( $id, "tags"  );
        my $filename = $redis->hget( $id, "file"  );
        $arcname  = redis_decode($arcname);
        $tags     = redis_decode($tags);
        $filename = redis_decode($filename);

        if ( $tags =~ /artist:/ ) {
            $tags =~ /.*artist:([^,]*),.*/;
            if ($1) { $arcname = $arcname . " by " . $1; }
        }

        my $force       = $self->req->param('force_reload')     || "0";
        my $thumbreload = $self->req->param('reload_thumbnail') || "0";
        my $imgpaths    = "";

        #Load a json matching pages to paths
        eval {
            $imgpaths =
              LANraragi::Model::Reader::build_reader_JSON( $self, $id, $force,
                $thumbreload );
        };

        if ($@) {
            my $err = $@;

            # Add some more info for RAR5
            if ($filename =~ /^.+\.rar$/ && $err =~ /Unrecognized archive format.*$/) {
                $err.= "\n RAR5 archives are not supported.";
            }

            $self->render(
                template => "error",
                title    => $self->LRR_CONF->get_htmltitle,
                filename => $filename,
                errorlog => $err
            );
            return;
        }

        $redis->quit();
        $self->render(
            template   => "reader",
            arcname    => $arcname,
            id         => $id,
            imgpaths   => $imgpaths,
            filename   => $filename,
            cssdrop    => generate_themes_selector,
            csshead    => generate_themes_header($self),
            version    => $self->LRR_VERSION,
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
