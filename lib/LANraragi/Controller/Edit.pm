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
	my $self = $_[0];
	my $id = $_[1];
	
	my $redis = $self->LRR_CONF->get_redis();

	my $filename = $redis->hget($id, "file");
	$filename = LANraragi::Model::Utils::redis_decode($filename);

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

	my $id = $self->req->param('id');
	my $event = $self->req->param('event');
	my $artist = $self->req->param('artist');
	my $title = $self->req->param('title');
	my $series = $self->req->param('series');
	my $language = $self->req->param('language');
	my $tags = $self->req->param('tags');

	#clean up the user's inputs and encode them.
	(LANraragi::Model::Utils::remove_spaces($_)) 
		for ($event, $artist, $title, $series, $language, $tags);

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

	my $redis = $self->LRR_CONF->get_redis();

	#for all keys of the hash, add them to the redis hash $id with the matching keys.
	$redis->hset($id, $_, $hash{$_}, sub {}) for keys %hash;
	$redis->wait_all_responses;
	
	$self->render(json => {
					id => $id,
					operation => "edit", 
					success => 1
					});
}

sub delete_archive {
	my $self = shift;
	my $id = $self->req->param('id');

	my $delStatus = &delete_metadata_and_file($self, $id);

	$self->render(json => {
					id => $id,
					operation => "delete", 
					success => $delStatus
					});
}

sub index {
	my $self = shift;

	#Does the passed file exist in the database?
	my $id = $self->req->param('id');

	my $redis = $self->LRR_CONF->get_redis();

	#TODO: Fix this to use new syntax w.namespaces
	if ($redis->hexists($id,"title")) 
	{
		my %hash = $redis->hgetall($id);					
		my ($name,$event,$artist,$title,$series,$language,$tags,$file,$thumbhash) = @hash{qw(name event artist title series language tags file thumbhash)};
		($_ = LANraragi::Model::Utils::redis_decode($_)) for ($name, $event, $artist, $title, $series, $language, $tags, $file);

		$redis->quit();

		$self->render(  template => "edit",
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
			            title => $self->LRR_CONF->get_htmltitle,
			            cssdrop => LANraragi::Model::Utils::generate_themes(0)
		  	          );
	}
	else 
		{ $self->redirect_to('index') }
}


1;
