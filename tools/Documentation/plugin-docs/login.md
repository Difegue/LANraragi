# Login Plugins

Login Plugins mostly play a support role: They can be called by all other plugins: Metadata, Downloader and Script Plugins.
Their role is to provide a configured [Mojo::UserAgent](https://mojolicious.org/perldoc/Mojo/UserAgent) object that can be used to perform authenticated operations on a remote Web service.

## Required subroutines

Only one subroutine needs to be implemented for the module to be recognized: `do_login`, which contains your working code. You're free to implement other subroutines for cleaner code, of course.

### Expected Input

When executing your Plugin, LRR will call the `do_login` subroutine and give it the following variables:

```perl
sub do_login {

    #First line you should have in the subroutine
    my (undef, $params) = @_; # Plugin parameters
```

The `$params` hash contains the values of the user defined parameters.

### Expected Output

Your plugin must return a [Mojo::UserAgent](https://mojolicious.org/perldoc/Mojo/UserAgent) object. That's it!

There's no particular error handling for Login Plugins at the moment, so I recommend you return an empty UserAgent if Login fails and handle the error in the matching Metadata/Script plugin.

## Plugin Template

```perl
package LANraragi::Plugin::Login::MyNewPlugin;

use strict;
use warnings;

use Mojo::UserAgent;
use LANraragi::Utils::Logging qw(get_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name  => "Login Plugin",
        type  => "login",
        namespace => "dummylogin",
        author => "Hackerman",
        version  => "0.001",
        description => "This is base boilerplate for writing LRR plugins.",
        #If your plugin uses/needs custom arguments, input their name here.
        #This name will be displayed in plugin configuration next to an input box.
        parameters  => {
            'loginenabled' => {type => "bool",   desc => "Enable logging in to service X", default_value => "1"},
            'uid'          => {type => "int",    desc => "User ID"},
            'password'     => {type => "string", desc => "Password"}
        }
    );

}

# Mandatory function to be implemented by your login plugin
# Returns a Mojo::UserAgent object only!
sub do_login {

    # Login plugins only receive the parameters entered by the user.
    my ( undef, $params ) = @_;

    my $logger = get_logger( "Undernet Login", "plugins" );
    my $ua = Mojo::UserAgent->new;

    if ($params->{loginenabled}) {

        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'userID',
                value  => $params->{uID},
                domain => 'example.com',
                path   => '/'
            )
        );

        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'password',
                value  => $params->{password},
                domain => 'example.com',
                path   => '/'
            )
        );

    } else {
        $logger->info( "No cookies provided, returning blank UserAgent.");
    }

    return $ua;
}

1;
```

### Converting existing plugins to named parameters

If you have a plugin that you want to convert to using named parameters check [Converting existing plugins to named parameters](metadata.md#converting-existing-plugins-to-named-parameters) in the [Metadata](./metadata.md) section.
