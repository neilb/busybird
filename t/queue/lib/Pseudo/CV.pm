package Pseudo::CV;
use strict;
use warnings;
use EV;

sub new {
    my ($class) = @_;
    return bless {
        count => 0,
        returned => [],
        sent => 0,
    }, $class;
}

sub recv {
    my $self = shift;
    if($self->{sent}) {
        return wantarray ? @{$self->{returned}} : $self->{returned}[0];
    }
    EV::run;
    return wantarray ? @{$self->{returned}} : $self->{returned}[0];
}

sub send {
    my ($self, @param) = @_;
    if($self->{sent}) {
        return;
    }
    $self->{sent} = 1;
    @{$self->{returned}} = @param;
    EV::break;
}

sub begin {
    my ($self) = @_;
    $self->{count}++;
}

sub end {
    my ($self) = @_;
    $self->{count}-- if $self->{count} > 0;
    if($self->{count} == 0) {
        $self->send;
    }
}

1;