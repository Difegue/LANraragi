use strict;
use warnings;
use utf8;

use Test::More;

BEGIN { 
    use_ok('LANraragi::Utils::Metrics'); 
    LANraragi::Utils::Metrics->import('extract_endpoint', 'escape_label_value');
}

note('testing basic functionality...');
{
    is(LANraragi::Utils::Metrics::extract_endpoint(undef), "/unknown", "undefined path returns /unknown");
    is(LANraragi::Utils::Metrics::extract_endpoint(""), "/", "empty string returns /");
    is(LANraragi::Utils::Metrics::extract_endpoint("/"), "/", "root path returns /");

    is(LANraragi::Utils::Metrics::extract_endpoint("/api/info?param=value"), "/api/info", "query parameters removed");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/info#fragment"), "/api/info", "fragments removed");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/info?param=value#fragment"), "/api/info", "both query and fragment removed");
}

note('testing archive endpoints...');
{
    my $archive_id = "19ecae086945bb7f815b19b192a48d9d79e36085";
    
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/archives/$archive_id"), 
        "/api/archives/:id", "archive ID normalization");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/archives/$archive_id/thumbnail"), 
        "/api/archives/:id/thumbnail", "archive thumbnail endpoint");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/archives/$archive_id/download"), 
        "/api/archives/:id/download", "archive download endpoint");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/archives/$archive_id/progress/15"), 
        "/api/archives/:id/progress/:page", "archive progress endpoint");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/archives/$archive_id/files"), 
        "/api/archives/:id/files", "archive files endpoint");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/archives/$archive_id/metadata"), 
        "/api/archives/:id/metadata", "archive metadata endpoint");

    is(LANraragi::Utils::Metrics::extract_endpoint("/api/archives"), 
        "/api/archives", "archives list endpoint unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/archives/untagged"), 
        "/api/archives/untagged", "untagged archives endpoint unchanged");
}

note('testing category endpoints...');
{
    my $category_id = "some_category_id";
    my $archive_id = "19ecae086945bb7f815b19b192a48d9d79e36085";

    is(LANraragi::Utils::Metrics::extract_endpoint("/api/categories"), 
        "/api/categories", "categories list endpoint unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/categories/$category_id"), 
        "/api/categories/:id", "category ID normalization");

    # The problematic case mentioned in the issue
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/categories/$category_id/$archive_id"), 
        "/api/categories/:id/:archive", "category with archive ID normalization - this was the bug");

    is(LANraragi::Utils::Metrics::extract_endpoint("/api/categories/bookmark_link"), 
        "/api/categories/bookmark_link", "bookmark link endpoint unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/categories/bookmark_link/$category_id"), 
        "/api/categories/bookmark_link/:id", "bookmark link with ID normalization");
}

note('testing tankoubon endpoints...');
{
    my $tankoubon_id = "some_tankoubon_id";
    my $archive_id = "19ecae086945bb7f815b19b192a48d9d79e36085";

    is(LANraragi::Utils::Metrics::extract_endpoint("/api/tankoubons"), 
        "/api/tankoubons", "tankoubons list endpoint unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/tankoubons/$tankoubon_id"), 
        "/api/tankoubons/:id", "tankoubon ID normalization");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/tankoubons/$tankoubon_id/$archive_id"), 
        "/api/tankoubons/:id/:archive", "tankoubon with archive ID normalization");
}

note('testing minion endpoints...');
{
    my $job_id = "12345";
    my $job_name = "some_job";
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/minion/$job_id"), 
        "/api/minion/:jobid", "minion job ID normalization");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/minion/$job_id/detail"), 
        "/api/minion/:jobid/detail", "minion job detail endpoint");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/minion/$job_name/queue"), 
        "/api/minion/:jobname/queue", "minion job queue endpoint");
}

note('testing OPDS endpoints...');
{
    my $opds_id = "some_opds_id";

    is(LANraragi::Utils::Metrics::extract_endpoint("/api/opds"), 
        "/api/opds", "OPDS catalog endpoint unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/opds/$opds_id"), 
        "/api/opds/:id", "OPDS item ID normalization");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/opds/$opds_id/pse"), 
        "/api/opds/:id/pse", "OPDS page endpoint normalization");
}

note('testing plugin endpoints...');
{
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/plugins/metadata"), 
        "/api/plugins/:type", "plugin type normalization");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/plugins/download"), 
        "/api/plugins/:type", "plugin download type normalization");

    is(LANraragi::Utils::Metrics::extract_endpoint("/api/plugins/use"), 
        "/api/plugins/use", "plugin use endpoint unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/plugins/queue"), 
        "/api/plugins/queue", "plugin queue endpoint unchanged");
}

note('testing other API endpoints...');
{
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/info"), 
        "/api/info", "info endpoint unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/search"), 
        "/api/search", "search endpoint unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/search/random"), 
        "/api/search/random", "random search endpoint unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/database/stats"), 
        "/api/database/stats", "database stats endpoint unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/metrics"), 
        "/metrics", "metrics endpoint unchanged");
}

note('testing non-API endpoints...');
{
    is(LANraragi::Utils::Metrics::extract_endpoint("/login"), 
        "/login", "login endpoint unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/config"), 
        "/config", "config endpoint unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/reader"), 
        "/reader", "reader endpoint unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/some/arbitrary/path"), 
        "/some/arbitrary/path", "arbitrary paths unchanged");
}

note('testing edge cases...');
{
    # Test malformed archive IDs (not exactly 40 hex chars)
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/archives/tooshort"), 
        "/api/archives/tooshort", "short non-SHA1 archive ID unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/archives/19ecae086945bb7f815b19b192a48d9d79e36085extra"), 
        "/api/archives/19ecae086945bb7f815b19b192a48d9d79e36085extra", "too long archive ID unchanged");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/archives/19ecae086945bb7f815b19b192a48d9d79e3608g"), 
        "/api/archives/19ecae086945bb7f815b19b192a48d9d79e3608g", "non-hex archive ID unchanged");

    # Test trailing slashes
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/categories/someid/"), 
        "/api/categories/:id/", "trailing slash preserved");
    is(LANraragi::Utils::Metrics::extract_endpoint("/api/categories/someid/19ecae086945bb7f815b19b192a48d9d79e36085/"), 
        "/api/categories/:id/:archive/", "trailing slash on archive endpoint preserved");
}

note('testing regression case from issue...');
{
    my $problematic_path = "/api/categories/some_category/19ecae086945bb7f815b19b192a48d9d79e36085";
    my $expected = "/api/categories/:id/:archive";

    is(LANraragi::Utils::Metrics::extract_endpoint($problematic_path), 
        $expected, "The specific case from the issue is now fixed");
}

note('testing OpenMetrics label value escaping...');
{
    # Test basic cases
    is(LANraragi::Utils::Metrics::escape_label_value(undef), "", "undefined value returns empty string");
    is(LANraragi::Utils::Metrics::escape_label_value(""), "", "empty string returns empty string");
    is(LANraragi::Utils::Metrics::escape_label_value("simple"), "simple", "simple string unchanged");
    
    # Test escaping rules
    is(LANraragi::Utils::Metrics::escape_label_value("quote\"test"), "quote\\\"test", "double quotes escaped");
    is(LANraragi::Utils::Metrics::escape_label_value("backslash\\test"), "backslash\\\\test", "backslashes escaped");
    is(LANraragi::Utils::Metrics::escape_label_value("newline\ntest"), "newline\\ntest", "newlines escaped");
    
    # Test multiple escapes in same string
    is(LANraragi::Utils::Metrics::escape_label_value("mixed\"test\\with\nnewline"), 
        "mixed\\\"test\\\\with\\nnewline", "multiple escape types handled correctly");
    
    # Test realistic LANraragi data
    is(LANraragi::Utils::Metrics::escape_label_value("LANraragi v.0.8.9 \"Shinobu\""), 
        "LANraragi v.0.8.9 \\\"Shinobu\\\"", "version name with quotes");
    is(LANraragi::Utils::Metrics::escape_label_value("My \"awesome\" library\nWith description"), 
        "My \\\"awesome\\\" library\\nWith description", "server name with quotes and newlines");
    is(LANraragi::Utils::Metrics::escape_label_value("Windows\\path\\to\\file"), 
        "Windows\\\\path\\\\to\\\\file", "Windows paths with backslashes");
    
    # Test HTTP methods and endpoints (these shouldn't need escaping but test anyway)
    is(LANraragi::Utils::Metrics::escape_label_value("GET"), "GET", "HTTP method unchanged");
    is(LANraragi::Utils::Metrics::escape_label_value("POST"), "POST", "HTTP method unchanged");
    is(LANraragi::Utils::Metrics::escape_label_value("/api/archives/:id"), "/api/archives/:id", "endpoint path unchanged");
    
    # Test edge cases
    is(LANraragi::Utils::Metrics::escape_label_value("\""), "\\\"", "single quote escaped");
    is(LANraragi::Utils::Metrics::escape_label_value("\\"), "\\\\", "single backslash escaped");  
    is(LANraragi::Utils::Metrics::escape_label_value("\n"), "\\n", "single newline escaped");
    is(LANraragi::Utils::Metrics::escape_label_value("\"\\\n"), "\\\"\\\\\\n", "all special chars together");
    
    # Test realistic server configuration values
    is(LANraragi::Utils::Metrics::escape_label_value("Welcome to my \"collection\"!\nEnjoy browsing."), 
        "Welcome to my \\\"collection\\\"!\\nEnjoy browsing.", "MOTD with quotes and newlines");
    is(LANraragi::Utils::Metrics::escape_label_value("C:\\Program Files\\LANraragi"), 
        "C:\\\\Program Files\\\\LANraragi", "Windows installation path");
}

done_testing();
