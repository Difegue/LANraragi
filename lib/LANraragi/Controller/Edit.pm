package LANraragi::Controller::Edit;
use Mojo::Base 'Mojolicious::Controller';

use File::Basename;
use Redis;
use Encode;
use Template;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;

#Deletes the archive with the given id from redis, and the matching archive file.
sub delete_metadata_and_file
{

	my $id = $_[0];

	my $redis = &get_redis();

	my $filename = $redis->hget($id, "file");
	$filename = decode_utf8($filename);

	#print $filepath;
	$redis->del($id);

	#print $delcmd;
	$redis->quit();

	if (-e $filename)
	{ 
		unlink $filename; 
		return $filename; 
	}

	return "0";

}

sub save_metadata {
	my $self = shift;

	my $id = $self->param('id');
	my $event = $self->param('event');
	my $artist = $self->param('artist');
	my $title = $self->param('title');
	my $series = $self->param('series');
	my $language = $self->param('language');
	my $tags = $self->param('tags');

	#clean up the user's inputs and encode them.
	(removeSpaceF($_)) for ($event, $artist, $title, $series, $language, $tags);

	#Input new values into redis hash.
	#prepare the hash which'll be inserted.
	my %hash = (
			event => encode_utf8($event),
			artist => encode_utf8($artist),
			title => encode_utf8($title),
			series => encode_utf8($series),
			language => encode_utf8($language),
			tags => encode_utf8($tags)
		);
		
	#for all keys of the hash, add them to the redis hash $id with the matching keys.
	$redis->hset($id, $_, $hash{$_}, sub {}) for keys %hash;
	$redis->wait_all_responses;
	
	$self->render(json => {
					id => $id,
					operation => "edit", 
					success => 1
					});
}

#TODO - move to API ?
sub delete_archive {
	my $self = shift;
	my $id = $self->param('id');

	my $delStatus = &delete_metadata_and_file($id);

	$self->render(json => {
					id => $id,
					operation => "delete", 
					success => $delStatus
					});
}

sub index {
	my $self = shift;

	#Does the passed file exist in the database?
	my $id = $self->param('id');

	if ($redis->hexists($id,"title")) 
	{
		my $redis = Redis->new(server => &get_redisad, 
				reconnect => 100,
				every     => 3000);
				
		my %hash = $redis->hgetall($id);					
		my ($name,$event,$artist,$title,$series,$language,$tags,$file,$thumbhash) = @hash{qw(name event artist title series language tags file thumbhash)};
		($_ = decode_utf8($_)) for ($name, $event, $artist, $title, $series, $language, $tags, $file);

		$redis->quit();

		$self->render(  template => "templates/edit.tmpl",
  				      	id => $id,
			            name => $name,
			            event => $event,
			            artist => $artist,
			            arctitle => $title,
			            series => $series,
			            language => $language,
			            tags => $tags,
			            file => $file,
			            thumbhash => $thumbhash,
			            title => &get_htmltitle,
			            cssdrop => &printCssDropdown(0)
		  	          );
	}
	else 
		{ $self->redirect_to('index') }
}


1;
