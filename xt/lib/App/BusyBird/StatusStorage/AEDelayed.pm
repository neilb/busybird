package App::BusyBird::StatusStorage::AEDelayed;
use strict;
use warnings;
use AnyEvent;

sub new {
    my ($class, %args) = @_;
    my $self = bless {%args}, $class;
    return $self;
}

sub _delayed_call {
    my ($self, @args) = @_;
    my $method;
    $method = (caller(1))[3];
    $method =~ s/^.*:://g;
    my $delay = $self->{delay_sec} || 0;
    my $w; $w = AnyEvent->timer(
        after => $delay,
        cb => sub {
            undef $w;
            $self->{backend}->$method(@args);
        }
    );
}

sub get_statuses { my $self = shift; $self->_delayed_call(@_) }
sub put_statuses { my $self = shift; $self->_delayed_call(@_) }
sub confirm_statuses { my $self = shift; $self->_delayed_call(@_) }
sub delete_statuses { my $self = shift; $self->_delayed_call(@_) }

sub get_unconfirmed_counts {
    my ($self, @args) = @_;
    return $self->{backend}->get_unconfirmed_counts(@args);
}


1;

=pod

=head1 NAME

App::BusyBird::StatusStorage::AEDelayed - StatusStorage wrapper for delayed operation based on AnyEvent

=head1 DESCRIPTION

This is a StatusStorage wrapper just for testing asynchronous operations for C<*_statuses> methods.

=head1 CLASS METHODS

=head2 $storage = App::BusyBird::StatusStorage::AEDelayed->new(%args)

C<%args> includes:

=over

=item C<backend> => STATUS_STORAGE

=item C<delay_sec> => NUMBER

=back

=head1 AUTHOR

Toshio Ito C<< toshioito [at] cpan.org >>

=cut
