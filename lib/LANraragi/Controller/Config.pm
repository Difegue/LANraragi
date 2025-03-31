package LANraragi::Controller::Config;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Utils::Generic    qw(generate_themes_header);
use LANraragi::Utils::String     qw(trim trim_CRLF);
use LANraragi::Utils::Database   qw(redis_encode save_computed_tagrules);
use LANraragi::Utils::Tags       qw(tags_rules_to_array replace_CRLF restore_CRLF);
use Mojo::JSON                   qw(encode_json);

use Authen::Passphrase::BlowfishCrypt;

# Render the configuration page
sub index {

    my $self = shift;

    $self->render(
        template        => "config",
        version         => $self->LRR_VERSION,
        vername         => $self->LRR_VERNAME,
        descstr         => $self->LRR_DESC,
        motd            => $self->LRR_CONF->get_motd,
        dirname         => $self->LRR_CONF->get_userdir,
        thumbdir        => $self->LRR_CONF->get_thumbdir,
        forceddirname   => ( defined $ENV{LRR_DATA_DIRECTORY}  ? 1 : 0 ),
        forcedthumbdir  => ( defined $ENV{LRR_THUMB_DIRECTORY} ? 1 : 0 ),
        pagesize        => $self->LRR_CONF->get_pagesize,
        enablepass      => $self->LRR_CONF->enable_pass,
        password        => $self->LRR_CONF->get_password,
        tagruleson      => $self->LRR_CONF->enable_tagrules,
        tagrules        => restore_CRLF( $self->LRR_CONF->get_tagrules ),
        title           => $self->LRR_CONF->get_htmltitle,
        tempmaxsize     => $self->LRR_CONF->get_tempmaxsize,
        cachemaxsize    => $self->LRR_CONF->get_cachemaxsize,
        localprogress   => $self->LRR_CONF->enable_localprogress,
        devmode         => $self->LRR_CONF->enable_devmode,
        nofunmode       => $self->LRR_CONF->enable_nofun,
        apikey          => $self->LRR_CONF->get_apikey,
        enablecors      => $self->LRR_CONF->enable_cors,
        enableresize    => $self->LRR_CONF->enable_resize,
        sizethreshold   => $self->LRR_CONF->get_threshold,
        readerquality   => $self->LRR_CONF->get_readquality,
        theme           => $self->LRR_CONF->get_style,
        usedateadded    => $self->LRR_CONF->enable_dateadded,
        usedatemodified => $self->LRR_CONF->use_lastmodified,
        enablecryptofs  => $self->LRR_CONF->enable_cryptofs,
        hqthumbpages    => $self->LRR_CONF->get_hqthumbpages,
        jxlthumbpages   => $self->LRR_CONF->get_jxlthumbpages,
        csshead         => generate_themes_header($self),
        tempsize        => 0,
        replacedupe     => $self->LRR_CONF->get_replacedupe
    );
}

# Save the given parameters to the Redis config
sub save_config {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis_config;

    my $success   = 1;
    my $errormess = "";

    my %confhash = (
        htmltitle     => scalar $self->req->param('htmltitle'),
        motd          => scalar $self->req->param('motd'),
        dirname       => scalar $self->req->param('dirname'),
        thumbdir      => scalar $self->req->param('thumbdir'),
        pagesize      => scalar $self->req->param('pagesize'),
        tagrules      => replace_CRLF( $self->req->param('tagrules') ),
        tempmaxsize   => scalar $self->req->param('tempmaxsize'),
        cachemaxsize  => scalar $self->req->param('cachemaxsize'),
        apikey        => scalar $self->req->param('apikey'),
        readerquality => scalar $self->req->param('readerquality'),
        sizethreshold => scalar $self->req->param('sizethreshold'),
        theme         => scalar $self->req->param('theme'),

        # For checkboxes,
        # we check if the parameter exists in the POST to return either 1 or 0.
        enablepass      => ( scalar $self->req->param('enablepass')      ? '1' : '0' ),
        enablecors      => ( scalar $self->req->param('enablecors')      ? '1' : '0' ),
        localprogress   => ( scalar $self->req->param('localprogress')   ? '1' : '0' ),
        devmode         => ( scalar $self->req->param('devmode')         ? '1' : '0' ),
        enableresize    => ( scalar $self->req->param('enableresize')    ? '1' : '0' ),
        tagruleson      => ( scalar $self->req->param('tagruleson')      ? '1' : '0' ),
        nofunmode       => ( scalar $self->req->param('nofunmode')       ? '1' : '0' ),
        usedateadded    => ( scalar $self->req->param('usedateadded')    ? '1' : '0' ),
        usedatemodified => ( scalar $self->req->param('usedatemodified') ? '1' : '0' ),
        enablecryptofs  => ( scalar $self->req->param('enablecryptofs')  ? '1' : '0' ),
        hqthumbpages    => ( scalar $self->req->param('hqthumbpages')    ? '1' : '0' ),
        jxlthumbpages   => ( scalar $self->req->param('jxlthumbpages')   ? '1' : '0' ),
        replacedupe     => ( scalar $self->req->param('replacedupe')     ? '1' : '0' ),
    );

    # Only add newpassword field as password if enablepass = 1
    if ( $self->req->param('enablepass') ) {

        # Hash password with authen
        my $password = $self->req->param('newpassword');

        if ( $password ne "" ) {
            my $ppr = Authen::Passphrase::BlowfishCrypt->new(
                cost        => 8,
                salt_random => 1,
                passphrase  => $password,
            );

            my $pass_hashed = $ppr->as_rfc2307;
            $confhash{password} = $pass_hashed;
        }
    }

    # Password check
    if ( $self->req->param('newpassword') ne $self->req->param('newpassword2') ) {
        $success   = 0;
        $errormess = "Mismatched passwords.";
    }

    # Numbers only in fields w. numbers
    if (   $confhash{pagesize} =~ /\D+/
        || $confhash{readerquality} =~ /\D+/
        || $confhash{sizethreshold} =~ /\D+/ ) {
        $success   = 0;
        $errormess = "Invalid characters.";
    }

    #Did all the checks pass ?
    if ($success) {

        $redis->watch("LRR_CONFIG");
        $redis->multi;

        foreach my $key ( keys %confhash ) {
            my $value = $confhash{$key};

            if ( $value ne '0' && $value ne '1' ) {

                # Clean up the user's inputs for non-toggle options and encode for redis insertion
                $value = trim($value);
                $value = trim_CRLF($value);
                $value = redis_encode($value);
            }

            # For all keys of the hash, add them to the redis config hash with the matching keys.
            $self->LRR_LOGGER->debug( "Saving $key with value " . $value );
            $redis->hset( "LRR_CONFIG", $key, $value );
        }

        $redis->exec;
    }

    $redis->quit;

    my @computed_tagrules = tags_rules_to_array( $self->req->param('tagrules') );
    $self->LRR_LOGGER->debug( "Saving computed tag rules : " . encode_json( \@computed_tagrules ) );
    save_computed_tagrules( \@computed_tagrules );

    $self->render(
        json => {
            operation => "config",
            success   => $success,
            message   => $errormess
        }
    );

}

1;
