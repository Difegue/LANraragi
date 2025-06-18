package LANraragi::Plugin::Metadata::EHDLInfo;

use v5.36;
use strict;
use warnings;
use Time::Piece;

use LANraragi::Model::Plugins;
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::String  qw(trim);
use LANraragi::Utils::Tags    qw(split_tags_to_array);

my $metadata_file = "info.txt";
my $S_INFO        = 1;
my $S_TAGS        = 2;
my $S_FLAT        = 3;

sub plugin_info {
    return (
        name        => "EHDL info.txt",
        type        => "metadata",
        namespace   => "ehd-info",
        author      => "IceBreeze",
        version     => "1.0",
        description => "EHDL info.txt metadata parser",

        #icon => "",
        parameters => {
            'replace_title'  => { type => "bool", desc => "Replace the title with the one in the metadata file" },
            'japanese_title' => { type => "bool", desc => "Use Japanese title if available" },
            'save_summary'   => { type => "bool", desc => "Save \"description\" as summary" },
        },
    );
}

sub get_tags {
    my ( undef, $lrr_info, $params ) = @_;
    my $logger = get_plugin_logger();

    my $archive = $lrr_info->{file_path};
    my %hashdata;

    if ( is_file_in_archive( $archive, $metadata_file ) ) {

        %hashdata = read_file( extract_file_from_archive( $archive, $metadata_file ), $params );

        if ( !$params->{'replace_title'} ) { delete $hashdata{'title'} }
        if ( !$params->{'save_summary'} )  { delete $hashdata{'summary'} }

        $logger->info( "Sending the following tags to LRR: " . $hashdata{tags} );

    }

    return %hashdata;
}

sub read_file {
    my ( $metafile, $params ) = @_;

    open( my $fh, '<:encoding(UTF-8)', $metafile )
      or die "Could not open $metafile!\n";

    my %hashdata;
    my %tags;
    my $count           = 0;
    my $reading_section = $S_INFO;
    while ( my $line = <$fh> ) {
        $line = trim($line);

        if ( !$line ) {
            $count++;
            next;
        } elsif ( $count == 0 ) {

            # try guessing the file format
            if ( $line =~ /^(description|title)\:(.*)/g ) {

                my $ns = ( $1 eq 'title' ) ? 'title' : 'summary';
                $hashdata{$ns} = trim($2);
                $reading_section = $S_FLAT;

            } else {
                $hashdata{'title'} = $line;
            }

        } elsif ( $reading_section == $S_INFO && $count == 1 && $params->{'japanese_title'} ) {
            $hashdata{'title'} = $line;    # expecting the original title
        } elsif ( $reading_section == $S_INFO && $count == 2 ) {

            # if this isn't the gallery URL, then the file format is unknown
            if ( $line =~ /^https\:\/\/(e.hentai\.org\/g\/[0-9]*\/[0-z]*)\/*.*/gi ) {
                $tags{'source'} = $1;
            } else {
                close($fh);
                unlink($metafile);
                die "Unknown file format";
            }

        } elsif ( $reading_section == $S_INFO ) {
            if    ( $line =~ m/^Category: (.*)/ ) { $tags{'category'}  = trim($1); }
            elsif ( $line =~ m/^Posted: (.*)/ )   { $tags{'timestamp'} = convert_to_epoch( trim($1) ); }
            elsif ( $line =~ m/^Language: ([a-z]*)/i ) { $tags{'language'} = lc($1); }    # this will be replaced if translated
            elsif ( $line =~ m/^Tags:/ ) { $reading_section = $S_TAGS; }
        } elsif ( $reading_section == $S_TAGS ) {
            if ( $line =~ /^> ([a-z]*):(.*)/gi ) {
                $tags{$1} = [ split_tags_to_array($2) ];
            } else {
                last;                                                                     # nothing useful anymore
            }
        } elsif ( $reading_section == $S_FLAT ) {
            if ( $line =~ /^([a-z]*):(.*)/g ) {
                my $ns    = $1;
                my $value = trim($2);
                if ( exists $tags{$ns} ) {
                    push @{ $tags{$ns} }, $value;
                } elsif ( $1 eq 'title' ) {
                    $hashdata{'title'} = trim($2);
                } elsif ( $1 eq 'description' ) {
                    $hashdata{'summary'} = trim($2);
                } else {
                    $tags{$ns} = [$value];
                }
            }
        }
        $count++;
    }
    close($fh);
    unlink($metafile);

    $hashdata{'tags'} = join( ',', hash_to_array( \%tags ) );

    return %hashdata;
}

sub hash_to_array {
    my ($hash_tags) = @_;
    my @array;
    while ( my ( $ns, $value ) = each %$hash_tags ) {
        if    ( !$value )                { push @array, $ns; }
        elsif ( $ns eq 'tag' )           { push @array, join( ',', @$value ); }
        elsif ( ref($value) eq 'ARRAY' ) { push @array, "$ns:$_" for @$value; }
        else                             { push @array, "$ns:$value"; }
    }
    @array = sort @array;
    return @array;
}

sub convert_to_epoch {
    my ($datetime) = @_;
    return Time::Piece->strptime( $datetime, "%Y-%m-%d %H:%M" )->epoch;
}
