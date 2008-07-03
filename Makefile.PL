use inc::Module::Install;

name            "Catalyst-Authentication-Credential-OpenID";
all_from        "lib/Catalyst/Authentication/Credential/OpenID.pm";
author          "Ashley Pond V <ashley@cpan.org>";

requires  "parent"                => "0.2";
requires  "Class::Accessor::Fast";
requires  "Catalyst";
requires  "Catalyst::Runtime"     => "5.7";
requires  "Catalyst::Devel"       => "1";
requires  "Crypt::DH"             => "0.05"; # IIRC OpenID stuff forgets to prereq this
requires  "Net::OpenID::Consumer" => "0.14";
requires  "Catalyst::Exception";
requires  "Catalyst::Authentication::User::Hash";
requires  "Cache::FastMmap"       => "1.28";

recommends "Config::General"     => "2";
recommends "YAML"                => "0.6";
recommends "LWPx::ParanoidAgent" => "1.03";
recommends "Math::BigInt";

build_requires  "LWP::UserAgent";
build_requires  "Test::More"            => "0.42";
build_requires  "Net::OpenID::Server";
build_requires  "Test::WWW::Mechanize"  => "1.20";
build_requires  "Catalyst::Plugin::Session::Store::FastMmap" => "0.05";
build_requires  "Net::DNS";
build_requires  "IO::Socket::INET";

auto_install;
WriteAll;

__END__
