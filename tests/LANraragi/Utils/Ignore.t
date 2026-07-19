use strict;
use warnings;
use utf8;

use Test::More;
binmode Test::More->builder->output, ':encoding(UTF-8)';
binmode Test::More->builder->failure_output, ':encoding(UTF-8)';
use File::Temp qw(tempdir);
use File::Spec;
use File::Path qw(make_path);
use LANraragi::Utils::Path qw(open_path_or_die);

use constant IS_UNIX => ( $^O ne 'MSWin32' );

BEGIN {
    use_ok('LANraragi::Utils::Ignore');
}

sub make_rules {
    my ($dir, @lines) = @_;
    my $file = File::Spec->catfile($dir, ".lrrignore");
    open_path_or_die( my $fh, '>:encoding(UTF-8)', $file );
    print $fh join("\n", @lines);
    close($fh);
}

# ============ *.tmp pattern (no slash) ============
{
    my $tmp = tempdir(CLEANUP => 1);
    make_path( File::Spec->catdir($tmp, "sub") );
    make_rules($tmp, "*.tmp");

    my $r = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "foo.tmp"), $r ),       "*.tmp matches foo.tmp" );
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "sub", "bar.tmp"), $r ), "*.tmp matches sub/bar.tmp" );
    ok( !LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "foo.cbz"), $r ),       "*.tmp does NOT match foo.cbz" );
    ok( !LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "foo.tmp.cbz"), $r ),   "*.tmp does NOT match foo.tmp.cbz" );
}

# ============ Directory pattern with trailing / ============
{
    my $tmp = tempdir(CLEANUP => 1);
    make_path( File::Spec->catdir($tmp, "private") );
    make_rules($tmp, "private/");

    my $r = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "private", "secret.cbz"), $r ),
        "private/* matches private/secret.cbz" );
    ok( !LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "not_private.cbz"), $r ),
        "private/* does NOT match not_private.cbz" );
}

# ============ Path boundary (a should not match ab, a/ should not match a) ============
{
    my $tmp = tempdir(CLEANUP => 1);
    make_rules($tmp, "file");

    my $r = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "file"), $r ),
        "file matches file" );
    ok( !LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "file1"), $r ),
        "file does NOT match file1" );

    # dir/ → dir/*
    make_rules($tmp, "dir/");
    my $r2 = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( !LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "dir"), $r2 ),
        "dir/ does NOT match file dir" );
}

# ============ Escape: \*, \!, \# ============
{
    my $tmp = tempdir(CLEANUP => 1);

    make_rules($tmp, 'star\*lit.tmp');
    my $r = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, 'star*lit.tmp'), $r ),
        '\* matches literal *' );
    ok( !LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, 'starlit.tmp'), $r ),
        '\* does NOT match starlit' );

    make_rules($tmp, '\!bang.tmp');
    my $r2 = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, '!bang.tmp'), $r2 ),
        '\! matches literal ! at line start' );

    make_rules($tmp, '\#tag.tmp');
    my $r3 = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, '#tag.tmp'), $r3 ),
        '\# matches literal # at line start' );
}

# ============ Anchored pattern with leading / ============
{
    my $tmp = tempdir(CLEANUP => 1);
    make_path( File::Spec->catdir($tmp, "sub") );
    make_rules($tmp, "/root.cbz");

    my $r = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "root.cbz"), $r ),
        "/root.cbz matches root-level file" );
    ok( !LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "sub", "root.cbz"), $r ),
        "/root.cbz does NOT match sub/root.cbz" );
}

# ============ Negation (!) — last matching rule wins ============
{
    my $tmp = tempdir(CLEANUP => 1);
    make_rules($tmp, "*.tmp", "!important.tmp");

    my $r = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "foo.tmp"), $r ),       "*.tmp matches foo.tmp" );
    ok( !LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "important.tmp"), $r ), "!important.tmp re-includes" );
}

# ============ Nested .lrrignore (child overrides parent) ============
{
    my $tmp = tempdir(CLEANUP => 1);
    my $sub = File::Spec->catdir($tmp, "sub");
    make_path($sub);
    make_rules($tmp, "*.tmp");
    make_rules($sub, "!keep.tmp");

    # build_ignore_rules from a file in sub loads both parent and child rules
    my $r = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "x.tmp"), $r ),
        "root *.tmp works on root file" );
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "sub", "drop.tmp"), $r ),
        "root *.tmp applies in subdir" );
    ok( !LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "sub", "keep.tmp"), $r ),
        "sub/keep.tmp re-included by child !keep.tmp" );
}

# ============ CJK paths ============
{
    my $tmp = tempdir(CLEANUP => 1);

    # Chinese
    my $cn = File::Spec->catdir($tmp, "漫画");
    make_path($cn);
    make_rules($tmp, "漫画/vol1.rar");
    my $r = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($cn, "vol1.rar"), $r ),
        "CJK: 漫画/vol1.rar matched by 漫画/vol1.rar" );
    ok( !LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($cn, "vol1.zip"), $r ),
        "CJK: 漫画/vol1.zip not matched" );

    # Japanese
    my $jp = File::Spec->catdir($tmp, "同人誌");
    make_path($jp);
    make_rules($tmp, "同人誌/C97.cbz");
    my $r2 = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($jp, "C97.cbz"), $r2 ),
        "CJK: 同人誌/C97.cbz matched by 同人誌/C97.cbz" );

    # Korean
    my $kr = File::Spec->catdir($tmp, "웹툰");
    make_path($kr);
    make_rules($tmp, "웹툰/ch01.zip");
    my $r3 = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($kr, "ch01.zip"), $r3 ),
        "CJK: 웹툰/ch01.zip matched by 웹툰/ch01.zip" );

    # CJK filename pattern
    make_rules($tmp, "漫画1.cbz");
    my $r4 = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "漫画1.cbz"), $r4 ),
        "CJK: 漫画1.cbz matched by 漫画1.cbz" );
    ok( !LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "漫画2.cbz"), $r4 ),
        "CJK: 漫画2.cbz not matched by 漫画1.cbz" );

    # CJK directory .lrrignore (nested override)
    my $sp_cn = "特别";
    utf8::encode($sp_cn) unless IS_UNIX;
    my $sp = File::Spec->catdir($tmp, $sp_cn);
    make_path($sp);
    make_rules($tmp, "过滤.tmp");
    make_rules($sp, "!保留.tmp");
    my $r5 = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($sp, "过滤.tmp"), $r5 ),
        "CJK: 过滤.tmp ignored by root 过滤.tmp" );
    ok( !LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($sp, "保留.tmp"), $r5 ),
        "CJK: 保留.tmp re-included by child !保留.tmp" );
}

# ============ Comments and empty lines ============
{
    my $tmp = tempdir(CLEANUP => 1);
    make_rules($tmp, "# comment", "", "*.cbz", "   # comment with spaces");

    my $r = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "test.cbz"), $r ), "comment lines are skipped, *.cbz works" );
}

# ============ Special characters in filenames ============
# Verify that is_ignored / find_path / abs2rel handle unusual characters gracefully.
{
    my $tmp = tempdir(CLEANUP => 1);

    my $sub = File::Spec->catdir($tmp, "sub");
    make_path($sub);
    make_rules($tmp,
        'space .tmp',
        'paren(1).tmp',
        'bracket[1].tmp',
        'curly{1}.tmp',
        'dollar$.tmp',
        'semi;.tmp',
        'pipe|.tmp',
        'caret^.tmp',
        'plus+.tmp',
        'hash#.tmp',
        'amp&.tmp',
        'tilde~.tmp',
        'at@.tmp',
        'backtick` .tmp',
        'single\'quote.tmp',
        'double"quote.tmp',
        '.leading dot.cbz',
        "emoj\x{1F4D6}.tmp",
        'sub/nested space.tmp',
        'sub/exclaim!.tmp',
    );

    my @specials = (
        'space .tmp',
        'paren(1).tmp',
        'bracket[1].tmp',
        'curly{1}.tmp',
        'dollar$.tmp',
        'semi;.tmp',
        'pipe|.tmp',
        'caret^.tmp',
        'plus+.tmp',
        'hash#.tmp',
        'amp&.tmp',
        'tilde~.tmp',
        'at@.tmp',
        'backtick` .tmp',
        'single\'quote.tmp',
        'double"quote.tmp',
        '.leading dot.cbz',
        "emoj\x{1F4D6}.tmp",
        'sub/nested space.tmp',
        'sub/exclaim!.tmp',
    );

    for my $name (@specials) {
        open( my $fh, '>', File::Spec->catfile( $tmp, $name ) );
        close($fh);
    }

    my $r = LANraragi::Utils::Ignore::build_ignore_rules($tmp);

    for my $name (@specials) {
        my $file = File::Spec->catfile( $tmp, $name );
        my $rel  = File::Spec->abs2rel( $file, $tmp );
        my $expected = 1;
        ok( LANraragi::Utils::Ignore::is_ignored( $file, $r ) == $expected,
            "special chars: $rel => " . ( $expected ? "ignored" : "scanned" ) );
    }
}

# ============ No .lrrignore file ============
{
    my $tmp = tempdir(CLEANUP => 1);
    my $r = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( !LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "foo.cbz"), $r ), "no ignore file -> nothing ignored" );
}

# ============ Specific file path ============
{
    my $tmp = tempdir(CLEANUP => 1);
    make_path( File::Spec->catdir($tmp, "backup") );
    make_rules($tmp, "backup/old.cbz");

    my $r = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    ok( LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "backup", "old.cbz"), $r ), "backup/old.cbz matches specific file" );
    ok( !LANraragi::Utils::Ignore::is_ignored( File::Spec->catfile($tmp, "backup", "new.cbz"), $r ), "backup/old.cbz does NOT match other files" );
}

# ============ Empty .lrrignore ============
{
    my $tmp = tempdir(CLEANUP => 1);
    make_rules($tmp, "", "# only comments", "   ");

    my $r = LANraragi::Utils::Ignore::build_ignore_rules($tmp);
    is( scalar keys %{ $r->{entries} }, 0, "empty .lrrignore produces empty entries" );
}

done_testing();
