package LANraragi::Plugin::Metadata::MEMS;

use strict;
use warnings;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use LANraragi::Utils::Logging qw(get_logger);

# Meta-information about the plugin.
sub plugin_info {
  return (
    # Standard metadata:
    name => 'Mayriad\'s EH Master Script',
    type => 'metadata',
    namespace => 'memsplugin',
    login_from => 'ehlogin',
    author => 'Mayriad',
    version => '1.0.0',
    description => 'Accurately retrieves metadata from e-hentai.org using the identifiers appeneded to the filenames '
      . 'of archives downloaded by Mayriad\'s EH Master Script.',
    icon => 'data:image/png;base64,AAABAAEAEBAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAD/'
      . '//8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///w'
      . 'D///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wARBmb/EQZm/xEGZv8RBmb/EQZm/////wD///8A////ABEG'
      . 'Zv8RBmb/////AP///wARBmb/EQZm/////wD///8AEQZm/xEGZv8RBmb/EQZm/xEGZv////8A////AP///wARBmb/EQZm/////wD///8AEQZm/x'
      . 'EGZv////8A////ABEGZv8RBmb/////AP///wD///8A////AP///wD///8AEQZm/xEGZv////8A////ABEGZv8RBmb/////AP///wARBmb/EQZm'
      . '/////wD///8A////AP///wD///8A////ABEGZv8RBmb/////AP///wARBmb/EQZm/////wD///8AEQZm/xEGZv////8A////AP///wD///8A//'
      . '//AP///wARBmb/EQZm/////wD///8AEQZm/xEGZv////8A////ABEGZv8RBmb/EQZm/xEGZv////8AEQZm/xEGZv////8AEQZm/xEGZv8RBmb/'
      . 'EQZm/xEGZv8RBmb/////AP///wARBmb/EQZm/xEGZv8RBmb/////ABEGZv8RBmb/////ABEGZv8RBmb/EQZm/xEGZv8RBmb/EQZm/////wD///'
      . '8AEQZm/xEGZv////8A////AP///wD///8A////AP///wARBmb/EQZm/////wD///8AEQZm/xEGZv////8A////ABEGZv8RBmb/////AP///wD/'
      . '//8A////AP///wD///8AEQZm/xEGZv////8A////ABEGZv8RBmb/////AP///wARBmb/EQZm/////wD///8A////AP///wD///8A////ABEGZv'
      . '8RBmb/////AP///wARBmb/EQZm/////wD///8AEQZm/xEGZv8RBmb/EQZm/xEGZv////8A////AP///wARBmb/EQZm/////wD///8AEQZm/xEG'
      . 'Zv////8A////ABEGZv8RBmb/EQZm/xEGZv8RBmb/////AP///wD///8AEQZm/xEGZv////8A////ABEGZv8RBmb/////AP///wD///8A////AP'
      . '///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////'
      . 'AP///wD///8A////AP///wD///8A////AP///wD///8A//8AAP//AACDmQAAg5kAAJ+ZAACfmQAAn5kAAISBAACEgQAAn5kAAJ+ZAACfmQAAg5'
      . 'kAAIOZAAD//wAA//8AAA==',
    # Custom arguments:
    oneshot_arg => 'Enter a valid EH gallery URL to copy metadata from this EH gallery to this LANraragi archvie',
    parameters  => [
      {type => 'bool', desc =>  'Save the original Japanese title when available instead of the English or romanised '
        . 'title'},
      {type => 'bool', desc =>  'Save additional timestamp (time posted) and uploader metadata'},
      {type => 'bool', desc =>  'Use ExHentai link for source instead of E-Hentai link'}
    ]
  );
}

# Mandatory function implemented by every plugin.
sub get_tags {
  shift;
  my $lrr_info = shift;
  my ($save_jpn_title, $save_additional_metadata, $use_exhentai) = @_;
  my $logger = get_logger('Mayriad\'s EH Master Script', 'plugins');
  my $gallery_id = '';
  my $gallery_token = '';

  # Use the URL from oneshot parameters or source tag first when applicable.
  if ($lrr_info->{oneshot_param} =~ /e(?:x|-)hentai\.org\/g\/(\d+)\/([0-9a-z]+)/i) {
    $gallery_id = $1;
    $gallery_token = $2;
    $logger->debug("Directly using gallery ID $gallery_id and token $gallery_token from oneshot parameters.");
  } elsif ($lrr_info->{existing_tags} =~ /source:e(?:x|-)hentai\.org\/g\/(\d+)\/([0-9a-z]+)/i) {
    $gallery_id = $1;
    $gallery_token = $2;
    $logger->debug("Directly using gallery ID $gallery_id and token $gallery_token from source tag.");
  } else {
    # Use the gallery ID and token in the filename to directly locate the gallery. Note that the regex does not have "$"
    # at the end, so the filename can have other information attached after the identifiers.
    ($gallery_id, $gallery_token) = ($lrr_info->{archive_title} =~ /.+? \[GID (\d+) GT ([0-9a-z]+)\]/);
    if ($gallery_id eq '' || $gallery_token eq '') {
      my $file_error = "Skipping archive without connecting to EH, because the archive title does not have valid "
        . "gallery identifiers from Mayriad\'s EH Master Script.";
      $logger->error($file_error);
      return (error => $file_error);
    }
  }

  # Retrieve metadata directly using EH API.
  my ($eh_all_tags, $eh_title, $error) = &get_eh_metadata($gallery_id, $gallery_token, $save_jpn_title,
    $save_additional_metadata);
  if ($error ne '') {
    $logger->error($error);
    return (error => $error);
  }

  # Put all metadata together and add them to LRR.
  $logger->info("Sending the following tags to LRR: $eh_all_tags");
  my %metadata = (tags => $eh_all_tags);
  # Add the source tag outside get_eh_metadata(), so that this tag is only added when metadata has been successfully
  # retrieved; otherwise $metadata{tags} may only contain this source tag and truly untagged galleries would be
  # incorrectly hidden.
  my $host = ($use_exhentai ? 'exhentai.org' : 'e-hentai.org');
  $metadata{tags} .= ", source:$host/g/$gallery_id/$gallery_token";
  # Title is always updated to hide the identifiers and also to reflect title changes due to rename petitions.
  $metadata{title} = $eh_title;
  # Return a hash containing the new metadata to be added to LRR.
  return %metadata;
}

# get_eh_metadata($gallery_id, $gallery_token, $save_jpn_title, $save_additional_metadata)
# Sends an EH API gallery metadata request and extracts metadata from the returned JSON.
sub get_eh_metadata {
  my ($gallery_id, $gallery_token, $save_jpn_title, $save_additional_metadata) = @_;
  my $api = 'https://api.e-hentai.org/api.php';
  my $user_agent = Mojo::UserAgent->new;
  my $logger = get_logger('Mayriad\'s EH Master Script', 'plugins');

  # Send the API request.
  my $response = $user_agent->post(
    $api => json => {
      method => 'gdata',
      gidlist => [[$gallery_id, $gallery_token]],
      namespace => 1
    }
  )->result;

  # Check for temporary ban and warning messages.
  my $response_text = $response->body;
  if (index($response_text, 'You are opening pages too fast' ) != -1) {
    # Not sure whether this warning actually shows up in practice, but it is included in case it will help.
    $logger->info('Sleeping for five minutes because you have been warned by EH for making excessive requests.');
    sleep(300);
  }
  if (index($response_text, 'Your IP address has been temporarily banned') != -1) {
    return ('', '', 'Failed to retrieve metadata because you have been temporarily banned from EH for excessive '
      . 'requests.');
  }

  my $response_json = $response->json;
  $logger->debug("Received JSON from EH API: $response_text");
  if (exists $response_json->{'error'}) {
    my $error = $response_json->{'error'};
    return ('', '', "Received error from EH API: $error");
  }

  # Extract metadata.
  my $data = $response_json->{'gmetadata'};
  # "title_jpn" is always in the json returned by the EH API. It is empty when the gallery does not have it.
  my $eh_title = @$data[0]->{($save_jpn_title ? 'title_jpn' : 'title')};
  if ($eh_title eq '' && $save_jpn_title) {
    $eh_title = @$data[0]->{'title'};
  }
  my $eh_tags = @$data[0]->{'tags'};
  my $eh_category = lc @$data[0]->{'category'};
  my $eh_all_tags = join(', ', @$eh_tags) . ', category:' . $eh_category;
  if ($save_additional_metadata) {
    # "uploader:" is effectively a searchable namespace on EH and also useful in LANraragi. "posted:" is named
    # "timestamp:" here to let it have its own namespace abbreviation "t:"; this namespace will be useful when LANraragi
    # supports advanced search options in the future.
    my $eh_uploader = @$data[0]->{'uploader'};
    my $eh_timestamp = @$data[0]->{'posted'};
    $eh_all_tags .= ', uploader:' . $eh_uploader . ', timestamp:' . $eh_timestamp;
  }

  # Check whether metadata were successfully retrieved from EH just in case. This should be unnecessary.
  if ($eh_all_tags eq '' || $eh_title eq '') {
    return ('', '', 'Failed to retrieve metadata due to an unknown error.');
  }
  return ($eh_all_tags, $eh_title, '');
}

1;
