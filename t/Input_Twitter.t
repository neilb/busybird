use strict;
use warnings;
use Test::More;
use Test::Builder;
use Test::MockObject;
use Test::Exception;
use DateTime::TimeZone;
use List::Util qw(min);
use FindBin;
use lib ("$FindBin::RealBin/lib");
use Test::App::BusyBird::Input_Twitter qw(:all);
use JSON;
use utf8;

BEGIN {
    use_ok('App::BusyBird::Input::Twitter');
}

$App::BusyBird::Input::Twitter::STATUS_TIMEZONE = DateTime::TimeZone->new(name => '+0900');

sub test_mock {
    my ($param, $exp_ids, $msg) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is_deeply(main->mock_timeline($param), [statuses(@$exp_ids)], $msg);
}

note('--- test the mock itself');

test_mock {}, [100,99,98,97,96,95,94,93,92,91], "mock no param";
test_mock {count => 4}, [100,99,98,97], "mock count";
test_mock {per_page => 13}, [100,99,98,97,96,95,94,93,92,91,90,89,88], "mock per_page";
test_mock {rpp => 150}, [reverse(1..100)], "mock rpp";
test_mock {max_id => 50}, [reverse(41..50)], "mock max_id";
test_mock {max_id => 120}, [reverse(91..100)], "mock max_id too large";
test_mock {max_id => -40}, [1], "mock max_id negative";
test_mock {since_id => 95}, [reverse(96 .. 100)], "mock since_id";
test_mock {since_id => 120}, [], "mock since_id too large";
test_mock {since_id => -100}, [reverse(91..100)], "mock since_id negative";
test_mock {max_id => 40, since_id => 35}, [reverse(36..40)], "mock max_id and since_id";
test_mock {max_id => 20, since_id => 20}, [], "mock max_id == since_id";

my $mocknt = mock_twitter();

note('--- iteration by user_timeline');
my $bbin = App::BusyBird::Input::Twitter->new(
    backend => $mocknt, page_next_delay => 0, page_max => 500, logger => undef, transformer => undef
);
is_deeply(
    $bbin->user_timeline({since_id => 10, screen_name => "someone"}),
    [statuses reverse 11..100],
    "user_timeline since_id"
);
test_call $mocknt, 'user_timeline', {screen_name => "someone", since_id => 10};
test_call $mocknt, 'user_timeline', {screen_name => "someone", since_id => 10, max_id => 91};
test_call $mocknt, 'user_timeline', {screen_name => "someone", since_id => 10, max_id => 82};
test_call $mocknt, 'user_timeline', {screen_name => "someone", since_id => 10, max_id => 73};
test_call $mocknt, 'user_timeline', {screen_name => "someone", since_id => 10, max_id => 64};
test_call $mocknt, 'user_timeline', {screen_name => "someone", since_id => 10, max_id => 55};
test_call $mocknt, 'user_timeline', {screen_name => "someone", since_id => 10, max_id => 46};
test_call $mocknt, 'user_timeline', {screen_name => "someone", since_id => 10, max_id => 37};
test_call $mocknt, 'user_timeline', {screen_name => "someone", since_id => 10, max_id => 28};
test_call $mocknt, 'user_timeline', {screen_name => "someone", since_id => 10, max_id => 19};
test_call $mocknt, 'user_timeline', {screen_name => "someone", since_id => 10, max_id => 11};
end_call $mocknt;

$mocknt->clear;
is_deeply(
    $bbin->user_timeline({user_id => 1919, count => 30}),
    [statuses reverse 71..100],
    "user_timeline no since_id"
);
test_call $mocknt, 'user_timeline', {user_id => 1919, count => 30};
end_call $mocknt;

$mocknt->clear;
is_deeply(
    $bbin->user_timeline({max_id => 50, count => 25}),
    [statuses reverse 26..50],
    "user_timeline max_id"
);
test_call $mocknt, 'user_timeline', {count => 25, max_id => 50};
end_call $mocknt;

$mocknt->clear;
is_deeply(
    $bbin->user_timeline({max_id => 20, since_id => 5, count => 5}),
    [statuses reverse 6..20],
    "user_timeline max_id and since_id"
);
test_call $mocknt, 'user_timeline', {count => 5, max_id => 20, since_id => 5};
test_call $mocknt, 'user_timeline', {count => 5, max_id => 16, since_id => 5};
test_call $mocknt, 'user_timeline', {count => 5, max_id => 12, since_id => 5};
test_call $mocknt, 'user_timeline', {count => 5, max_id => 8, since_id => 5};
test_call $mocknt, 'user_timeline', {count => 5, max_id => 6, since_id => 5};
end_call $mocknt;

$bbin = App::BusyBird::Input::Twitter->new(
    backend => $mocknt, page_next_delay => 0, page_max => 2, logger => undef, transformer => undef
);
$mocknt->clear;
is_deeply(
    $bbin->user_timeline({since_id => 5, screen_name => "foo"}),
    [statuses reverse 82..100],
    "page_max option"
);
test_call $mocknt, 'user_timeline', {screen_name => "foo", since_id => 5};
test_call $mocknt, 'user_timeline', {screen_name => "foo", since_id => 5, max_id => 91};
end_call $mocknt;

$bbin = App::BusyBird::Input::Twitter->new(
    backend => $mocknt, page_next_delay => 0, page_max_no_since_id => 3, logger => undef, transformer => undef
);
$mocknt->clear;
is_deeply(
    $bbin->user_timeline({max_id => 80, count => 11}),
    [statuses reverse 50..80],
    "page_max_no_since_id option"
);
test_call $mocknt, 'user_timeline', {count => 11, max_id => 80};
test_call $mocknt, 'user_timeline', {count => 11, max_id => 70};
test_call $mocknt, 'user_timeline', {count => 11, max_id => 60};
end_call $mocknt;

$bbin = App::BusyBird::Input::Twitter->new(
    backend => $mocknt, page_next_delay => 0, logger => undef, transformer => undef
);
foreach my $method_name (qw(home_timeline list_statuses search)) {
    note("--- iteration by $method_name");
    $mocknt->clear;
    is_deeply(
        $bbin->$method_name({max_id => 40, since_id => 5, count => 20}),
        [statuses reverse 6..40],
        "$method_name iterates"
    );
    test_call $mocknt, $method_name, {count => 20, since_id => 5, max_id => 40};
    test_call $mocknt, $method_name, {count => 20, since_id => 5, max_id => 21};
    test_call $mocknt, $method_name, {count => 20, since_id => 5, max_id => 6};
    end_call $mocknt;
}

note('--- public_statuses should never iterate');
$bbin = App::BusyBird::Input::Twitter->new(
    backend => $mocknt, page_next_delay => 0, page_max_no_since_id => 10, logger => undef, transformer => undef
);
$mocknt->clear;
is_deeply(
    $bbin->public_timeline(),
    [statuses reverse 91..100],
    "public_timeline does not iterate even if page_max_no_since_id > 1"
);
test_call $mocknt, 'public_timeline', {};
end_call $mocknt;

{
    note('--- it should return undef if backend throws an exception.');
    my $diemock = Test::MockObject->new;
    my $call_count = 0;
    $diemock->mock('user_timeline', sub {
        my ($self, $params) = @_;
        $call_count++;
        if($call_count == 1) {
            return mock_timeline($self, $params);
        }else {
            die "Some network error.";
        }
    });
    my $diein = App::BusyBird::Input::Twitter->new(
        backend => $diemock, page_next_delay => 0, logger => undef, transformer => undef
    );
    my $result;
    lives_ok { $result = $diein->user_timeline({since_id => 10, count => 5}) } '$diein should not throw exception even if backend does.';
    ok(!defined($result), "the result should be undef then.") or diag("result is $result");
}

{
    note('--- transforms');
    my $tmock = Test::MockObject->new;
    my $apiurl = 'http://hoge.com/';
    $tmock->mock($_, \&mock_timeline) foreach qw(home_timeline);
    $tmock->mock('search', \&mock_search);
    $tmock->mock('-apiurl', sub { $apiurl });
    $bbin = App::BusyBird::Input::Twitter->new(
        backend => $tmock, page_next_delay => 0, logger => undef
    );
    is_deeply(
        $bbin->transform_status_id({ id => 10, in_reply_to_status_id => 55}),
        {
            id => "${apiurl}10", in_reply_to_status_id => "${apiurl}55",
            busybird => { original => {
                id => 10, in_reply_to_status_id => 55
            } }
        },
        "transform_status_id"
    );
    is_deeply(
        $bbin->transform_search_status({
            id => 10, from_user_id => 88, from_user => "hoge",
            created_at => 'Thu, 06 Oct 2011 19:36:17 +0000'
        }),
        {
            id => 10, user => {
                id => 88,
                screen_name => "hoge"
            },
            created_at => 'Thu Oct 06 19:36:17 +0000 2011'
        },
        "transform_search_status"
    );
    is_deeply(
        $bbin->transform_timezone({ id => 5, created_at => "Sat Aug 25 17:26:51 +0000 2012" }, "+0900"),
        {
            id => 5, created_at => "Sun Aug 26 02:26:51 +0900 2012"
        },
        "transform_timezone"
    );
    is_deeply(
        $bbin->transform_timezone({id => 10, created_at => 'Mon, 31 Dec 2012 22:01:43 +0000'}),
        { id => 10, created_at => 'Tue Jan 01 07:01:43 +0900 2013' },
        'transform_timezone to local'
    );
    {
        local $App::BusyBird::Input::Twitter::STATUS_TIMEZONE
            = DateTime::TimeZone->new(name => '-0500');
        is_deeply(
            $bbin->transform_timezone({id => 10, created_at => 'Mon, 31 Dec 2012 22:01:43 +0000'}),
            { id => 10, created_at => 'Mon Dec 31 17:01:43 -0500 2012' },
            'transform_timezone to local (another one)'
        );
    }
    is_deeply(
        $bbin->transform_permalink({ id => 5, user => { screen_name => "hoge" } }),
        { id => 5, user => {screen_name => "hoge"},
          busybird => { status_permalink => "${apiurl}hoge/status/5" } },
        'transform_permalink'
    );

    is_deeply(
        $bbin->transformer_default([decode_json(q{
{
            "id": 5, "id_str": "5", "created_at": "Wed, 05 Dec 2012 14:09:11 +0000",
            "in_reply_to_status_id": 12, "in_reply_to_status_id_str": "12",
            "from_user": "foobar",
            "from_user_id": 100,
            "from_user_id_str": "100",
            "true_flag": true,
            "false_flag": false,
            "null_value": null
        }
})]),
        [{
            id => "${apiurl}5", id_str => "${apiurl}5",
            in_reply_to_status_id => "${apiurl}12",
            in_reply_to_status_id_str => "${apiurl}12",
            created_at => "Wed Dec 05 23:09:11 +0900 2012",
            true_flag => JSON::true,
            false_flag => JSON::false,
            null_value => undef,
            user => {
                screen_name => "foobar",
                id => 100,
                id_str => "100"
            },
            busybird => {
                status_permalink => "${apiurl}foobar/status/5",
                original => {
                    id => 5,
                    id_str => "5",
                    in_reply_to_status_id => 12,
                    in_reply_to_status_id_str => "12",
                }
            }
        }],
        'transformer_default'
    );
}

done_testing();
