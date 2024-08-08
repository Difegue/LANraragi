use strict;
use warnings;
use utf8;
use Cwd;

use Data::Dumper;
use Test::MockObject;
use Mojo::JSON qw (decode_json);

sub setup_redis_mock {

    # DataModel for searches
    # files are set to package.json since the search engine checks for file existence and I ain't about to mock perl's -e call
    # Switch devmode to 1 for debug output in test
    my %datamodel =
      %{ decode_json qq(
        {
        "LRR_CONFIG": {
            "pagesize": "100",
            "devmode": "1"
        },
        "SET_1589141306": {
            "archives": "[\\\"e69e43e1355267f7d32a4f9b7f2fe108d2401ebf\\\",\\\"e69e43e1355267f7d32a4f9b7f2fe108d2401ebg\\\"]",
            "name": "Segata Sanshiro",
            "pinned": "1",
            "search": ""
        },
        "SET_1589138380":{
            "archives": "[]",
            "id": "SET_1589138380",
            "name": "AMERICA ONRY",
            "pinned": "0",
            "search": "American"
        },
        "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf": {
            "isnew": "false",
            "pagecount": 2,
            "progress": 10,
            "tags": "character:segata sanshiro, male:very cool",
            "title": "Saturn Backup Cartridge - Japanese Manual",
            "file": "package.json",
            "lastreadtime": 1589038280
        },
        "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg": {
            "isnew": "false",
            "pagecount": 200,
            "progress": 34,
            "tags": "character:segata, female:very cool too",
            "title": "Saturn Backup Cartridge - American Manual",
            "file": "package.json",
            "lastreadtime": 1589038281
        },
        "e4c422fd10943dc169e3489a38cdbf57101a5f7e": {
            "isnew": "true",
            "pagecount": 10,
            "progress": 0,
            "tags": "parody: jojo's bizarre adventure",
            "title": "Rohan Kishibe goes to Gucci",
            "file": "package.json",
            "lastreadtime": 0
        },
        "4857fd2e7c00db8b0af0337b94055d8445118630": {
            "isnew": "false",
            "pagecount": 34,
            "progress": 34,
            "tags": "artist:shirow masamune",
            "title": "Ghost in the Shell 1.5 - Human-Error Processor vol01ch01",
            "file": "package.json",
            "lastreadtime": 1589038280
        },
        "2810d5e0a8d027ecefebca6237031a0fa7b91eb3": {
            "isnew": "false",
            "pagecount": 34,
            "progress": 34,
            "tags": "parody:fate grand order,  character:abigail williams,  character:artoria pendragon alter,  character:asterios,  character:ereshkigal,  character:gilgamesh,  character:hans christian andersen,  character:hassan of serenity,  character:hector,  character:helena blavatsky,  character:irisviel von einzbern,  character:jeanne alter,  character:jeanne darc,  character:kiara sessyoin,  character:kiyohime,  character:lancer,  character:martha,  character:minamoto no raikou,  character:mochizuki chiyome,  character:mordred pendragon,  character:nitocris,  character:oda nobunaga,  character:osakabehime,  character:penthesilea,  character:queen of sheba,  character:rin tosaka,  character:saber,  character:sakata kintoki,  character:scheherazade,  character:sherlock holmes,  character:suzuka gozen,  character:tamamo no mae,  character:ushiwakamaru,  character:waver velvet,  character:xuanzang,  character:zhuge liang,  group:wadamemo,  artist:wada rco,  artbook,  full color",
            "title": "Fate GO MEMO 2",
            "file": "package.json",
            "lastreadtime": 1589038280
        },
        "28697b96f0ac5858be2614ed10ca47742c9522fd": {
            "isnew": "false",
            "pagecount": 1,
            "progress": 0,
            "tags": "parody:fate grand order,  group:wadamemo,  artist:wada rco,  artbook,  full color, male:very cool too",
            "title": "Fate GO MEMO",
            "file": "package.json",
            "lastreadtime": 0
        },
        "28697b96f0ac5777be2614ed10ca47742c9522fa": {
            "isnew": "false",
            "pagecount": 128,
            "progress": 0,
            "tags": "year of shadow, character:vector the crocodile",
            "title": "Find the Computer Room",
            "file": "package.json",
            "lastreadtime": 0
        },
        "28697b96f0ac5858be2666ed10ca47742c955555": {
            "isnew": "false",
            "pagecount": 22,
            "progress": 0,
            "tags": "medjed, character:doubles guy, character:king of GETs, check this 5",
            "title": "All about Egypt",
            "file": "package.json",
            "lastreadtime": 0
        },
        "TANK_1589141306": [
            "Hello",
            "28697b96f0ac5858be2666ed10ca47742c955555",
            "28697b96f0ac5777be2614ed10ca47742c9522fa"
        ],
        "TANK_1589138380":[
            "World",
            "28697b96f0ac5777be2614ed10ca47742c9522fa"
        ]
    })
      };

    # Mock Redis object which uses the datamodel
    my $redis = Test::MockObject->new();
    $redis->mock(
        'keys',    # $redis->keys => get keys matching predicate in datamodel
        sub {
            shift;

            # Replace redis' '?' wildcards with regex '.'s
            my $expr = $_[0] =~ s/\?/\./gr;

            # Replace redis' '*' wildcards with regex '.*'s
            $expr = $expr =~ s/\*/\.\*/gr;
            return grep { /$expr/ } keys %datamodel;
        }
    );
    $redis->mock( 'exists',  sub { shift; return $_[0] eq "LRR_SEARCHCACHE" ? 0 : 1 } );
    $redis->mock( 'hexists', sub { 1 } );
    $redis->mock( 'hset',    sub { 1 } );
    $redis->mock( 'quit',    sub { 1 } );
    $redis->mock( 'select',  sub { 1 } );
    $redis->mock( 'flushdb', sub { 1 } );
    $redis->mock( 'zincrby', sub { 1 } );
    $redis->mock( 'zrem',    sub { 1 } );
    $redis->mock( 'watch',   sub { 1 } );
    $redis->mock( 'hlen',    sub { 1337 } );
    $redis->mock( 'dbsize',  sub { 1337 } );

    $redis->mock(
        'multi',
        sub {
            my $self = shift;
            $self->{ismulti} = 1;
        }
    );

    $redis->mock(
        'exec',
        sub {
            my $self = shift;
            $self->{ismulti} = 0;
            my @a = values @{ $self->{results} };

            # Return the values directly to match Redis module behavior, instead of boxing them in an array
            return @a;
        }
    );

    $redis->mock(
        'hget',    # $redis->hget => get value of key in datamodel
        sub {
            my $self = shift;
            my ( $key, $hashkey ) = @_;

            my $value = $datamodel{$key}{$hashkey};
            return $value;
        }
    );

    $redis->mock(
        'sadd',    # $redis->sadd => add value to list named by key in datamodel
        sub {
            my $self = shift;
            my ( $key, $value ) = @_;

            if ( !exists $datamodel{$key} ) {
                $datamodel{$key} = [];
            }

            if ( !grep { $_ eq $value } @{ $datamodel{$key} } ) {
                push @{ $datamodel{$key} }, $value;
            }

            push @{ $datamodel{$key} }, $value;
        }
    );

    $redis->mock(
        'zadd',    # $redis->zadd => add value to list named by key in datamodel
        sub {
            my $self = shift;
            my ( $key, $weight, $value ) = @_;

            if ( !exists $datamodel{$key} ) {
                $datamodel{$key} = [];
            }

            # Don't push value if it's already in the array
            if ( !grep { $_ eq $value } @{ $datamodel{$key} } ) {
                push @{ $datamodel{$key} }, $value;
            }
        }
    );

    $redis->mock(
        'zcard',    # $redis->zcard => number of values in list named by key in datamodel
        sub {
            my $self = shift;
            my ($key) = @_;

            if ( !exists $datamodel{$key} ) {
                $datamodel{$key} = [];
            }

            return scalar @{ $datamodel{$key} };
        }
    );

    $redis->mock(
        'scard',    # $redis->scard => number of values in list named by key in datamodel
        sub {
            my $self = shift;
            my ($key) = @_;

            if ( !exists $datamodel{$key} ) {
                $datamodel{$key} = [];
            }

            return scalar @{ $datamodel{$key} };
        }
    );

    # $redis->mock(
    #     'zscore',    # $redis->zscore => array position in list named by key in datamodel
    #     sub {
    #         my $self = shift;
    #         my ($key, $value) = @_;

    #         if ( !exists $datamodel{$key} ) {
    #             $datamodel{$key} = [];
    #         }

    #         for my $i ( 0 .. $#results ) {
    #             if ($element == $value) {
    #                 return
    #             }
    #         }

    #         return scalar @{ $datamodel{$key} };
    #     }
    # );

    $redis->mock(
        'zrangebylex',    # $redis->zrangebylex => get all values of key in datamodel
        sub {
            my $self = shift;
            my ( $key, $start, $end ) = @_;

            if ( !exists $datamodel{$key} ) {
                $datamodel{$key} = [];
            }

            # Return array, ordered alphabetically
            return sort @{ $datamodel{$key} };
        }
    );

    $redis->mock(
        'zrangebyscore',    # $redis->zrangebyscore => get all values of key in datamodel
        sub {
            my $self = shift;
            my ( $key, $start, $end ) = @_;

            if ( !exists $datamodel{$key} ) {
                $datamodel{$key} = [];
            }

            if ($end eq "+inf") {
                $end = scalar @{ $datamodel{$key} };
            }

            # Skip $start amount of elements
            my @res = @{ $datamodel{$key} }[ $start .. $end ];
            # Add index after each element to simulate zrangebyscore behavior
            my @indexed_res;
            my $ind = $start;
            foreach my $val (@res) {
                unless ($val) {
                    next;
                }
                push @indexed_res, $val;
                push @indexed_res, $ind;
                $ind++;
            }

            return @indexed_res;
        }
    );

    $redis->mock(
        'zscan',    # $redis->zscan => get all values of key in datamodel
        sub {
            my $self = shift;
            my ( $key, $cursor, $match, $matchexpr, $count, $countnumber ) = @_;

            if ( !exists $datamodel{LRR_TITLES} ) {
                $datamodel{LRR_TITLES} = [];
            }

            # Search for the match expression in the list of titles
            # Replace redis' '?' wildcards with regex '.'s
            my $expr = $matchexpr =~ s/\?/\./gr;

            # Replace redis' '*' wildcards with regex '.*'s
            $expr = $expr =~ s/\*/\.\*/gr;

            my @matches = grep { /$expr/i } @{ $datamodel{LRR_TITLES} };

            # Return 0 for cursor to indicate we scanned everything, and
            return ( 0, \@matches );
        }
    );

    $redis->mock(
        'smembers',    # $redis->smembers => return all values of key in datamodel
        sub {
            my $self = shift;
            my ($key) = @_;

            if ( !exists $datamodel{$key} ) {
                $datamodel{$key} = [];
            }

            return @{ $datamodel{$key} };
        }
    );

    $redis->mock(
        'hgetall',    # $redis->hgetall => get all values of key in datamodel
        sub {
            my $self = shift;
            my $key  = shift;

            my @value = %{ $datamodel{$key} };

            if ( $self->{ismulti} ) {
                push @{ $self->{results} }, \@value;
                return 1;
            } else {
                return @value;
            }
        }
    );

    $redis->fake_module( "Redis", new => sub { $redis } );
}

sub get_logger_mock {
    my ($args) = @_;
    my $mock = Test::MockObject->new();
    $mock->mock(
        'error', sub { push( @{$args}, [ 'error', @_ ] ) if ($args); },
        'info',  sub { push( @{$args}, [ 'info',  @_ ] ) if ($args); },
        'debug', sub { push( @{$args}, [ 'debug', @_ ] ) if ($args); },
        'trace', sub { push( @{$args}, [ 'trace', @_ ] ) if ($args); }
    );
    return $mock;
}

1;
