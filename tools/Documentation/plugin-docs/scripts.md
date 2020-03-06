# Script Plugins

Script Plugins are meant for generic workflows that aren't explicitly supported.  
The main usecase is essentially for users to script their own API endpoints, since those plugins can easily be invoked through the [Client API.](extending-lanraragi/client-api.md)  

## Required subroutines

Only one subroutine needs to be implemented for the module to be recognized: `run_script `, which contains your working code. You're free to implement other subroutines for cleaner code, of course.  

### Expected Input

The following section deals with writing the `run_script` subroutine.  
When executing your Plugin, LRR will call this subroutine and pass it the following variables:

```perl
sub get_tags {

    #First lines you should have in the subroutine
    shift;
    my $lrr_info = shift; # Global info hash
    my ($param1, $param2) = @_; # Plugin parameters

```

The variables match the parameters you've entered in the `plugin_info` subroutine.

The `$lrr_info` hash contains two variables you can use in your plugin:  

* _$lrr_info->{oneshot_param}_: Value of your one-shot argument, if it's been set by the User. See below.
* _$lrr_info->{user_agent}_: [Mojo::UserAgent](https://mojolicious.org/perldoc/Mojo/UserAgent) object you can use for web requests. If this plugin depends on a Login plugin, this UserAgent will be pre-configured with the cookies from the Login.

#### One-Shot/Runtime Arguments

Scripts can have one string argument given to them when executed.   

If you want the user to be able to enter this override, the `oneshot_arg` field must be present in `plugin_info`, and contain a brief description of what your argument is for.

### Expected Output

LRR expects Scripts to return a hash, containing the results of whatever operations they ran.  
This hash is then projected back to the user.  

`return (total => $filtered, partial_ids => \@ids );`

If your script errored out, you can tell LRR that an error occurred by returning a hash containing an "error" field:

`return ( error => "my error :(" );`

If you do this, the error will be logged/displayed to the user.


## Plugin Template

```perl
package LANraragi::Plugin::Script::MyNewPlugin;

use strict;
use warnings;

# Plugins can freely use all Perl packages already installed on the system 
# Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::UserAgent;

# You can also use LRR packages when fitting.
# All packages are fair game, but only functions explicitly exported by the Utils packages are supported between versions.
# Everything else is considered internal API and can be broken/renamed between versions.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Script Boilerplate",
        type        => "script",
        namespace   => "dummyscript",
        author      => "Hackerman",
        version     => "0.1",
        description => "This is base boilerplate for writing LRR scripts. Uses JSONPlaceholder to return bogus data.",
        icon        => "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAABZSURBVDhPzY5JCgAhDATzSl+e/2irOUjQSFzQog5hhqIl3uBEHPxIXK7oFXwVE+Hj5IYX4lYVtN6MUW4tGw5jNdjdt5bLkwX1q2rFU0/EIJ9OUEm8xquYOQFEhr9vvu2U8gAAAABJRU5ErkJggg==",
        oneshot_arg => "ID argument for https://jsonplaceholder.typicode.com/",
        parameters  => [
            {type => "bool", desc => "Use posts instead of todos (jsonplaceholder)"}
        ]

    );

}

## Mandatory function to be implemented by your script
sub run_script {
    shift;
    my $lrr_info = shift; # Global info hash 
    my ($useposts) = @_; # Plugin parameters

    my $logger = get_logger( "Source Finder", "plugins" );

    # Get the runtime parameter
    my $id = $lrr_info->{oneshot_param};

    my $url = "";
    $logger->debug("useposts =  " . $useposts );
    if ($useposts) {
        $url = "https://jsonplaceholder.typicode.com/posts/$id";
    } else {
        $url = "https://jsonplaceholder.typicode.com/todos/$id";
    }

    $logger->debug("Loading  " . $url );

    if ($id eq "") {
        return ( error => "No ID specified!"); 
    }

    # Use the provided useragent
    my $ua = $lrr_info->{user_agent};

    my $res = $ua->get($url)->result;

    if ($res->is_success)  {
        # Return the response JSON directly.
         return %{$res->json}; 
    }
    elsif ($res->is_error) { 
        return ( error => $res->message );  
    }
    
}

1;
```  
