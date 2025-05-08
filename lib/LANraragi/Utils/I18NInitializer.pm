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

            # TODO handle fallbacks, ie Accept-Language zh-TW,zh-CN;q=0.8,fr;q=0.7,fr-FR;q=0.5,en-US;q=0.3,en;q=0.2
            if ($accept_language) {
                ($lang) = split /,/, $accept_language;
                $lang =~ s/;.*//; # remove any quality value
                $c->LRR_LOGGER->trace("Detected language: $lang");
            }

            my $handle = LANraragi::Utils::I18N->get_handle($lang);
            unless ($handle) {
                $c->LRR_LOGGER->trace("No handle for language: $lang, trying without region");
                $lang =~ s/-.*//;
                $handle = LANraragi::Utils::I18N->get_handle($lang);
                unless ($handle) {
                    $c->LRR_LOGGER->trace("No handle for $lang, falling back to English");
                    $handle = LANraragi::Utils::I18N->get_handle('en');
                }
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
                eval { $translated = LANraragi::Utils::I18N->get_handle('en')->maketext( $key, @encoded_args ); };
                if ($@) { return $key; }    # Last-ditch fallback
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
