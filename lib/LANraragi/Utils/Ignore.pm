package LANraragi::Utils::Ignore;

use strict;
use warnings;
use utf8;
use feature qw(signatures state);
no warnings 'experimental::signatures';

use File::Spec;
use File::Basename qw(dirname basename);
use Config;

use LANraragi::Utils::Path    qw(open_path find_path create_path);
use LANraragi::Utils::String  qw(trim);
use Storable                  qw(nfreeze thaw);

use Exporter 'import';
our @EXPORT_OK = qw(
    is_ignored
    build_ignore_rules
    initialize
    load_ignore_rules
);

use constant IS_UNIX => ( $Config{osname} ne 'MSWin32' );

# Called at server startup to scan .lrrignore files and store rules in Redis.
sub initialize {
    my $redis = LANraragi::Model::Config->get_redis_config;
    my $rules = build_ignore_rules( LANraragi::Model::Config->get_userdir );
    $redis->set( "LRR_IGNORE_RULES", nfreeze($rules) );
    $redis->quit();
}

# Load cached ignore rules from Redis.
# Rules are immutable at runtime; they only change when the server restarts.
sub load_ignore_rules {
    state $cached = do {
        my $redis = LANraragi::Model::Config->get_redis_config;
        my $data  = $redis->get("LRR_IGNORE_RULES");
        $redis->quit();
        return undef unless $data;

        # compile regexp
        my $rules = thaw($data);
        for my $patterns (values %{ $rules->{entries} }) {
            for my $p (@$patterns) {
                $p->{regex} = qr{$p->{regex}};
            }
        }
        return $rules;
    };
    return $cached;
}

# Scan the content directory for .lrrignore files and build rule entries.
sub build_ignore_rules ($content_dir) {
    $content_dir =~ s{\\}{/}g unless IS_UNIX;
    my $rules = {
        content_dir => $content_dir,
        entries     => {},
    };

    my @lrrignore_dirs;
    find_path(
        sub {
            my $f = create_path($_);
            return if -d $f;
            return unless basename($f) eq '.lrrignore';
            push @lrrignore_dirs, dirname($f);
        },
        $content_dir
    );

    for my $dir (@lrrignore_dirs) {
        load_ignore_file( $dir, $rules->{entries} );
    }

    return $rules;
}

# Rules data structure:
# $rules = {
#     content_dir => $path,                      # Root content directory for scanning
#     entries     => {                           # Hash map: dir -> patterns
#         $path => [                             # Parsed patterns from a single .lrrignore file
#             {
#                 pattern  => "*.tmp",           # Original pattern string
#                 regex    => qr/.../i,          # Compiled regex for matching
#                 negation => 0|1,               # 1 = ! re-include, 0 = ignore
#             },
#             ...
#         ],
#         ...
#     },
# }
#
sub is_ignored ($file, $rules) {
    return 0 unless $rules;

    my $entries = $rules->{entries};
    return 0 unless $entries && keys %$entries;

    return 0 unless is_subpath($file, $rules->{content_dir});

    my $d = dirname($file);
    while (1) {
        if ( my $patterns = $entries->{$d} ) {
            my $rel = File::Spec->abs2rel( $file, $d );
            $rel =~ s{\\}{/}g unless IS_UNIX;
            utf8::decode($rel);
            my $result;
            for my $rule ( @$patterns ) {
                next unless $rel =~ $rule->{regex};
                $result = $rule->{negation} ? 0 : 1;
            }
            return $result if defined $result;
        }
        last if $d eq $rules->{content_dir};
        $d = dirname($d);
    }
    return 0;
}

sub load_ignore_file ($dir, $entries) {
    my $ignore = File::Spec->catfile( $dir, ".lrrignore" );
    return unless -f $ignore;
    my @parsed = parse_ignore_file($ignore);
    return unless @parsed;
    $entries->{$dir} = \@parsed;
}

sub parse_ignore_file ($path) {
    my @patterns;

    open_path( my $fh, '<:encoding(UTF-8)', $path ) or return @patterns;
    my @lines = <$fh>;
    close($fh);

    for my $line (@lines) {
        $line = trim($line);
        next if $line eq '';
        next if $line =~ /^#/;

        my $negation = 0;
        if ( $line =~ s/^!// ) { $negation = 1; }

        my $regex = glob_to_regex($line);
        next unless defined $regex;

        push @patterns, {
            pattern  => $line,
            regex    => $regex,
            negation => $negation,
        };
    }

    return @patterns;
}

sub glob_to_regex ($pattern_str) {

    my $match_dir = 0;
    if ( $pattern_str =~ s{/$}{} ) { $match_dir = 1; }

    my $anchored = 0;
    if ( $pattern_str =~ s{^\.?/}{} ) { $anchored = 1; }

    return () if $pattern_str eq '';

    $pattern_str = join '[^/]*', map {
        quotemeta($_ =~ s/\\(.)/$1/gr);
    } split(/(?<!\\)\*/, $pattern_str, -1);

    if (!$anchored) {
        $pattern_str = '(?:.+/)?' . $pattern_str;
    }
    if ( $match_dir ) {
        $pattern_str .= '/.*';
    }

    return ( '(?i)^' . $pattern_str . '$' );
}

sub is_subpath ($path, $parent) {
    $parent =~ s{/+$}{};
    return 0 if $path eq $parent;
    return index( $path, $parent . '/' ) == 0;
}
  
1;
