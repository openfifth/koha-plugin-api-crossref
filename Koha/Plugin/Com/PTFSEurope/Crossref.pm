# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Copyright 2026 Open Fifth
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License
# for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

package Koha::Plugin::Com::PTFSEurope::Crossref;

use Modern::Perl;

use base qw(Koha::Plugins::Base);
use Koha::DateUtils qw( dt_from_string );

use Cwd qw(abs_path);
use CGI;
use LWP::UserAgent;
use HTTP::Request;
use JSON qw( encode_json decode_json );

our $VERSION         = '1.1.0';

our $metadata = {
    name            => 'Crossref',
    author          => 'Andrew Isherwood',
    date_authored   => '2022-04-20',
    date_updated    => "2022-04-20",
    minimum_version => '18.05.00.000',
    maximum_version => undef,
    version         => $VERSION,
    license         => 'AGPL-3.0-or-later',
    license_url     => 'https://www.gnu.org/licenses/agpl-3.0.html',
    description     => 'This plugin provides Koha API routes enabling access to the Crossref "works" API endpoint. Licensed under AGPL-3.0-or-later.' 
};

sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    $self->{config} = decode_json($self->retrieve_data('crossref_config') || '{}');

    return $self;
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'configure.tt' });
        $template->param(
            config => $self->{config}
        );
        $self->output_html( $template->output() );
    } else {
        my %blacklist = ('save' => 1, 'class' => 1, 'method' => 1);
        my $hashed = { map { $_ => (scalar $cgi->param($_))[0] } $cgi->param };
        my $p = {};
        foreach my $key (keys %{$hashed}) {
           if (!exists $blacklist{$key}) {
               $p->{$key} = $hashed->{$key};
           }
        }
        $self->store_data({ crossref_config => scalar encode_json($p) });
        print $cgi->redirect(-url => '/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::Com::PTFSEurope::Crossref&method=configure');
        exit;
    }
}

sub provides_api {
    return {
        name                  => 'Crossref', # Display name
        api_namespace         => api_namespace(), # API namespace for URL forming
        type                  => 'search', # Type of API this is
        identifiers_supported => { # The identifiers this service can use
            doi => {
                regex      => '^((http|https):\/\/(dx\.)?doi\.org\/|doi:)?(?<identifier>10\..*)$', # Regex for identifying these identifiers
                param_name => 'doi' # When passing one of these identifiers to the API, name of the parameter
            }
        },
        search_endpoint       => '/works', # The endpoint for accessing this API
        ill_parse_endpoint    => '/parse_to_ill', # The endpoint for parsing search results into ILL schema
        method                => 'GET', # The HTTP method to use
        provide_identifier_in => 'query' # Where to provide identifiers in calls
    };
}

sub api_routes {
    my ($self, $args) = @_;

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ($self) = @_;

    return 'crossref';
}

sub install() {
    return 1;
}

sub upgrade {
    my ( $self, $args ) = @_;

    my $dt = dt_from_string();
    $self->store_data(
        { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') }
    );

    return 1;
}

sub uninstall() {
    return 1;
}

1;
