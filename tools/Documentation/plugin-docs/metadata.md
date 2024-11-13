# Metadata Plugins

Metadata plugins are the bread-n-butter of LRR plugins: For a given archive, they can look for tags in a remote service or a local file and return this info so it can be integrated into LRR's database.

## Required subroutines

Only one subroutine needs to be implemented for the module to be recognized: `get_tags`, which contains your working code. You're free to implement other subroutines for cleaner code, of course.

### Expected Input

The following section deals with writing the `get_tags` subroutine.
When executing your Plugin, LRR will call this subroutine and pass it the following variables:

```perl
sub get_tags {

    #First lines you should have in the subroutine
    # $lrr_info: global info hash, contains various metadata provided by LRR
    # $params  : plugin parameters
    shift;
    my ( $lrr_info, $params ) = @_;
```

The variables match the parameters you've entered in the `plugin_info` subroutine. \(Example here is for E-H.  )

The `$lrr_info` hash contains various variables you can use in your plugin:

* _$lrr\_info->{archive\_id}_: The internal ID of the archive.
* _$lrr\_info->{archive\_title}_: The title of the archive, as entered by the User.
* _$lrr\_info->{existing\_tags}_: The tags that are already in LRR for this archive, if there are any.
* _$lrr\_info->{thumbnail\_hash}_: A SHA-1 hash of the first image of the archive.
* _$lrr\_info->{file\_path}_: The filesystem path to the archive.
* _$lrr\_info->{oneshot\_param}_: Value of your one-shot argument, if it's been set by the User. See below.
* _$lrr\_info->{user\_agent}_: [Mojo::UserAgent](https://mojolicious.org/perldoc/Mojo/UserAgent) object you can use for web requests. If this plugin depends on a Login plugin, this UserAgent will be pre-configured with the cookies from the Login.

The `$params` hash contains the values of the user defined parameters.

#### One-Shot Arguments

The **One-Shot Argument** can be set by the user every time he uses your Plugin on a specific file, through LRR's Edit Menu.
It's more meant for special overrides you'd want to use for this specific file:
For example, in E-Hentai and nHentai plugins, it can be used to set a specific Gallery URL you want to pull tags from.

If you want the user to be able to enter this override, the `oneshot_arg` field must be present in `plugin_info`, and contain a brief description of what your argument is for.

One-Shot Arguments can only be strings.

### Expected Output

Once you're done and obtained your tags, all that's needed for LRR to handle them is to return a hash containg said tags.
Tags are expected to be separated by commas, like this:

`return ( tags => "my:new, tags:here, look ma no namespace" );`

Plugins can also modify the title or the summary of the archive:
`return ( tags => "some:tags", title=>"My new epic archive title", summary=>"Phenomenal! Wheres that David Lynch clip where he says phenomenal" );`
Those two parameters are completely optional. \(The tags one isn't, but it can very well be empty.\)
If the Plugin's user has disabled "Plugins can modify archive titles" in their settings, you can still pass a new title - It'll simply do nothing.

If you couldn't obtain tags for some reason, you can tell LRR that an error occurred by throwing an exception:

`die "my error :(\n";`

The old error handling still exists, but it's **deprecated**:

`return ( error => "my error :(" );`

If you do this, no tags will be added for this archive, and the error will be logged/displayed to the user.

## Plugin Template

```perl
package LANraragi::Plugin::Metadata::MyNewPlugin;

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
        name         => "Plugin Boilerplate",
        type         => "metadata",
        namespace    => "dummyplug",
        #login_from  => "dummylogin",
        author       => "Hackerman",
        version      => "0.001",
        description  => "This is base boilerplate for writing LRR plugins.",
        icon         => "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAABmJLR0QAAAAAAAD5Q7t/AAAACXBI\nWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH4wYDFCYzptBwXAAAAB1pVFh0Q29tbWVudAAAAAAAQ3Jl\nYXRlZCB3aXRoIEdJTVBkLmUHAAAAjUlEQVQ4y82UwQ7AIAhDqeH/f7k7kRgmiozDPKppyisAkpTG\nM6T5vAQBCIAeQQBCUkiWRTV68KJZ1FuG5vY/oazYGdcWh7diy1Bml5We1yiMW4dmQr+W65mPjFjU\n5PMg2P9jKKvUdxWMU8neqYUW4cBpffnxi8TsXk/Qs8GkGGaWhmes1ZmNmr8kuMPwAJzzZSoHwxbF\nAAAAAElFTkSuQmCC",
        #If your plugin uses/needs custom arguments, input their name here.
        #This name will be displayed in plugin configuration next to an input box for global arguments, and in archive edition for one-shot arguments.
        oneshot_arg => "This is a one-shot argument that can be entered by the user when executing this plugin on a file",
        parameters  => [
            'doomsday'   => {type => "bool", desc => "Enable the DOOMSDAY DEVICE"},
            'iterations' => {type => "int",  desc => "Number of iterations", default_value => "9001"}
        ]
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    # $lrr_info: global info hash, contains various metadata provided by LRR
    # $params  : plugin parameters
    my ( $lrr_info, $params ) = @_;

    if ($lrr_info->{oneshot_param}) {
        die "Yaaaaaaaaa gomen gomen the oneshot argument isn't implemented -- You entered ".$lrr_info->{oneshot_param}.", right ?\n";
    }

    #Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    my $logger = get_logger("My Cool Plugin","plugins");

    #Work your magic here - You can create subroutines below to organize the code better
    $logger->info("Gettin' tags");
    my $newtags = get_tags_from_somewhere($params->{iterations}, $params->{doomsday}); #To be implemented
    my $error = 0;

    #Something went wrong? Return an error.
    if ($error) {
        $logger->error("Oh no");
        die "Error Text Here\n";
    }

    #Otherwise, return the tags you've harvested.
    return ( tags => $newtags );
}

sub get_tags_from_somewhere {

    my ($iterations, $doomsday) = @_;
    my $logger = get_logger("My Cool Plugin","plugins");

    if ($doomsday) {
        die "You fools! You've messed with the natural order!\n";
    }

    $logger->info("I'm supposed to be iterating $iterations times but I don't give a damn my man");

    #Tags are expected to be submitted as a single string, containing tags split up by commas. Namespaces are optional.
    return "my:new, tags:here, look ma no namespace";
}

1;
```

### Converting existing plugins to named parameters

If you have a plugin that you want to convert to using named parameters without losing the existing configuration, you can add new key called `to_named_params` to the `plugin_info`.
The new key must contain an array of the names assigned to the old parameters in the exact sequence in which they were present before the conversion.
If you have added new parameters in the meantime, you don't have to specify them in the `to_named_params` key.

The following example shows how to convert from the old parameter structure:

```perl
    # [...]
    parameters  => [
        {type => "bool", desc => "Enable the DOOMSDAY DEVICE"},
        {type => "int",  desc => "Number of iterations", default_value => "9001"}
    ]
    # [...]
```

to the new structure:

```perl
    # [...]
    to_named_params => ['doomsday', 'iterations'],
    parameters  => {
        'iterations' => {type => "int",  desc => "Number of iterations", default_value => "9001"},
        'doomsday'   => {type => "bool", desc => "Enable the DOOMSDAY DEVICE"},
        'salvation'  => {type => "bool", desc => "Now you can be saved"}
    }
    # [...]
```

Note that `salvation` is not included in the conversion and the order of the items inside `to_named_params` corresponds to the sequence of the parameters in the old format.

The `to_named_params` key must be present the first time you load the plugin with the new parameter structure, otherwise the existing configuration will be lost. After the first use, however, it is no longer needed and you can remove it from a future version of the plugin.
