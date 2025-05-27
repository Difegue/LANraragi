package LANraragi::Plugin::Metadata::ComicInfoNhentaiChine;

use strict;
use warnings;

use utf8;
binmode(STDOUT, ":encoding(UTF-8)");

use Mojo::DOM;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);
use LANraragi::Utils::String  qw(trim);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "ComicInfo nhentai Chine",
        type        => "metadata",
        namespace   => "comicInfonhentaichine",
        author      => "Gin-no-kami & luolili233",
        version     => "1.2.2",
        description => "解析档案中嵌入的 ComicInfo.xml 的元数据，仅对使用nhentai程序下载的档案有效",
        parameters  => []
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;    # Global info hash, contains various metadata provided by LRR

    #Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    my $logger = get_plugin_logger();

    my $file            = $lrr_info->{file_path};
    my $path_in_archive = is_file_in_archive( $file, "ComicInfo.xml" );

    die "No ComicInfo.xml file found in the archive\n" if ( !$path_in_archive );

    #Extract ComicInfo.xml
    my $filepath = extract_file_from_archive( $file, $path_in_archive );

    #Read file into string
    my $stringxml = "";
    open( my $fh, '<:encoding(UTF-8)', $filepath )
      or die "Could not open $filepath!\n";
    while ( my $line = <$fh> ) {
        chomp $line;
        $stringxml .= $line;
    }

    #Parse file into DOM object and extract tags
    
    #新添加
    my $title;
    my $yuanbiaoti;
    my $yuanzhu;
    my $juese;
    my $zuozhe;
    my $shetuan;
    my $biaoqian;
    my $chuban;
    my $leixing;
    my $heibai;
    my $fanyi;
    my $laiyuan;

    #原版
    my $genre;
    my $calibretags;
    my $group;
    my $url;
    my $artist;
    my $lang;
    my $series;
    my $character;
    my $publisher;

    my $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Title');
    if ( defined $result ) {
        $title = $result->text;
    }
    #原标题
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Summary');
    if ( defined $result ) {
        $yuanbiaoti = $result->text;
    }
    #原著
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Series');
    if ( defined $result ) {
        $yuanzhu = $result->text;
    }
    #角色
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Characters');
    if ( defined $result ) {
        $juese = $result->text;
    }
    #作者
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Writer');
    if ( defined $result ) {
        $zuozhe = $result->text;
    }
    #社团
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Groups');
    if ( defined $result ) {
        $shetuan = $result->text;
    }
    #标签
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Tags');
    if ( defined $result ) {
        $biaoqian = $result->text;
    }
    #出版
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Publisher');
    if ( defined $result ) {
        $chuban = $result->text;
    }
    #类型
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Genre');
    if ( defined $result ) {
        $leixing = $result->text;
    }
    #黑白
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('BlackAndWhite');
    if ( defined $result ) {
        $heibai = $result->text;
    }
    #翻译
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('LanguageISO');
    if ( defined $result ) {
        $fanyi = $result->text;
    }
    #来源
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('URL');
    if ( defined $result ) {
        $laiyuan = $result->text;
    }


    #Delete local file
    unlink $filepath;

    #Add prefix and concatenate
    my @found_tags;
    @found_tags = try_add_tags( \@found_tags, "\x{539F}\x{6807}\x{9898}:", $yuanbiaoti );
    @found_tags = try_add_tags( \@found_tags, "\x{539F}\x{8457}:", $yuanzhu );
    @found_tags = try_add_tags( \@found_tags, "\x{89D2}\x{8272}:", $juese );
    @found_tags = try_add_tags( \@found_tags, "\x{4F5C}\x{8005}:", $zuozhe );
    @found_tags = try_add_tags( \@found_tags, "\x{793E}\x{56E2}:", $shetuan );
    @found_tags = try_add_tags( \@found_tags, "\x{6807}\x{7B7E}:", $biaoqian );
    @found_tags = try_add_tags( \@found_tags, "\x{51FA}\x{7248}:", $chuban );
    @found_tags = try_add_tags( \@found_tags, "\x{7C7B}\x{578B}:", $leixing );
    @found_tags = try_add_tags( \@found_tags, "\x{9ED1}\x{767D}:", $heibai );
    @found_tags = try_add_tags( \@found_tags, "\x{7FFB}\x{8BD1}:", $fanyi );
    @found_tags = try_add_tags( \@found_tags, "\x{6765}\x{6E90}:", $laiyuan );
    push( @found_tags, "language:" . $lang ) unless !$lang;
    my @genres = split( ',', $genre // "" );

    if ($calibretags) {
        push @genres, split( ',', $calibretags );
    }
    foreach my $genre_tag (@genres) {
        push( @found_tags, trim($genre_tag) );
    }
    my $tags = join( ", ", @found_tags );
    my $yuanzhu = join( ", ", @found_tags );
    my $juese = join( ", ", @found_tags );
    my $zuozhe = join( ", ", @found_tags );
    my $shetuan = join( ", ", @found_tags );
    my $biaoqian = join( ", ", @found_tags );

    $logger->info("Sending the following tags to LRR: $tags");
    return ( tags => $tags, title => $title );
}

sub try_add_tags {
    my @found_tags = @{ $_[0] };
    my $prefix     = $_[1];
    my $tags       = $_[2] // "";

    my @tags_array = split( ',', $tags );

    foreach my $tag (@tags_array) {
        push( @found_tags, $prefix . trim($tag) );
    }
    return @found_tags;
}

1;
