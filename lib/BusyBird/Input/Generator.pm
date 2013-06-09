package BusyBird::Input::Generator;
use strict;
use warnings;
use DateTime;
use BusyBird::DateTime::Format;
use BusyBird::Version;
our $VERSION = $BusyBird::Version::VERSION;

sub new {
    my ($class, %args) = @_;
    my $self = bless {
        screen_name => defined($args{screen_name}) ? $args{screen_name} : "",
        last_epoch => 0,
        next_sequence_number => 0,
    }, $class;
    return $self;
}

sub generate {
    my ($self, %args) = @_;
    my $text = defined($args{text}) ? $args{text} : "";
    my $level = defined($args{level}) ? $args{level} : 0;
    my $cur_time = DateTime->now;
    my $status = +{
        id => $self->generate_id(undef, $cur_time),
        text => $text,
        created_at => BusyBird::DateTime::Format->format_datetime($cur_time),
        user => {
            screen_name => $self->{screen_name},
        },
        busybird => {
            status_permalink => ""
        }
    };
    if(defined $level) {
        $status->{busybird}{level} = $level + 0;
    }
    return $status;
}

sub generate_id {
    my ($self, $namespace, $cur_time) = @_;
    $namespace = $self->{screen_name} if not defined($namespace);
    $cur_time = DateTime->now if not defined($cur_time);
    my $cur_epoch = $cur_time->epoch;
    if($self->{last_epoch} != $cur_epoch) {
        $self->{next_sequence_number} = 0;
    }
    my $id = qq{busybird://$namespace/$cur_epoch/$self->{next_sequence_number}};
    $self->{next_sequence_number}++;
    $self->{last_epoch} = $cur_epoch;
    return $id;
}

1;
__END__

=pod

=head1 NAME

BusyBird::Input::Generator - status generator

=head1 SYNOPSIS

    my $gen = BusyBird::Input::Generator->new(screen_name => "toshio_ito");
    
    my $status = $gen->generate(text => "Hello, world!");

=head1 DESCRIPTION

L<BusyBird::Input::Generator> generates status objects.
It is useful for injecting arbitrary messages into your timelines,
or just for debugging purposes.

=head2 Features

=over

=item *

The IDs of generated statuses are unique as long as they are generated by the same
L<BusyBird::Input::Generator> object.

=item *

It automatically sets the timestamps of generated statuses.

=back

=head1 CLASS METHODS

=head2 $gen = BusyBird::Input::Generator->new(%args)

The constructor.

Fields in C<%args> are:

=over

=item C<screen_name> => STR (optional, default: "")

The C<screen_name> field of the statuses to be generated.

=back

=head1 OBJECT METHODS

=head2 $status = $gen->generate(%args)

Generates a status object.
See L<BusyBird::Status> for format of the status object.

Fields in C<%args> are:

=over

=item C<text> => STR (optional, default: "")

The C<text> field of the status. It must be a text string, not a binary (octet) string.

=item C<level> => INT (optional, default: 0)

The C<busybird.level> field of the status.

=back

=head2 $id_str = $gen->generate_id([$namespace, $current_time])

Generates a new ID string from C<$namespace> string and the timestamp C<$current_time>.
Both C<$namespace> and C<$current_time> are optional.

C<$namespace> is an arbitrary string that is included in the C<$id_str>.
If C<$namespace> is C<undef>, the C<screen_name> field given in C<new()> is used.

C<$current_time> is supposed to be L<DateTime> object representing the current time.
If it's C<undef>, C<< DateTime->now >> is used.
If you give C<$current_time>, make sure it is older or equal to the C<$current_time> for
any previous call to C<generate_id()>.
Note also that C<generate()> method calls C<generate_id()> method.

=head1 AUTHOR

Toshio Ito C<< <toshioito [at] cpan.org> >>

=cut



