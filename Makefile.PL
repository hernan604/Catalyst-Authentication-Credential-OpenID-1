use inc::Module::Install;

name            "Catalyst-Authentication-Credential-OpenID";
all_from        "lib/Catalyst/Authentication/Credential/OpenID.pm";

requires  "parent"                => "0.2";
requires  "Class::Accessor::Fast" => 0;
requires  "Catalyst::Runtime"     => "5.7";
requires  "Crypt::DH"             => "0.05"; # IIRC OpenID stuff forgets to prereq this
requires  "Net::OpenID::Consumer" => "0.14";
requires  "Catalyst::Exception"   => 0;
requires  "UNIVERSAL::require"    => 0;
requires  "Catalyst::Authentication::User::Hash" => 0;

recommends "Config::General"     => "2";
recommends "YAML"                => ".6";
recommends "LWPx::ParanoidAgent" => "1.03";
recommends "Math::BigInt"        => 0;

build_requires  "LWP::UserAgent"        => 0;
build_requires  "Test::More"            => "0.42";
build_requires  "Net::OpenID::Server"   => 0;
build_requires  "Test::WWW::Mechanize"  => "1.20";
build_requires  "Catalyst::Plugin::Session::Store::FastMmap" => 0;
build_requires  "Net::DNS" => 0;
build_requires  "IO::Socket::INET" => 0;

auto_install;
WriteAll;

__END__
