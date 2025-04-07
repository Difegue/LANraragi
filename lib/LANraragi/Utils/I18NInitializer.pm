package LANraragi::Utils::I18NInitializer;

use strict;
use warnings;
use utf8;
use Encode;
use LANraragi::Utils::I18N;

sub initialize {
    my ($app) = @_;

    $app->helper(
        lh => sub {
            my ( $c, $key, @args ) = @_;
            my $accept_language = $c->req->headers->accept_language;

            # default language
            my $lang = 'en';

            if ($accept_language) {
                ($lang) = split /,/, $accept_language;
                $lang =~ s/-.*//;
                $c->LRR_LOGGER->trace("Detected language: $lang");
            }

            my $handle = LANraragi::Utils::I18N->get_handle($lang);
            unless ($handle) {
                $c->LRR_LOGGER->trace("No handle for language: $lang, fallback to en");
                $handle = LANraragi::Utils::I18N->get_handle('en');
                return $key unless $handle;
            }

            $c->LRR_LOGGER->trace( "Key: $key, Args: " . join( ", ", map { defined($_) ? $_ : 'undef' } @args ) );

            # make sure all args are encoded in UTF-8
            my @encoded_args = map { Encode::encode( 'UTF-8', $_ ) } @args;

            my $translated;
            my $error;
            eval { $translated = $handle->maketext( $key, @encoded_args ); };
            $error = $@;
            if ($error) {
                $c->LRR_LOGGER->error("Maketext error: [$error]");
                return $key;
            }

            # make sure the result is decoded in UTF-8
            if ( !Encode::is_utf8($translated) ) {
                $translated = Encode::decode_utf8($translated);
            }

            $c->LRR_LOGGER->trace("Translated result: $translated");
            return $translated;
        }
    );

    $app->LRR_LOGGER->debug("I18N system initialized.");
}

1;
