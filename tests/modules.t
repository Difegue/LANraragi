use strict;
use warnings;
use utf8;
use Cwd;

use Test::More;

# Mock Redis
my $cwd = getcwd;
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

my @modules = (
    "Shinobu",                                      "LANraragi",
    "LANraragi::Utils::Archive",                    "LANraragi::Utils::Database",
    "LANraragi::Utils::Generic",                    "LANraragi::Utils::Plugins",
    "LANraragi::Utils::Routing",                    "LANraragi::Utils::TempFolder",
    "LANraragi::Utils::Logging",                    "LANraragi::Utils::Minion",
    "LANraragi::Utils::Tags",                       "LANraragi::Controller::Api::Archive",
    "LANraragi::Controller::Api::Search",           "LANraragi::Controller::Api::Category",
    "LANraragi::Controller::Api::Database",         "LANraragi::Controller::Api::Shinobu",
    "LANraragi::Controller::Api::Minion",           "LANraragi::Controller::Api::Other",
    "LANraragi::Controller::Backup",                "LANraragi::Controller::Batch",
    "LANraragi::Controller::Config",                "LANraragi::Controller::Edit",
    "LANraragi::Controller::Index",                 "LANraragi::Controller::Logging",
    "LANraragi::Controller::Login",                 "LANraragi::Controller::Plugins",
    "LANraragi::Controller::Reader",                "LANraragi::Controller::Stats",
    "LANraragi::Controller::Upload",                "LANraragi::Controller::Category",
    "LANraragi::Model::Archive",                    "LANraragi::Model::Backup",
    "LANraragi::Model::Config",                     "LANraragi::Model::Plugins",
    "LANraragi::Model::Reader",                     "LANraragi::Model::Search",
    "LANraragi::Model::Stats",                      "LANraragi::Model::Category",
    "LANraragi::Model::Upload",                     "LANraragi::Model::Opds",
    "LANraragi::Plugin::Metadata::Chaika",          "LANraragi::Plugin::Metadata::CopyTags",
    "LANraragi::Plugin::Metadata::DateAdded",       "LANraragi::Plugin::Metadata::EHentai",
    "LANraragi::Plugin::Metadata::Eze",             "LANraragi::Plugin::Metadata::Hdoujin",
    "LANraragi::Plugin::Metadata::Koromo",          "LANraragi::Plugin::Metadata::MEMS",
    "LANraragi::Plugin::Metadata::nHentai",         "LANraragi::Plugin::Metadata::RegexParse",
    "LANraragi::Plugin::Metadata::Fakku",           "LANraragi::Plugin::Login::EHentai",
    "LANraragi::Plugin::Login::Fakku",              "LANraragi::Plugin::Scripts::SourceFinder",
    "LANraragi::Plugin::Scripts::FolderToCat",      "LANraragi::Plugin::Download::EHentai",
    "LANraragi::Plugin::Download::Chaika",          "LANraragi::Plugin::Scripts::nHentaiSourceConverter",
    "LANraragi::Plugin::Scripts::BlacklistMigrate", "LANraragi::Plugin::Metadata::Hitomi"
);

# Test all modules load properly
foreach my $module_name (@modules) {
    require_ok($module_name);
}

done_testing();
