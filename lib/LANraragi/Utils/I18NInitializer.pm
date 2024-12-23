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
            my ($c, $key, @args) = @_;

            my $accept_language = $c->req->headers->accept_language;
            my $lang = 'en';

            if ($accept_language) {
                ($lang) = split /,/, $accept_language;
                $lang =~ s/-.*//;
                $c->log->debug("Detected language: $lang");
            }

            my $handle = LANraragi::Utils::I18N->get_handle($lang);

            unless ($handle) {
                $c->log->debug("No handle for language: $lang");
                return $key;
            }

            $c->log->debug("Key: $key, Args: " . join(", ", map { defined($_) ? $_ : 'undef' } @args));

            my @encoded_args = map { Encode::encode('UTF-8', $_) } @args;

            my $translated;
            eval {
                $translated = $handle->maketext($key, @encoded_args);
            };
            if ($@) {
                $c->log->error("Maketext error: $@");
                return $key;
            }

            if ( !Encode::is_utf8($translated) ) {
                $translated = Encode::decode_utf8($translated);
            }

            $c->log->debug("Translated result: $translated");
            return $translated;
        }
    );

    $app->log->debug("I18N system initialized.");
}


1;
