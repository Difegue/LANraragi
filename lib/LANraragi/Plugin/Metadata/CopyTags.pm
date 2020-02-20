package LANraragi::Plugin::Metadata::CopyTags;

use strict;
use warnings;

use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Tag Copier",
        type        => "metadata",
        namespace   => "copytags",
        author      => "Difegue",
        version     => "2.1",
        description => "Apply custom tag modifications.",
        icon        => "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAACXBIWXMAAAsTAAALEwEAmpwYAAAA\nB3RJTUUH4wYCFQ05iQtpeQAAAB1pVFh0Q29tbWVudAAAAAAAQ3JlYXRlZCB3aXRoIEdJTVBkLmUH\nAAAD8ElEQVQ4y4WUW2yURRTHfzPfty2UWrZbqdrdhktowQAJiQ/iDUwkaFJ5IAQfGjWBByMhwYAm\nBH3xqT5ArARS9cUgJC1qjCDxCY1JEy6lLVJrW9lKq6Wlgcqy2W7b/S4zx4fdbstFneRMZjLJb/7n\nf86MOn78+MlEIvE6gIhgRRARECGTmaS0tJT6+vrvo7HKxserq6f4v9Hc3PyxiBh5yBgYGJBUKiW/\n9vZKV/eVb7s6OyN79uxhbGwMKVx8f2gRUUEQEAQhfhDg+wGeHxAaA8DZs2e50tVNZ+flJ3v7B8ra\n29uJx+M0NTXhed6DCg8dPtzs+77xfV883xfP8yVXCM/zxA9CCcNQzv3402+bX96yuK2tjd27dxOP\nx2loaCCdTj+gkIJlICAFLz0vx/RMjmx2kunpaXK5nF5au3RJb29fzdq162ouX+p4ZHh4mO3bt98j\n0DU2n5oUZqUUvudz8cIFEvEEoQkRIBarXLFr584frLVmdHRUj4yNXu3r69tbVVV1u7W1lcbGxjxQ\njMzjKxAw1rJoURlr1q7B9wMEQaFKBerDwMfzPKKLo6t+uXp12Z07d16pq6tL79ixg0gkgjamkCv5\nvItKUfkrFCilmN0orZmayrJgQSlDQ0NPHz3WskhrTXd3NwBaxBR8m007v7aza+a8RQTXcaipTTAx\nMYHn+2SnJ4nFYgwODuaBRmxB3FylEEGsLRKliBZcHSFVkSFVOUWiOk5uxiObzZJKpfJAa8wciPvA\nzIflzxSKW+EtDgx8wKUbXVSYcuM4TtEWba1VSkGkJILruvmIuFibh2gNjtI4SuNqB6XBVQ7jFTdo\nK/+GiWemNmmt59omFouNfXf6dLsIalZZGJrI6lV1zwIcOP8hQ871YsE0mpRJUVFWTnZ5WjpSF09t\n+WhbJdf4DMDdv2/foYMHDx46c+YMW7dupba2lutDw1UrV674G+B3/xr9VT1gVLFMWjk4SoOg/ope\nZyo9/elzq1/QQIs7v8u11oyMjFBTU6OszKas0I4D6t4nG1qDAqwWJnWG0IbrAdz737ZSCmsNUvAw\nmAnxJsxcHyEoV+FUgDiWhXfL2RS89FXdtSfeYss8oDEGz/Ow1mKMQReq9vXmE4SSVyPAAl3KiT9b\n2X/7XZZMPcbz9sWTl94/9+bn63vUXvaKCxCGIclkkmQyCcCxlhZJ/jHI3XR60hqjpdinloiUSJ/0\nlZQuLC/Z0L9B4n2V73zR08ORXUcEyFd2fHycTCZT7KWLHR3q5s3xyslMxlhrlYjklVvLuv6V/tE3\nTr29vGzZxlffe+q1jV82hObRwFZXVxONRvnXn/e/ounCJzU/z5yPPOzsH4cGnEj6mhLzAAAAAElF\nTkSuQmCC",
        parameters  => [
            {type => "string", desc => "Tags to copy, separated by commas."}
        ]
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift; 
    my %lrr_info = shift; # Global info hash 
    my ($tagstocopy) = @_; # Plugin parameters

    my $logger = get_logger( "Tag Copy", "plugins" );

    #Tags to copy is the first global argument
    $logger->debug("Sending the following tags to LRR: " . $tagstocopy );
    return ( tags => $tagstocopy );

}

1;
