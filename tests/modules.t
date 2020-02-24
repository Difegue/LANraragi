use strict;
use warnings;
use utf8;
use Cwd;

use Mojo::Base 'Mojolicious';
use Test::More tests => 38;
use Test::Mojo;
use Test::MockObject;

sub test_module {
    my $module_name = shift;

    eval "require $module_name";
    if($@) {
        warn "Could not load module: $@\n";
        return 0;
    }

    return 1;
}

# Mock Redis
my $cwd = getcwd;
require $cwd."/tests/mocks.pl";
setup_redis_mock();

my @modules = ("Shinobu", 
            "LANraragi",
            "LANraragi::Utils::Archive",
            "LANraragi::Utils::Database",
            "LANraragi::Utils::Generic",
            "LANraragi::Utils::Plugins",
            "LANraragi::Utils::Routing",
            "LANraragi::Utils::TempFolder",
            "LANraragi::Utils::Logging",
            "LANraragi::Controller::Api",
            "LANraragi::Controller::Backup",
            "LANraragi::Controller::Batch",
            "LANraragi::Controller::Config",
            "LANraragi::Controller::Edit",
            "LANraragi::Controller::Index",
            "LANraragi::Controller::Logging",
            "LANraragi::Controller::Login",
            "LANraragi::Controller::Plugins",
            "LANraragi::Controller::Reader",
            "LANraragi::Controller::Search",
            "LANraragi::Controller::Stats",
            "LANraragi::Controller::Upload",
            "LANraragi::Model::Api",
            "LANraragi::Model::Backup",
            "LANraragi::Model::Config",
            "LANraragi::Model::Plugins",
            "LANraragi::Model::Reader",
            "LANraragi::Model::Search",
            "LANraragi::Model::Stats",
            "LANraragi::Plugin::Metadata::Chaika",
            "LANraragi::Plugin::Metadata::CopyTags",
            "LANraragi::Plugin::Metadata::DateAdded",
            "LANraragi::Plugin::Metadata::EHentai",
            "LANraragi::Plugin::Metadata::Eze",
            "LANraragi::Plugin::Metadata::Hdoujin",
            "LANraragi::Plugin::Metadata::Koromo",
            "LANraragi::Plugin::Metadata::nHentai",
            "LANraragi::Plugin::Login::EHentai"
            );

# Test all modules load properly
foreach my $module_name(@modules) {
    ok( test_module($module_name), $module_name);
}

done_testing();