package LANraragi::Plugin::Metadata::HDoujin;

use strict;
use warnings;

# Plugins can freely use all Perl packages already installed on the system
# Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::JSON qw(from_json);

# You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::String qw(trim_url);

# Meta-information about your plugin.
sub plugin_info {

    return (
        # Standard metadata
        name        => "HDoujin",
        type        => "metadata",
        namespace   => "Hdoujinplugin",
        author      => "Pao, Squidy",
        version     => "0.7",
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

    if ($path_in_archive) {
        return get_tags_from_hdoujin_json_file($archive_file_path, $path_in_archive);
    }

    $path_in_archive = is_file_in_archive($archive_file_path, "info.txt");

    if ($path_in_archive) {
        return get_tags_from_hdoujin_txt_file($archive_file_path, $path_in_archive);
    }

    return (error => "No HDoujin metadata files found in this archive!");

}

sub get_tags_from_hdoujin_txt_file {

    my $archive_file_path = $_[0];
    my $path_in_archive = $_[1];

    my $logger = get_plugin_logger();

    my $file_path = extract_file_from_archive($archive_file_path, $path_in_archive);

    open(my $file_handle, '<:encoding(UTF-8)', $file_path)
        or return (error => "Could not open $file_path!");

    my $title = "";
    my $tags = "";
    my $summary = "";

    while (my $line = <$file_handle>) {

        if ($line =~ m/(?i)^(artist|author|circle|characters?|description|language|parody|series|tags|title|url): (.*)/) {

            my $namespace = normalize_namespace($1);
            my $value = $2;

            $value =~ s/^\s+|\s+$//g;

            if ($value eq "") {
                next;
            }

            if(lc($namespace) eq "source") {
                $value = trim_url($value);
            }

            if (lc($namespace) eq "description") {
                $summary = $value;
            }
            elsif(lc($namespace) eq "title") {
                $title = $value;
            }
            else {
                $tags = append_tags($tags, $namespace, $value);
            }

        }

    }

    unlink $file_path;

    if ($tags eq "") {
        return (error => "No tags were found in info.txt!");
    }

    $logger->info("Sending the following tags to LRR: $tags");

    return (title => $title, tags => remove_duplicates($tags), summary => $summary);

}

sub get_tags_from_hdoujin_json_file {

    my $archive_file_path = $_[0];
    my $path_in_archive = $_[1];

    my $logger = get_plugin_logger();

    my $file_path = extract_file_from_archive($archive_file_path, $path_in_archive);
    my $json_str = "";

    open(my $file_handle, '<:encoding(UTF-8)', $file_path)
        or return (error => "Could not open $file_path!");

    while (my $row = <$file_handle>) {

        chomp $row;
        $json_str .= $row;

    }

    my $json_hash = from_json $json_str;

    $logger->debug("Found and loaded the following JSON: $json_str");

    # Note that fields may be encapsulated in an outer "manga_info" object if the user has enabled this.
    # Each field can contain either a single tag or an array of tags.

    if (exists $json_hash->{"manga_info"}) {
        $json_hash = $json_hash->{"manga_info"};
    }

    my $title = $json_hash->{"title"};
    my $tags = get_tags_from_hdoujin_json_file_hash($json_hash);
    my $summary = $json_hash->{"description"};

    unlink $file_path;

    if ($tags eq "") {
        return (error => "No tags were found in info.json!");
    }

    $logger->info("Sending the following tags to LRR: $tags");

    return (title => $title, tags => remove_duplicates($tags), summary => $summary);

}

sub get_tags_from_hdoujin_json_file_hash {

    my $json_obj = $_[0];
    my $tags = "";

    my $logger = get_plugin_logger();

    my @filtered_keys = grep { /(?i)^(?:artist|author|circle|characters?|language|parody|series|tags|url)/ } keys(%$json_obj);

    foreach my $key (@filtered_keys) {

        my $namespace = normalize_namespace($key);
        my $values = $json_obj->{$key};

        if(lc($namespace) eq "source") {
            $values = trim_url($values);
        }

        if (ref($values) eq 'ARRAY') {

            # We have an array of values (e.g. author, artist, language, and character fields).

            foreach my $tag (@$values) {
                $tags = append_tags($tags, $namespace, $tag);
            }

        }
        elsif (ref($values) eq 'HASH') {

            # We have a map of keyed values (e.g. tags with namespace arrays enabled).

            foreach my $nestedNamespace (keys(%$values)) {

                my $nestedValues = $values->{$nestedNamespace};

                foreach my $tag (@$nestedValues) {
                    $tags = append_tags($tags, normalize_namespace($nestedNamespace), $tag);
                }

            }

        } 
        else {

            # We have a basic string value (e.g. series).

            $tags = append_tags($tags, $namespace, $values);

        }

    }

    return $tags;

}

sub append_tags {

    my $tags = $_[0];
    my $namespace = $_[1];
    my $append = $_[2];

    my @split_tags = split(/,/, $append);

    for my $tag (@split_tags) {

        $tag =~ s/^\s+|\s+$//g;

        if ($tag eq "") {
            next;
        }

        if ($namespace ne "") {
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

sub normalize_namespace {

    my $namespace = lc($_[0]);
    
    if ($namespace eq "characters") {
        return "character";
    } 
    elsif ($namespace eq "misc") {
        return "other";
    }
    elsif ($namespace eq "tags") {
        return "";
    }
    elsif ($namespace eq "url") {
        return "source";
    }

    return $namespace;

}

1;
