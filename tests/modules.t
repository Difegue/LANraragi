use strict;
use warnings;
use utf8;

use Mojo::Base 'Mojolicious';
use Test::More tests => 37;
use Test::Mojo;

sub test_module {
    my $module_name = shift;

    eval "require $module_name";
    if($@) {
        warn "Could not load module: $@\n";
        return 0;
    }

    return 1;
}

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
            "LANraragi::Plugin::Chaika",
            "LANraragi::Plugin::CopyTags",
            "LANraragi::Plugin::DateAdded",
            "LANraragi::Plugin::EHentai",
            "LANraragi::Plugin::Eze",
            "LANraragi::Plugin::Hdoujin",
            "LANraragi::Plugin::Koromo",
            "LANraragi::Plugin::nHentai"
            );

# Test all modules load properly
foreach my $module_name(@modules) {
    ok( test_module($module_name), $module_name);
}

done_testing();