package LANraragi::Plugin::Login::EHentai;

use strict;
use warnings;
no warnings 'uninitialized';

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::UserAgent;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "E-Hentai",
        type        => "login",
        namespace   => "ehlogin",
        author      => "Difegue",
        version     => "2.2",
        description => "Handles login to E-H. If you have an account that can access fjorded content or exhentai, adding the credentials here will make more archives available for parsing.",
        icon        => "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI\nWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH4wYBFg0JvyFIYgAAAB1pVFh0Q29tbWVudAAAAAAAQ3Jl\nYXRlZCB3aXRoIEdJTVBkLmUHAAAEo0lEQVQ4y02UPWhT7RvGf8/5yMkxMU2NKaYIFtKAHxWloYNU\ncRDeQTsUFPwAFwUHByu4ODq4Oghdiri8UIrooCC0Lx01ONSKfYOioi1WpWmaxtTm5PTkfNzv0H/D\n/9oeePjdPNd13Y8aHR2VR48eEUURpmmiaRqmaXbOAK7r4vs+IsLk5CSTk5P4vo9hGIgIsViMra0t\nCoUCRi6XY8+ePVSrVTRN61yybZuXL1/y7t078vk8mUyGvXv3cuLECWZnZ1lbW6PdbpNIJHAcB8uy\nePr0KYZlWTSbTRKJBLquo5TCMAwmJia4f/8+Sini8Ti1Wo0oikin09i2TbPZJJPJUK/XefDgAefO\nnWNlZQVD0zSUUvi+TxAE6LqOrut8/fqVTCaDbdvkcjk0TSOdTrOysoLrujiOw+bmJmEYMjAwQLVa\nJZVKYXR1ddFut/F9H9M0MU0T3/dZXV3FdV36+/vp7u7m6NGj7Nq1i0qlwuLiIqVSib6+Pubn5wGw\nbZtYLIaxMymVSuH7PpZlEUURSina7TZBEOD7Pp8/fyYMQ3zfZ25ujv3795NOp3n48CE9PT3ouk4Q\nBBi/fv3Ctm0cx6Grq4utrS26u7sREQzDIIoifv78SU9PD5VKhTAMGRoaYnV1leHhYa5evUoQBIRh\niIigiQhRFKHrOs1mE9u2iaKIkydPYhgGAKZp8v79e+LxOPl8Htd1uXbtGrdv3yYMQ3ZyAODFixeb\nrVZLvn//Lq7rSqVSkfX1dREROXz4sBw/flyUUjI6OipXrlyRQ4cOSbPZlCiKxHVdCcNQHMcRz/PE\ndV0BGL53756sra1JrVaT9fV1cRxHRESGhoakr69PUqmUvHr1SsrlsuzI931ptVriuq78+fNHPM+T\nVqslhoikjh075p09e9ba6aKu6/T39zM4OMjS0hIzMzM0Gg12794N0LEIwPd9YrEYrusShiEK4Nmz\nZ41yudyVy+XI5/MMDAyQzWap1+tks1lEhIWFBQqFArZto5QiCAJc1+14t7m5STweRwOo1WoSBAEj\nIyMUi0WSySQiQiqV6lRoYWGhY3673e7sfRAEiAjZbBbHcbaBb9++5cCBA2SzWZLJJLZt43kesViM\nHX379g1d1wnDsNNVEQEgCAIajQZ3797dBi4tLWGaJq7rYpompVKJmZkZ2u12B3j58mWUUmiahoiw\nsbFBEASdD2VsbIwnT55gACil+PHjB7Ozs0xPT/P7929u3ryJZVmEYUgYhhQKBZRSiAie52EYBkop\nLMvi8ePHTE1NUSwWt0OZn5/3hoeHzRs3bqhcLseXL1+YmJjowGzbRtO07RT/F8jO09+8ecP58+dJ\nJBKcPn0abW5uThWLRevOnTv/Li4u8vr1a3p7e9E0jXg8zsePHymVSnz69Kmzr7quY9s2U1NTXLp0\nCc/zOHLkCPv27UPxf6rX63+NjIz8IyKMj48zPT3NwYMHGRwcpLe3FwARodVqcf36dS5evMj4+DhB\nEHDmzBkymQz6DqxSqZDNZr8tLy//DYzdunWL5eVlqtUqHz58IJVKkUwmaTQalMtlLly4gIjw/Plz\nTp06RT6fZ2Njg/8AqMV7tO07rnsAAAAASUVORK5CYII=",
        parameters  => [
            {type => "int",    desc =>  "ipb_member_id cookie"},
            {type => "string", desc =>  "ipb_pass_hash cookie"},
            {type => "string", desc =>  "star cookie (optional, if present you can view fjorded content without exhentai)"}
        ]
    );

}

# Mandatory function to be implemented by your login plugin
# Returns a Mojo::UserAgent object only!
sub do_login {

    # Login plugins only receive the parameters entered by the user.
    shift;
    my ( $ipb_member_id, $ipb_pass_hash, $star) = @_;
    return get_user_agent($ipb_member_id, $ipb_pass_hash, $star);
}

# get_user_agent(ipb cookies)
# Try crafting a Mojo::UserAgent object that can access E-Hentai.
# Returns the UA object created.
sub get_user_agent {

    my ($ipb_member_id, $ipb_pass_hash, $star) = @_;

    my $logger = get_logger( "E-Hentai Login", "plugins" );
    my $ua = Mojo::UserAgent->new;

    if ($ipb_member_id ne "" && $ipb_pass_hash ne "") {
        $logger->info( "Cookies provided ($ipb_member_id $ipb_pass_hash $star)!");

        #Setup the needed cookies with both domains
        #They should translate to exhentai cookies with the igneous value generated
        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'ipb_member_id',
                value  => $ipb_member_id,
                domain => 'exhentai.org',
                path   => '/'
            )
        );

        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'ipb_member_id',
                value  => $ipb_member_id,
                domain => 'e-hentai.org',
                path   => '/'
            )
        );

        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'ipb_pass_hash',
                value  => $ipb_pass_hash,
                domain => 'exhentai.org',
                path   => '/'
            )
        );

        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'ipb_pass_hash',
                value  => $ipb_pass_hash,
                domain => 'e-hentai.org',
                path   => '/'
            )
        );

        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'star',
                value  => $star,
                domain => 'exhentai.org',
                path   => '/'
            )
        );

        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'star',
                value  => $star,
                domain => 'e-hentai.org',
                path   => '/'
            )
        );

        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'ipb_coppa',
                value  => '0',
                domain => 'forums.e-hentai.org',
                path   => '/'
            )
        );
    } else {
        $logger->info( "No cookies provided, returning blank UserAgent.");
    }

    return $ua;

}

1;
