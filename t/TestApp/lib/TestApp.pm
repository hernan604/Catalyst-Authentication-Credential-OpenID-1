package TestApp;

use strict;
use warnings;

use Catalyst::Runtime '5.70';

use Catalyst qw(
                -Debug
                ConfigLoader
                Authentication
                Session
                Session::Store::FastMmap
                Session::State::Cookie
                );

our $VERSION = '0.01';

__PACKAGE__->config
    ( name => "TestApp",
      startup_time => time(),
      "Plugin::Authentication" => {
          default_realm => "members",
          realms => {
              members => {
                  credential => {
                      class => "Password",
                      password_field => "password",
                      password_type => "clear"
                      },
                          store => {
                              class => "Minimal",
                              users => {
                                  paco => {
                                      password => "l4s4v3n7ur45",
                                  },
                              }                       
                          }
              },
              openid => {
                  ua_class => "LWPx::ParanoidAgent",
#                  ua_class => "LWP::UserAgent",
                  ua_args => {
                      whitelisted_hosts => [qw/ 127.0.0.1 localhost /],
                  },
                  debug => 1,
                  credential => {
                      class => "OpenID",
#DOES NOTHING                      use_session => 1        
                      store => {
                          class => "OpenID",
                      },
                  },
              },
          },
      },
      );

# Start the application
__PACKAGE__->setup;

1;

__END__

=pod

package TestApp;

use Catalyst qw/
    Authentication
    /;

use Test::More;
use Test::Exception;

sub provider : Local {


}

sub user : Local {
    my ( $self, $c ) = @_;

    ok(!$c->user, "no user");

    is( $c->user, $users->{foo}, "user object is in proper place");

    ok( !$c->user->roles, "no roles for foo" );
    my @new = qw/foo bar gorch/;
    $c->user->roles( @new );
    is_deeply( [ $c->user->roles ], \@new, "roles set as array");

    $c->logout;
    ok(!$c->user, "no more user, after logout");

    $c->res->body( "ok" );
}

__PACKAGE__->config
    (
     "Plugin::Authentication" => {
                                  default_realm => "OpenID",
                                  realms => {
                                             "OpenID" => {
                                                          credential => {
                                                                         class => "OpenID",
#DOES NOTHING YET                                                                     use_session => 1
                                                                         store => {
                                                                                   class => "OpenID",
                                                                                  },
                                                                        },
                                                         },
                                            },
                                 },
    );
#        class: Null
#implied already        user_class: Catalyst::Authentication::User::Hash
    };

__PACKAGE__->setup;

=cut
