package LANraragi::Plugin::Metadata::HDoujin;

use strict;
use warnings;

# Plugins can freely use all Perl packages already installed on the system
# Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::JSON qw(from_json);

# You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);

# Meta-information about your plugin.
sub plugin_info {

    return (
        # Standard metadata
        name        => "HDoujin",
        type        => "metadata",
        namespace   => "hdoujinplugin",
        author      => "Pao, Squidy",
        version     => "0.6",
        description => "Collects metadata embedded into your archives by HDoujin Downloader's JSON or TXT files.",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI\nWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH4wYDFB0m9797jwAAAB1pVFh0Q29tbWVudAAAAAAAQ3Jl\nYXRlZCB3aXRoIEdJTVBkLmUHAAAEbklEQVQ4y1WUPW/TUBSGn3uvHdv5cBqSOrQJgQ4ghqhCAgQM\nIIRAjF2Y2JhA/Q0g8R9YmJAqNoZKTAwMSAwdQEQUypeQEBEkTdtUbdzYiW1sM1RY4m5Hunp1znmf\n94jnz5+nAGmakiQJu7u7KKWwbRspJWma0m63+fHjB9PpFM/z6Ha7FAoFDMNga2uLx48fkyQJ29vb\nyCRJSNMUz/PY2dnBtm0qlQpKKZIkIQgCer0eW1tbDIdDJpMJc3NzuK5Lt9tF13WWl5dJkoRyuYyU\nUrK3t0ccx9TrdQzD4F/HSilM08Q0TWzbplqtUqvVKBaLKKVoNpt8/vyZKIq4fv064/EY2ev1KBQK\n2LadCQkhEEJkteu6+L6P7/tMJhOm0ylKKarVKjdu3GA6nXL+/HmSJEHWajV0Xf9P7N8TQhDHMWEY\nIoRgOBzieR4At2/f5uTJk0RRRLFYZHZ2liNHjqBFUcRoNKJarSKlRAiRmfPr1y/SNMVxHI4dO8aF\nCxfI5/O4rotSirdv33L16lV+//7Nly9fUEqh5XI5dF0nTdPMaSEEtm3TaDSwLAvLstB1nd3dXUql\nEqZpYlkW6+vrdLtdHjx4wPb2NmEYHgpalkUQBBwcHLC2tsbx48cpFos4jkMQBIRhyGQyYTgcsrGx\nQavVot1uc+LECcbjMcPhkFKpRC6XQ0vTlDAMieOYQqGA4zhcu3YNwzDQdR3DMA4/ahpCCPL5fEbC\nvXv3WFlZ4c+fP7TbbZaWlpBRFGXjpmnK/Pw8QRAwnU6RUqJpGp7nMRqNcF0XwzCQUqKUolwus7y8\njO/7lMtlFhcX0YQQeJ6XMXfq1Cn29/epVCrouk4QBNi2TalUIoqizLg0TQEYjUbU63VmZmYOsdE0\nDd/3s5HH4zG6rtNsNrEsi0qlQqFQYH19nVevXjEej/8Tm0wmlMtlhBAMBgOkaZo0Gg329vbY2dkh\nCIJsZ0oplFK8efOGp0+fcvHiRfL5PAAHBweEYcj8/HxGydevX5FxHDMajajVanz69Ik4jkmSBF3X\n0TSNzc1N7t69S6vV4vXr10gp8X2f4XBIpVLJghDHMRsbG2jT6TRLxuLiIr1eDwBN09A0jYcPHyKE\n4OjRo8RxTBRF9Pt95ubmMud93+f79+80m03k/v4+UspDKDWNRqPBu3fvSNOUtbU16vU6ly5dwnEc\ncrkcrutimib5fD4zxzRNVldXWVpaQqysrKSdTofLly8zmUwoFAoIIfjXuW3bnD17NkuJlBLHcdA0\nDYAgCHj27BmO47C6uopM05RyucyLFy/QNA3XdRFCYBgGQRCwubnJhw8fGAwGANRqNTRNI0kSXr58\nyc2bN6nX64RhyP379xFPnjxJlVJIKTl37hydTocoiuh0OszOzmJZFv1+n8FgwJ07d7hy5Qrj8ZiP\nHz/S7/c5ffo0CwsL9Ho9ZmZmEI8ePUoNwyBJEs6cOcPCwgLfvn3j/fv35PN5bNtGKZUdjp8/f3Lr\n1q3svLVaLTzPI4oiLMviL7opJdyaltNwAAAAAElFTkSuQmCC",
        parameters => []
    );

}

# Mandatory function to be implemented by your plugin
sub get_tags {

    shift;

    my $lrr_info = shift; # Global info hash

    my $logger = get_plugin_logger();
    my $archive_file_path = $lrr_info->{file_path};

    my $path_in_archive = is_file_in_archive($archive_file_path, "info.json");

    if($path_in_archive) {
        return get_tags_from_hdoujin_json_file($archive_file_path, $path_in_archive);
    }

    $path_in_archive = is_file_in_archive($archive_file_path, "info.txt");

    if($path_in_archive) {
        return get_tags_from_hdoujin_txt_file($archive_file_path, $path_in_archive);
    }

    return (error => "No HDoujin metadata files found in this archive!");

}

sub get_tags_from_hdoujin_txt_file {

    my $archive_file_path = $_[0];
    my $path_in_archive = $_[1];

    my $logger = get_plugin_logger();

    # Extract info.txt
    my $file_path = extract_file_from_archive($archive_file_path, $path_in_archive);

    # Open it
    open(my $file_handle, '<:encoding(UTF-8)', $file_path)
        or return (error => "Could not open $file_path!");

    my $tags = "";
    my $summary = "";

    while (my $line = <$file_handle>) {

        if ($line =~ m/(ARTIST|AUTHOR|CIRCLE|CHARACTERS|DESCRIPTION|LANGUAGE|PARODY|SERIES|TAGS): (.*)/) {

            my $namespace = $1;
            my $value = $2;

            $value =~ s/^\s+|\s+$//g;

            if($value eq "") {
                next;
            }

            if($namespace eq "CHARACTERS") {
                $namespace = "CHARACTER";
            } 
            elsif($namespace eq "TAGS") {
                $namespace = "";
            }

            if($namespace eq "DESCRIPTION") {
                $summary = $value;
            }
            else {
                $tags = append_tags($tags, $namespace, $value);
            }

        }

    }

    # Delete it
    unlink $file_path;

    if ($tags eq "") {
        return (error => "No tags were found in info.txt!");
    }

    # Return tags
    $logger->info("Sending the following tags to LRR: $tags");

    return (tags => remove_duplicates($tags), summary => $summary);

}

sub get_tags_from_hdoujin_json_file {

    my $archive_file_path = $_[0];
    my $path_in_archive = $_[1];

    my $logger = get_plugin_logger();

    # Extract info.json
    my $file_path = extract_file_from_archive($archive_file_path, $path_in_archive);

    my $json_str = "";

    # Open it
    open(my $file_handle, '<:encoding(UTF-8)', $file_path)
        or return (error => "Could not open $file_path!");

    while (my $row = <$file_handle>) {

        chomp $row;

        $json_str .= $row;

    }

    #Use Mojo::JSON to decode the string into a hash
    my $json_hash = from_json $json_str;

    $logger->debug("Found and loaded the following JSON: $json_str");

    #Parse it
    my $tags = get_tags_from_hdoujin_json_hash($json_hash);

    #Delete it
    unlink $file_path;

    #Return tags
    $logger->info("Sending the following tags to LRR: $tags");

    return (tags => $tags);

}

#get_tags_from_hdoujin_json(decodedjson)
#Goes through the JSON hash obtained from an info.json file and return the contained tags.
sub get_tags_from_hdoujin_json_hash {

    my $hash = $_[0];
    my $return = "";

    #HDoujin jsons are composed of a main manga_info object, containing fields for every metadata.
    #Those fields can contain either a single tag or an array of tags.

    my $tags = $hash->{"manga_info"};

    #Take every key in the manga_info hash, except for title which we're already processing

    my @filtered_keys = grep { $_ ne "tags" and $_ ne "title" } keys(%$tags);

    foreach my $namespace (@filtered_keys) {

        my $members = $tags->{$namespace};

        if ( ref($members) eq 'ARRAY' ) {

            foreach my $tag (@$members) {

                $return .= ", " unless $return eq "";
                $return .= $namespace . ":" . $tag unless $members eq "";

            }

        } else {

            $return .= ", " unless $return eq "";
            $return .= $namespace . ":" . $members unless $members eq "";

        }

    }

    my $tagsobj = $hash->{"manga_info"}->{"tags"};

    if ( ref($tagsobj) eq 'HASH' ) {

        return $return . "," . tags_from_wRespect($hash);

    } else {

        return $return . "," . tags_from_noRespect($hash);

    }

}

sub tags_from_wRespect {

    my $hash   = $_[0];
    my $return = "";
    my $tags   = $hash->{"manga_info"}->{"tags"};

    foreach my $namespace ( keys(%$tags) ) {

        my $members = $tags->{$namespace};
        foreach my $tag (@$members) {

            $return .= ", " unless $return eq "";
            $return .= $namespace . ":" . $tag;

        }
    }

    return $return;

}

sub tags_from_noRespect {

    my $hash   = $_[0];
    my $return = "";
    my $tags   = $hash->{"manga_info"};

    my @filtered_keys = grep { /^tags/ } keys(%$tags);

    foreach my $namespace (@filtered_keys) {

        my $members = $tags->{$namespace};

        if ( ref($members) eq 'ARRAY' ) {

            foreach my $tag (@$members) {

                $return .= ", " unless $return eq "";
                $return .= $namespace . ":" . $tag;

            }

        }

    }

    return $return;

}

sub append_tags {

    my $tags = $_[0];
    my $namespace = $_[1];
    my $append = $_[2];

    my @split_tags = split(/,/, $append);

    for my $tag (@split_tags) {

        $tag =~ s/^\s+|\s+$//g;

        if($tag eq "") {
            next;
        }

        if($namespace ne "") {
            $tag = lc($namespace) . ":" . $tag;
        }

        $tags .= ", " unless $tags eq "";
        $tags .= $tag;

    }

    return $tags;

}

sub remove_duplicates {

    # The tags list may contain tags duplicated in fields, so it's likely to encounter duplicates.

    my $tags = $_[0];
    my @split_tags = split(/,/, $tags);

    my %seenTags;
    my @uniqueTags;

    for my $tag (@split_tags) {

        $tag =~ s/^\s+|\s+$//g;

        next if $seenTags{lc($tag)}++;

        push(@uniqueTags, $tag);

    }

    return join(", ", @uniqueTags);

}

1;
