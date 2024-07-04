package LANraragi::Plugin::Metadata::ComicInfoToEhviewer;

use strict;
use warnings;

use Mojo::DOM;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);

#Meta-information about your plugin.
sub plugin_info {
    return (
        name         => "ComicInfoToEhviewer",
        type         => "metadata",
        namespace    => "ComicInfoToEhviewer",
        author       => "Ariadust",
        version      => "1.0",
        description  => "Based on the modification of the original comicinfo plugin,adapted to read the comicinfo obtained from the FooIbar version Ehviewer download file",
        parameters   => []
    );
}

#Mandatory function to be implemented by your plugin
sub get_tags {
    shift;
    my $lrr_info = shift; # Global info hash, contains various metadata provided by LRR

    my $logger = get_plugin_logger();

    my $file = $lrr_info->{file_path};
    my $path_in_archive = is_file_in_archive($file, "ComicInfo.xml");

    if ($path_in_archive) {
        my $filepath = extract_file_from_archive($file, $path_in_archive);
        my $stringxml = "";
        open(my $fh, '<:encoding(UTF-8)', $filepath)
          or return (error => "Could not open $filepath!");
        while (my $line = <$fh>) {
            chomp $line;
            $stringxml .= $line;
        }

        my $genre;
        my $group;
        my $url;
        my $artist;
        my $lang;
        my $teams;
        my $characters;
        my $alternate_series;
        
        my $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Genre');
        if (defined $result) {                  
            $genre = $result->text;
        }
        $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Web');
        if (defined $result) {
            $url = $result->text;
        }
        $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Writer');
        if (defined $result) {
            $group = $result->text;
        }
        $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Penciller');
        if (defined $result) {
            $artist = $result->text;
        }
        $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('LanguageISO');
        if (defined $result) {
            $lang = $result->text;
        }
        $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Teams');
        if (defined $result) {
            $teams = $result->text;
        }
        $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Characters');
        if (defined $result) {
            $characters = $result->text;
        }
        $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('AlternateSeries');
        if (defined $result) {
            $alternate_series = $result->text;
        }

        unlink $filepath;

        my @found_tags;
        @found_tags = try_add_tags(\@found_tags, "group:", $group);
        @found_tags = try_add_tags(\@found_tags, "artist:", $artist);
        @found_tags = try_add_tags(\@found_tags, "source:", $url);

        if ($lang) {
            $lang = convert_language($lang);
            push(@found_tags, "language:" . $lang);
        }

        @found_tags = try_add_tags(\@found_tags, "parody:", $teams);
        @found_tags = try_add_tags(\@found_tags, "character:", $characters);

        my @genres = split(',', $genre);
        foreach my $genre_tag (@genres) {
            $genre_tag = trim($genre_tag);
            if ($genre_tag =~ /^f:/) {
                $genre_tag =~ s/^f:/female:/;
            } elsif ($genre_tag =~ /^x:/) {
                $genre_tag =~ s/^x:/mixed:/;
            } elsif ($genre_tag =~ /^m:/) {
                $genre_tag =~ s/^m:/male:/;
            }else {
        $genre_tag = "other:" . $genre_tag;  # 如果没有命中任何一项，则在开头添加 other:
        }
            push(@found_tags, $genre_tag);
        }
        my $tags = join(", ", @found_tags);

        $logger->info("Sending the following tags to LRR: $tags");
        return (tags => $tags , title => $alternate_series );
    }
    
    return (error => "No ComicInfo.xml file found in archive");
}

sub convert_language {
    my $lang = shift;
    my %lang_map = (
        'zh' => 'chinese',
        'en' => 'english',
        'ja' => 'japanese',
        'fr' => 'french',
        'de' => 'german',
        'es' => 'spanish',
        'it' => 'italian',
        'pt' => 'portuguese',
        'ru' => 'russian',
        'ko' => 'korean',
        'ar' => 'arabic',
        'hi' => 'hindi',
        'bn' => 'bengali',
        'pa' => 'punjabi',
        'jv' => 'javanese',
        'ms' => 'malay',
        'vi' => 'vietnamese',
        'th' => 'thai',
        'tr' => 'turkish',
        'fa' => 'persian',
        'pl' => 'polish',
        'uk' => 'ukrainian',
        # Add more language mappings as needed
    );
    return $lang_map{$lang} // $lang;
}

sub try_add_tags {
    my @found_tags = @{$_[0]};
    my $prefix = $_[1];
    my $tags = $_[2];
    my @tags_array = split(',', $tags);

    foreach my $tag (@tags_array) {             
        push(@found_tags, $prefix . trim($tag));
    }
    return @found_tags;
}

sub trim { 
    my $s = shift; 
    $s =~ s/^\s+|\s+$//g;
    return $s;
}

1;