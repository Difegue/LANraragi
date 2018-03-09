#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use feature qw(say);
use Digest::SHA;
use Redis;
use Encode;
#use Data::Dumper;
use Cwd 'abs_path';

#Get Redis address and DB number from argument
#Otherwise flash message
unless ( @ARGV > 0 ) {
    say("Execution: migrate-database [REDIS_ADDRESS] [DATABASE_NUMBER]");
    exit;
}

say ("LANraragi 0.4 to 0.5 Migration Tool");

my $address = $ARGV[0];
my $dbnumber  = $ARGV[1];

say ("Connecting to $address on Database $dbnumber...");

#Connect to Redis DB
my $redis = Redis->new(
        server    => $address,
        reconnect => 3
    );

#Database switch if it's not 0
if ( $dbnumber != 0 ) { $redis->select($dbnumber); }

say ("Done!");
say ("Going through IDs...");

my $json  = "[ ";
my $treated = 0;

#Go through LRR 0.4 ID (64-character long)
my @keys = $redis->keys('????????????????????????????????????????????????????????????????');    

#Iterate on hashes to get their tags
foreach my $id (@keys) {

    my %hash = $redis->hgetall($id);

    #print Dumper %hash;

    my ( $event, $artist, $title, $series, $language, $file, $tags ) =
        @hash{qw(event artist title series language file tags )};


    ( $_ = redis_decode($_) )
      for ( $event, $artist, $title, $series, $language, $tags, $file );

    #Check if file still exists
    if (-e $file) {

        say ("Found archive $title ");
        say ("Tags are $tags");
        $treated++;

        #Generate 0.5 ID from the existing File
        my $newid = compute_id($file);

        #Move fields to namespaced tags
        my $newtags = "";

        if ($event ne "") {
            $newtags .= "event: $event, ";
        }

        if ($artist ne "") {

            #Special case for circle/artist sets: If the string contains parenthesis, what's inside those is the artist name -- the rest is the circle.
            if ( $artist =~ /(.*) \((.*)\)/ ) {
                $newtags .= "group:$1, artist:$2, ";
            }
            else {
                $newtags .= "artist:$artist ";
            }

        }

        if ($series ne "") {
            $newtags .= "parody:$series, ";
        }

        if ($language ne "") {
            $newtags .= "language:$language, ";
        }

        #Keep old tags without doing any form of cleaning whatsoever
        $newtags .= $tags;

        #Make the filepath static (0.4 allowed relative filepaths)
        $file = abs_path($file);

        #Generate 0.5-compliant JSON
        $json .= qq(
                {
                    "arcid": "$newid",
                    "title": "$title",
                    "tags": "$newtags",
                    "filename": "$file"
                },);

    }


}

#remove last comma for json compliance
chop($json);

$json .= "]";

#Export to File
my $file = './migrated-data.json';
say ("Writing data to $file...");

if ( -e $file ) { unlink $file }

my $OUTFILE;

open $OUTFILE, '>>', $file;
print {$OUTFILE} $json;
close $OUTFILE;

#donezo
say("Treated $treated Files.");
say ("All done! You can import the resulting JSON into LRR 0.5 and up.");

###Subs copied from main LRR code

sub redis_decode {

    my $data = $_[0];

    eval { $data = decode_utf8($data) };
    eval { $data = decode_utf8($data) };

    return $data;
}

sub compute_id {

    my $file = $_[0];

    #Read the first 500 KBs only (allows for faster disk speeds )
    open( my $handle, '<', $file ) or die $!;
    my $data;
    my $len = read $handle, $data, 512000;
    close $handle;

    #Compute a SHA-1 hash of this data
    my $ctx = Digest::SHA->new(1);
    $ctx->add($data);
    my $digest = $ctx->hexdigest;

    return $digest;

}