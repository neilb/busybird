package BusyBird::Main;
use strict;
use warnings;


our $VERSION = '0.01';

1;

=pod

=head1 NAME

BusyBird::Main - main application object of BusyBird

=head1 VERSION

0.01

=head1 SYNOPSIS

    Write synopsis!!

=head1 DESCRIPTION

L<BusyBird::Main> is the main application object of L<BusyBird>.
It keeps application configuration and timelines (L<BusyBird::Timeline> objects).

=head1 CLASS METHODS

=head2 $main = BusyBird::Main->new()

Creates a L<BusyBird::Main> object.

Users usually don't have to call this method.
The singleton instance of L<BusyBird::Main> object is created and obtained
by C<busybird()> method from L<BusyBird> module.
See L<BusyBird::Tutorial> for detail.

=head1 OBJECT METHODS

=head2 $app = $main->to_app()

Creates and returns a L<PSGI> application object from the C<$main> object.

=head2 $timeline = $main->timeline($name)

Returns the C<$timeline> whose name is C<$name> from the C<$main>.
C<$timeline> is a L<BusyBird::Timeline> object.

If there is no timeline named C<$name> in C<$main>, a new timeline is created, installed and returned.
C<$name> must be a string consisting only of C<[a-zA-Z0-9_-]>.


=head2 $timeline = $main->get_timeline($name)

Returns the C<$timeline> whose name is C<$name> from the C<$main>.

If there is no timeline named C<$name> in C<$main>, it returns C<undef>.


=head2 @timelines = $main->get_all_timelines()

Returns the list of all timelines installed in the C<$main>.

=head2 $main->install_timeline($timeline)

Installs the given C<$timeline> to the C<$main>.

If a timeline with the same name as the given C<$timeline> is already installed in the C<$main>,
the old timeline is replaced by the given C<$timeline>.

=head2 $timeline = $main->uninstall_timeline($name)

Uninstalls the timeline whose name is C<$name> from the C<$main>.
It returns the uninstalled C<$timeline>.

If there is no timeline named C<$name>, it returns C<undef>.

=head2 $status_storage = $main->default_status_storage([$status_storage])

Accessor for the default StatusStorage object used by C<$main>.

A StatusStorage is an object where timelines save their statuses.
When a timeline is created by C<timeline()> method, the default StatusStorage is used for the timeline.

When an argument is given, this method sets the default StatusStorage to the given C<$status_storage> object.
This method returns the current (changed) default StatusStorage object.

Note that the default StatusStorage object is referred to only when creating timelines via C<timeline()> method.
Existing timelines are not affected by changing the default StatusStorage object.

A StatusStorage object is an object implementing L<BusyBird::StatusStorage> interface specification.
For example, the following modules can be used as StatusStorage.

=over

=item *

L<BusyBird::StatusStorage::Memory> - storage in the process memory

=back

See each module's documentation for details.


=head2 $watcher = $main->watch_unacked_counts($level, $watch_spec, $callback->($w, $tl_unacked_counts, $error))

Watch updates in numbers of unacked statuses (i.e. unacked counts) in timelines.

When this method is called, the current unacked counts are compared with the unacked counts given in the arguments (C<$level> and C<$watch_spec>).
If the current and given unacked counts are different, the C<$callback> subroutine reference is called
with the current unacked counts (C<$tl_unacked_counts>).
If the current and given unacked counts are the same, the execution of the C<$callback> is delayed until there is some difference between them.

C<$level> is the status level you want to watch.
It is either an integer number or the string of C<'total'>.
If an integer is specified, the unacked counts in that status level are watched.
If C<'total'> is specified, the total unacked counts are watched.

C<$watch_spec> is a hash-ref specifying the given unacked count for each timeline.
Its key is the name of the timeline you want to watch, and its value
is the given unacked counts for the timeline in the status level specified by C<$level>.
You can watch multiple timelines by a single call of this method.

C<$callback> is a subroutine reference that is called when the current unacked counts
are different from the given unacked counts in some way.

In success, C<$callback> is called with two arguments (C<$w> and C<$tl_unacked_counts>).
C<$w> is an L<BusyBird::Watcher> object representing the watch.
C<$tl_unacked_counts> is a hash-ref describing the current unacked counts for watched timelines.

For example, if you call this method with the following arguments,

    $level = 'total';
    $watch_spec = {
        TL1 => 0, TL2 => 0, TL3 => 5
    };

This means the caller assumes there is no unacked statuses in TL1 and TL2,
and there are 5 unacked statuses in TL3.
Then, the C<$callback> may be called with C<$tl_unacked_counts> like,

    $tl_unacked_counts = {
        TL1 => {
            total => 2,
            0     => 1,
            2     => 1,
        },
    };

This means the timeline named C<'TL1'> actually has 2 unacked statuses in total,
one of which is in level 0 and the other is in level 2.

Note that although you can specify multiple timelines in C<$watch_spec>,
the returned C<$tl_unacked_counts> may not contain all the specified timelines.

In failure, C<$callback> is called with three arguments, and the third argument (C<$error>) describes the error.

The return value of this method (C<$watcher>) is the same instance as C<$w>.
You can use C<< $watcher->cancel() >> or C<< $w->cancel() >> method to cancel the watch.
Otherwise, the C<$callback> is repeatedly called whenever some updates in unacked counts happen and
the current and given unacked counts are different.

In C<$watch_spec>, the timeline names that are not in C<$main> are ignored.
If there is no existent timeline name in C<$watch_spec>, this method croaks.



=head1 AUTHOR

Toshio Ito C<< <toshioito [at] cpan.org> >>

=cut


