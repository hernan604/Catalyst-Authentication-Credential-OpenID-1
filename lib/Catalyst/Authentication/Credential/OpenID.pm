package Catalyst::Authentication::Credential::OpenID;
use parent "Class::Accessor::Fast";

BEGIN {
    __PACKAGE__->mk_accessors(qw/ _config realm debug secret /);
}

use strict;
use warnings;
no warnings "uninitialized";

our $VERSION = "0.02";

use Net::OpenID::Consumer;
use UNIVERSAL::require;
use Catalyst::Exception ();

sub new : method {
    my ( $class, $config, $c, $realm ) = @_;
    my $self = { _config => { %{ $config },
                              %{ $realm->{config} }
                          }
                 };
    bless $self, $class;

    # 2.0 spec says "SHOULD" be named "openid_identifier."
    $self->_config->{openid_field} ||= "openid_identifier";

    $self->debug( $self->_config->{debug} );

    my $secret = $self->_config->{consumer_secret} ||= join("+",
                                                            __PACKAGE__,
                                                            $VERSION,
                                                            sort keys %{ $c->config }
                                                            );

    $secret = substr($secret,0,255) if length $secret > 255;
    $self->secret( $secret );
    $self->_config->{ua_class} ||= "LWPx::ParanoidAgent";

    eval {
        $self->_config->{ua_class}->require;
    }
    or Catalyst::Exception->throw("Could not 'require' user agent class " .
                                  $self->_config->{ua_class});

    $c->log->debug("Setting consumer secret: " . $secret) if $self->debug;

    return $self;
}

sub authenticate : method {
    my ( $self, $c, $realm, $authinfo ) = @_;

    $c->log->debug("authenticate() called from " . $c->request->uri) if $self->debug;

    my $field = $self->{_config}->{openid_field};

    my $claimed_uri = $authinfo->{ $field };

    # Its security related so we want to be explicit about GET/POST param retrieval.
    $claimed_uri ||= $c->req->method eq 'GET' ? 
        $c->req->query_params->{ $field } : $c->req->body_params->{ $field };

    my $csr = Net::OpenID::Consumer->new(
        ua => $self->_config->{ua_class}->new(%{$self->_config->{ua_args} || {}}),
        args => $c->req->params,
        consumer_secret => $self->secret,
    );

    if ( $claimed_uri )
    {
        my $current = $c->uri_for($c->req->uri->path); # clear query/fragment...

        my $identity = $csr->claimed_identity($claimed_uri)
            or Catalyst::Exception->throw($csr->err);

        my $check_url = $identity->check_url(
            return_to  => $current . '?openid-check=1',
            trust_root => $current,
            delayed_return => 1,
        );
        $c->res->redirect($check_url);
        return;
    }
    elsif ( $c->req->params->{'openid-check'} )
    {
        if ( my $setup_url = $csr->user_setup_url )
        {
            $c->res->redirect($setup_url);
            return;
        }
        elsif ( $csr->user_cancel )
        {
            return;
        }
        elsif ( my $identity = $csr->verified_identity )
        {
            # This is where we ought to build an OpenID user and verify against the spec.
            my $user = +{ map { $_ => scalar $identity->$_ }
                qw( url display rss atom foaf declared_rss declared_atom declared_foaf foafmaker ) };

            my $user_obj = $realm->find_user($user, $c);

            if ( ref $user_obj )
            {
                return $user_obj;
            }
            else
            {
                $c->log->debug("Verified OpenID identity failed to load with find_user; bad user_class? Try 'Null.'") if $c->debug;
                return;
            }
        }
        else
        {
            Catalyst::Exception->throw("Error validating identity: " .
                                       $csr->err);
        }
    }
    else
    {
        return;
    }
}

1;

__END__

=pod

=head1 NAME

Catalyst::Authentication::Credential::OpenID - OpenID credential for L<Catalyst::Plugin::Authentication> framework.

=head1 SYNOPSIS

 # MyApp
 use Catalyst qw/
    Authentication
    Session
    Session::Store::FastMmap
    Session::State::Cookie
 /;

 # MyApp.yaml --
 Plugin::Authentication:
   default_realm: openid
   realms:
     openid:
       credential:
         class: OpenID

 # Root::openid().
 sub openid : Local {
      my($self, $c) = @_;

      if ( $c->authenticate() )
      {
          $c->flash(message => "You signed in with OpenID!");
          $c->res->redirect( $c->uri_for('/') );
      }
      else
      {
          # Present OpenID form.
      }
 }

 # openid.tt
 <form action="[% c.uri_for('/openid') %]" method="GET" name="openid">
 <input type="text" name="openid_identifier" class="openid" />
 <input type="submit" value="Sign in with OpenID" />
 </form>


=head1 DESCRIPTION

This is the B<third> OpenID related authentication piece for
L<Catalyst>. The first -- L<Catalyst::Plugin::Authentication::OpenID>
by Benjamin Trott -- was deprecated by the second --
L<Catalyst::Plugin::Authentication::Credential::OpenID> by Tatsuhiko
Miyagawa -- and this is an attempt to deprecate both by conforming to
the newish, at the time of this module's inception, realm-based
authentication in L<Catalyst::Plugin::Authentication>.

 * Catalyst::Plugin::Authentication::OpenID (first)
 * Catalyst::Plugin::Authentication::Credential::OpenID (second)
 * Catalyst::Authentication::Credential::OpenID (this, the third)

The benefit of this version is that you can use an arbitrary number of
authentication systems in your L<Catalyst> application and configure
and call all of them in the same way.

Note, both earlier versions of OpenID authentication use the method
C<authenticate_openid()>. This module uses C<authenticate()> and
relies on you to specify the realm. You can specify the realm as the
default in the configuration or inline with each
C<authenticate()> call; more below.

This module functions quite differently internally from the others.
See L<Catalyst::Plugin::Authentication::Internals> for more about this
implementation.

=head1 METHOD

=over 4

=item * $c->authenticate({},"your_openid_realm");

Call to authenticate the user via OpenID. Returns false if
authorization is unsuccessful. Sets the user into the session and
returns the user object if authentication succeeds.

You can see in the call above that the authentication hash is empty.
The implicit OpenID parameter is, as the 2.0 specification says it
SHOULD be, B<openid_identifier>. You can set it anything you like in
your realm configuration, though, under the key C<openid_field>. If
you call C<authenticate()> with the empty info hash and no configured
C<openid_field> then only C<openid_identifier> is checked.

It implicitly does this (sort of, it checks the request method too)-

 my $claimed_uri = $c->req->params->{openid_identifier};
 $c->authenticate({openid_identifier => $claimed_uri});

=item * Catalyst::Authentication::Credential::OpenID->new()

You will never call this. Catalyst does it for you. The only important
thing you might like to know about it is that it merges its realm
configuration with its configuration proper. If this doesn't mean
anything to you, don't worry.

=back

=head2 USER METHODS

Currently the only supported user class is L<Catalyst::Plugin::Authentication::User::Hash>.

=over 4

=item * $c->user->url

=item * $c->user->display

=item * $c->user->rss 

=item * $c->user->atom

=item * $c->user->foaf

=item * $c->user->declared_rss

=item * $c->user->declared_atom

=item * $c->user->declared_foaf

=item * $c->user->foafmaker

=back

See L<Net::OpenID::VerifiedIdentity> for details.

=head1 CONFIGURATION

Catalyst authentication is now configured entirely from your
application's configuration. Do not, for example, put
C<Credential::OpenID> into your C<use Catalyst ...> statement.
Instead, tell your application that in one of your authentication
realms you will use the credential.

In your application the following will give you two different
authentication realms. One called "members" which authenticates with
clear text passwords and one called "openid" which uses... uh, OpenID.

 __PACKAGE__->config
    ( name => "MyApp",
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
                  consumer_secret => "Don't bother setting",
                  ua_class => "LWPx::ParanoidAgent",
                  ua_args => {
                      whitelisted_hosts => [qw/ 127.0.0.1 localhost /],
                  },
                  credential => {
                      class => "OpenID",
                      store => {
                          class => "OpenID",
                      },
                  },
              },
          },
      },
      );

And now, the same configuration in YAML.

 name: MyApp
 Plugin::Authentication:
   default_realm: members
   realms:
     members:
       credential:
         class: Password
         password_field: password
         password_type: clear
       store:
         class: Minimal
         users:
           paco:
             password: l4s4v3n7ur45
     openid:
       credential:
         class: OpenID
         store:
           class: OpenID
       consumer_secret: Don't bother setting
       ua_class: LWPx::ParanoidAgent
       ua_args:
         whitelisted_hosts:
           - 127.0.0.1
           - localhost

B<NB>: There is no OpenID store yet. Trying for next release.

=head1 CONFIGURATION

These are set in your realm. See above.

=over 4

=item * ua_args and ua_class

L<LWPx::ParanoidAgent> is the default agent -- C<ua_class>. You don't
have to set it. I recommend that you do B<not> override it. You can
with any well behaved L<LWP::UserAgent>. You probably should not.
L<LWPx::ParanoidAgent> buys you many defenses and extra security
checks. When you allow your application users freedom to initiate
external requests, you open a big avenue for DoS (denial of service)
attacks. L<LWPx::ParanoidAgent> defends against this.
L<LWP::UserAgent> and any regular subclass of it will not.

=item * consumer_secret

The underlying L<Net::OpenID::Consumer> object is seeded with a
secret. If it's important to you to set your own, you can. The default
uses this package name + its version + the sorted configuration keys
of your Catalyst application (chopped at 255 characters if it's
longer). This should generally be superior to any fixed string.

=back


=head1 TODO

There are some interesting implications with this sort of setup. Does
a user aggregate realms or can a user be signed in under more than one
realm? The documents could contain a recipe of the self-answering
OpenID end-point that is in the tests.

Debug statements need to be both expanded and limited via realm
configuration.

Better diagnostics in errors. Debug info at all consumer calls.

Roles from provider domains? Mapped? Direct? A generic "openid" auto_role?

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008, Ashley Pond V C<< <ashley@cpan.org> >>. Some of
Tatsuhiko Miyagawa's work is reused here.

This module is free software; you can redistribute it and modify it
under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

Because this software is licensed free of charge, there is no warranty
for the software, to the extent permitted by applicable law. Except when
otherwise stated in writing the copyright holders and other parties
provide the software "as is" without warranty of any kind, either
expressed or implied, including, but not limited to, the implied
warranties of merchantability and fitness for a particular purpose. The
entire risk as to the quality and performance of the software is with
you. Should the software prove defective, you assume the cost of all
necessary servicing, repair, or correction.

In no event unless required by applicable law or agreed to in writing
will any copyright holder, or any other party who may modify or
redistribute the software as permitted by the above license, be
liable to you for damages, including any general, special, incidental,
or consequential damages arising out of the use or inability to use
the software (including but not limited to loss of data or data being
rendered inaccurate or losses sustained by you or third parties or a
failure of the software to operate with any other software), even if
such holder or other party has been advised of the possibility of
such damages.


=head1 THANKS

To Benjamin Trott, Tatsuhiko Miyagawa, and Brad Fitzpatrick for the
great OpenID stuff and to Jay Kuri and everyone else who has made
Catalyst such a wonderful framework.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Plugin::Authentication>,
L<Net::OpenID::Consumer>, and L<LWPx::ParanoidAgent>.

=head2 RELATED

L<Net::OpenID::Server>, L<Net::OpenID::VerifiedIdentity>,
L<http://openid.net/>, and L<http://openid.net/developers/specs/>.

L<Catalyst::Plugin::Authentication::OpenID> (Benjamin Trott) and L<Catalyst::Plugin::Authentication::Credential::OpenID> (Tatsuhiko Miyagawa).

=cut