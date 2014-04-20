package BusyBird::Filter::Twitter;
use strict;
use warnings;
use BusyBird::DateTime::Format;
use BusyBird::Util qw(split_with_entities);
use Exporter qw(import);
use Storable qw(dclone);

our @EXPORT = our @EXPORT_OK = map { "filter_twitter_$_" } qw(all search_status status_id unescape);

my $DATETIME_FORMATTER = 'BusyBird::DateTime::Format';

sub _make_filter {
    my ($transformer) = @_;
    return sub {
        return [ map { $transformer->(dclone($_)) } @{$_[0]} ];
    };
}

my %_SEARCH_KEY_MAP = (
    id => 'from_user_id',
    id_str => 'from_user_id_str',
    screen_name => 'from_user',
    profile_image_url => 'profile_image_url',
);

sub _transform_search_status {
    my ($status) = @_;
    if(exists($status->{created_at})) {
        $status->{created_at} = $DATETIME_FORMATTER->format_datetime(
            $DATETIME_FORMATTER->parse_datetime($status->{created_at})
        );
    }
    return $status if defined $status->{user};
    $status->{user} = {};
    foreach my $new_id_key (keys %_SEARCH_KEY_MAP) {
        my $orig_id_key = $_SEARCH_KEY_MAP{$new_id_key};
        $status->{user}{$new_id_key} = delete $status->{$orig_id_key} if exists $status->{$orig_id_key};
    }
    return $status;
}

my $FILTER_SEARCH = _make_filter \&_transform_search_status;

sub filter_twitter_search_status {
    return $FILTER_SEARCH;
}

sub _transform_status_id {
    my ($prefix, $status) = @_;
    foreach my $key (qw(id id_str in_reply_to_status_id in_reply_to_status_id_str)) {
        next if not defined $status->{$key};
        $status->{busybird}{original}{$key} = $status->{$key};
        $status->{$key} = "$prefix/statuses/show/" . $status->{$key} . ".json";
    }
    return $status;
}

sub _normalize_api_url {
    my ($api_url) = @_;
    $api_url = "https://api.twitter.com/1.1/" if not defined $api_url;
    $api_url =~ s|/+$||;
    return $api_url;
}

sub filter_twitter_status_id {
    my ($api_url) = @_;
    $api_url = _normalize_api_url($api_url);
    return _make_filter sub { _transform_status_id($api_url, $_[0]) };
}

sub _transform_unescape {
    my ($status) = @_;
    if(defined($status->{retweeted_status})) {
        _transform_unescape($status->{retweeted_status});
    }
    if(!defined($status->{text})) {
        return $status;
    }
    my $segments = split_with_entities($status->{text}, $status->{entities});
    my $new_text = "";
    my %new_entities = ();
    if(defined($status->{entities}) && ref($status->{entities}) eq 'HASH') {
        %new_entities = map { $_ => [] } keys %{$status->{entities}};
    }
    foreach my $segment (@$segments) {
        $segment->{text} =~ s/&lt;/</g;
        $segment->{text} =~ s/&gt;/>/g;
        $segment->{text} =~ s/&quot;/"/g;
        $segment->{text} =~ s/&amp;/&/g;
        if(defined($segment->{entity})) {
            $segment->{entity}{indices}[0] = length($new_text);
            $segment->{entity}{indices}[1] = $segment->{entity}{indices}[0] + length($segment->{text});
            push(@{$new_entities{$segment->{type}}}, $segment->{entity});
        }
        $new_text .= $segment->{text};
    }
    $status->{text} = $new_text;
    if(defined($status->{entities})) {
        $status->{entities} = \%new_entities;
    }
    return $status;
}

my $FILTER_UNESCAPE = _make_filter \&_transform_unescape;

sub filter_twitter_unescape {
    return $FILTER_UNESCAPE;
}

sub filter_twitter_all {
    my ($api_url) = @_;
    $api_url = _normalize_api_url($api_url);
    return _make_filter sub {
        _transform_unescape
            _transform_status_id $api_url,
                _transform_search_status shift
    };
}


1;
__END__

=pod

=head1 NAME

BusyBird::Filter::Twitter - filters for statuses imported from Twitter

=head1 SYNOPSIS

    write synopsis (using 'BusyBird' module)

=head1 DESCRIPTION

This module provides transformations and filters that you should apply to statuses imported from Twitter.
Basically it does the following transformation to the input statuses.

=over

=item *

Convert status IDs to include the source of the statuses.
This prevents ID conflict between statuses from different sources.

=item *

Add BusyBird-specific fields to the statuses.

=item *

Normalize status objects from Search API v1.0.

=item *

Transform text content so that L<BusyBird> can render it appropriately.

=back

Note that this module does not help you import statuses from Twitter.
For that purpose, I recommend L<Net::Twitter::Loader>.

By default, this module exports nothing.
You can import the following functions individually and/or by tags.
Import C<":all"> to import all functions at once.

=head1 :transform TAG FUNCTIONS

These functions transform a single status object and return the result.
The transformation is B<destructive>.

=head2 $status = trans_twitter_all($status, [$api_url])

Applies all transformations described below to the given C<$status>.

Argument C<$api_url> is optional. See C<trans_twitter_status_id()> function below.

=head2 $status = trans_twitter_search_status($status)

Transforms the C<$status> returned by Twitter's Search API v1.0 into something more like a normal status object.

=head2 $status = trans_twitter_status_id($status, [$api_url])

Transforms the C<$status>'s ID fields so that they include API URL of the source.
This transformation is recommended when you load statuses from multiple sources, e.g. twitter.com and loadaverage.org.

Argument C<$api_url> is optional. By default it is C<"https://api.twitter.com/1.1/">.
You should set it appropriately if you import statuses from other sites.

The original IDs are saved under C<< $status->{busybird}{original} >>

=head2 $status = trans_twitter_unescape($status)

Unescapes some HTML entities in the C<$status>'s text field.

HTML-unescape is necessary because twitter.com automatically HTML-escapes some special characters,
AND L<BusyBird> also HTML-escapes status texts when it renders them.
This results in double HTML-escapes.

The transformation changes the status's text length.
C<"indices"> fields in the status's L<Twitter Entities|https://dev.twitter.com/docs/platform-objects/entities> are
adjusted appropriately.

The transformation is applied recursively to the status's C<retweeted_status>, if any.

=head1 :filter TAG FUNCTIONS

These functions generate a synchronous status filter corresponding to the C<trans_twitter_*> functions.

All filters are non-destructive. That is, they won't modify input statuses. Transformation is done to their clones.

=head2 $filter = filter_twitter_all([$api_url])

=head2 $filter = filter_twitter_search_status()

=head2 $filter = filter_twitter_status_id([$api_url])

=head2 $filter = filter_twitter_unescape()

=head1 SEE ALSO

=over

=item *

L<Net::Twitter>

=item *

L<Net::Twitter::Lite>

=item *

L<Net::Twitter::Loader>

=back

=head1 AUTHOR

Toshio Ito C<< <toshioito [at] cpan.org> >>

=cut
