use strict;
use warnings;
use Test::More;
use Test::Builder;
use BusyBird::Main;
use BusyBird::Log;
use BusyBird::StatusStorage::Memory;
use JSON qw(decode_json);
use utf8;

BEGIN {
    use_ok("BusyBird::Main::PSGI::View");
}

$BusyBird::Log::Logger = undef;

sub test_psgi_response {
    my ($psgi_res, $exp_code, $label) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is(ref($psgi_res), "ARRAY", "$label: top array-ref OK");
    is($psgi_res->[0], $exp_code, "$label: status code OK");
    is(ref($psgi_res->[1]), "ARRAY", "$label: header array-ref OK");
    is(ref($psgi_res->[2]), "ARRAY", "$label: content array-ref OK");
}

sub test_json_response {
    my ($psgi_res, $exp_code, $exp_obj, $label) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    test_psgi_response($psgi_res, $exp_code, $label);
    my $got_obj = decode_json(join("", @{$psgi_res->[2]}));
    is_deeply($got_obj, $exp_obj, "$label: json object OK");
}

sub create_main {
    my $main = BusyBird::Main->new;
    $main->set_config(
        default_status_storage => BusyBird::StatusStorage::Memory->new
    );
    $main->timeline('test');
    return $main;
}

{
    note("--- response methods");
    my $main = create_main();
    my $view = new_ok("BusyBird::Main::PSGI::View", [main_obj => $main]);

    test_psgi_response($view->response_notfound(), 404, "notfound");
    
    test_json_response($view->response_json(200, {}),
                       200, {error => undef}, "json, 200, empty hash");
    test_json_response($view->response_json(200, [0,1,2]),
                       200, [0,1,2], "json, 200, array");
    test_json_response($view->response_json(400, {}),
                       400, {}, "json, 400, empty hash");
    test_json_response($view->response_json(500, {error => "something bad happened"}),
                       500, {error => "something bad happened"}, "json, 500, error set");
    test_json_response($view->response_json(200, {main => $main}),
                       500, {error => "error while encoding to JSON."}, "json, 500, unable to encode");

    test_psgi_response($view->response_statuses(statuses => [], http_code => 200, format => "html", timeline_name => "test"),
                       200, "statuses success");
    test_psgi_response($view->response_statuses(error => "hoge", http_code => 400, format => "html", timeline_name => "test"),
                       400, "statuses failure");
    test_psgi_response($view->response_statuses(statuses => [], http_code => 200, format => "foobar", timeline_name => "test"),
                       400, "statuses unknown format");

    test_psgi_response($view->response_timeline("test", ""), 200, "existent timeline");
    test_psgi_response($view->response_timeline("hoge", ""), 404, "missing timeline");
}

{
    note("--- template_functions");
    my $main = create_main();
    my $view = BusyBird::Main::PSGI::View->new(main_obj => $main);
    my $funcs = $view->template_functions();

    note("--- -- js"); ## from SYNOPSIS of JavaScript::Value::Escape with a small modification
    is($funcs->{js}->(q{&foo"bar'</script>}), "\\u0026foo\\u0022bar\\u0027\\u003c/script\\u003e", "js filter OK");

    note("--- -- link");
    foreach my $case (
        {label => "escape text", args => ['<hoge>', href => 'http://example.com/'],
         exp => '<a href="http://example.com/">&lt;hoge&gt;</a>'},
        {label => "external href", args => ['foo & bar', href => 'https://www.google.co.jp/search?channel=fs&q=%E3%81%BB%E3%81%92&ie=utf-8&hl=ja#112'],
         exp => '<a href="https://www.google.co.jp/search?channel=fs&q=%E3%81%BB%E3%81%92&ie=utf-8&hl=ja#112">foo &amp; bar</a>'},
        {label => "internal absolute href",
         args => ['hoge', href => '/timelines/hoge/statuses.html?count=10&max_id=http%3A%2F%2Fhoge.com%2F%3Fid%3D31245%26cat%3Dfoo'],
         exp => '<a href="/timelines/hoge/statuses.html?count=10&max_id=http%3A%2F%2Fhoge.com%2F%3Fid%3D31245%26cat%3Dfoo">hoge</a>'},
        {label => "with target and class", args => ['ほげ', href => '/', target => '_blank', class => 'link important'],
         exp => '<a href="/" target="_blank" class="link important">ほげ</a>'},
        {label => "no href", args => ['no link', class => "hogeclass"],
         exp => 'no link'},
        {label => "javascript: href", args => ['alert!', href => 'javascript: alert("hogehoge"); return false;'],
         exp => 'alert!'},
        {label => "empty text", args => ['', href => 'http://empty.net/'],
         exp => '<a href="http://empty.net/"></a>'},
        {label => "undef text", args => [undef], exp => ""},
    ) {
        is($funcs->{link}->(@{$case->{args}}), $case->{exp}, "$case->{label} OK");
    }

    note("--- -- image");
    foreach my $case (
        {label => "external http", args => [src => "http://www.hoge.com/images.php?id=101&size=large"],
         exp => '<img src="http://www.hoge.com/images.php?id=101&size=large" />'},
        {label => "external https", args => [src => "https://example.co.jp/favicon.ico"],
         exp => '<img src="https://example.co.jp/favicon.ico" />'},
        {label => "internal absolute", args => [src => "/static/hoge.png"],
         exp => '<img src="/static/hoge.png" />'},
        {label => "with width, height and class",
         args => [src => '/foobar.jpg', width => "400", height => "300", class => "foo bar"],
         exp => '<img src="/foobar.jpg" width="400" height="300" class="foo bar" />'},
        {label => "no src", args => [], exp => ''},
        {label => "script", args => [src => '<script>alert("hoge");</script>'],
         exp => ''},
        {label => "data:",
         args => [src => 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAAAXNSR0IArs4c6QAAAAxJREFUCNdjuKCgAAAC1AERHXzACQAAAABJRU5ErkJggg=='],
         exp => ''},
        {label => "javascript:", args => [src => 'javascript: alert("hoge");'],
         exp => ''},
    ) {
        is($funcs->{image}->(@{$case->{args}}), $case->{exp}, "$case->{label} OK");
    }

    note("--- -- bb_level");
    foreach my $case (
        {label => "positive level", args => [10], exp => "10"},
        {label => "zero", args => [0], exp => "0"},
        {label => "negative level", args => [-5], exp => "-5"},
        {label => "undef", args => [undef], exp => "0"},
    ) {
        is($funcs->{bb_level}->(@{$case->{args}}), $case->{exp}, "$case->{label} OK");
    }
}

{
    note("--- template_functions_for_timeline");
    my $main = create_main();
    my $view = BusyBird::Main::PSGI::View->new(main_obj => $main);
    my $funcs = $view->template_functions_for_timeline('test');
    $main->set_config(
        time_zone => "UTC",
        time_format => '%Y-%m-%d %H:%M:%S',
        time_locale => 'en_US',
    );

    note("--- -- bb_timestamp");
    foreach my $case (
        {label => 'normal', args => ['Tue May 28 20:10:13 +0900 2013'], exp => '2013-05-28 11:10:13'},
        {label => 'undef', args => [undef], exp => ''},
        {label => 'empty string', args => [''], exp => ''},
    ) {
        is($funcs->{bb_timestamp}->(@{$case->{args}}), $case->{exp}, "$case->{label}: OK");
    }

    note("--- -- bb_status_permalink");
    foreach my $case (
        {label => "complete status",
         args => [{id => "191", user => {screen_name => "hoge"}, busybird => {status_permalink => "http://hoge.com/"}}],
         exp => "http://hoge.com/"},
        {label => "missing status_permalink field",
         args => [{id => "191", user => {screen_name => "hoge"}}],
         exp => "https://twitter.com/hoge/status/191"},
        {label => "unable to build", args => [{id => "191"}], exp => ""},
        {label => "invalid status_permalink",
         args => [{id => "191", busybird => {status_permalink => "javascript: alert('hoge')"}}],
         exp => ""},
    ) {
        is($funcs->{bb_status_permalink}->(@{$case->{args}}), $case->{exp}, "$case->{label}: OK");
    }

    note("--- -- bb_text");
    foreach my $case (
        {label => "HTML special char, no URL, no entity",
         args => [{text => q{foo bar "A & B"} }],
         exp => q{foo bar &quot;A &amp; B&quot;}},
        
        {label => "URL and HTML special char, no entity",
         args => [{id => "hoge", text => 'this contains URL http://hogehoge.com/?a=foo+bar&b=%2Fhoge here :->'}],
         exp => q{this contains URL <a href="http://hogehoge.com/?a=foo+bar&b=%2Fhoge">http://hogehoge.com/?a=foo+bar&amp;b=%2Fhoge</a> here :-&gt;}},
        
        {label => "URL at the top and bottom",
         args => [{text => q{http://hoge.com/toc.html#item5 hogehoge http://foobar.co.jp/q=hoge&page=5}}],
         exp => q{<a href="http://hoge.com/toc.html#item5">http://hoge.com/toc.html#item5</a> hogehoge <a href="http://foobar.co.jp/q=hoge&page=5">http://foobar.co.jp/q=hoge&amp;page=5</a>}},
        
        {label => "Twitter Entities",
         args => [{
             text => q{てすと &lt;"&amp;hearts;&amp;&amp;hearts;"&gt; http://t.co/dNlPhACDcS &gt;"&lt; @debug_ito &amp; &amp; &amp; #test},
             entities => {
                 hashtags => [ { text => "test", indices => [106,111] } ],
                 user_mentions => [ {
                     "name" => "Toshio Ito",
                     "id" => 797588971,
                     "id_str" => "797588971",
                     "indices" => [ 77, 87 ],
                     "screen_name" => "debug_ito"
                 } ],
                 symbols => [],
                 urls => [ {
                     "display_url" => "google.co.jp",
                     "expanded_url" => "http://www.google.co.jp/",
                     "url" => "http://t.co/dNlPhACDcS",
                     "indices" => [ 44, 66 ]
                 } ]
             }
         }],
         exp => q{てすと &amp;lt;&quot;&amp;amp;hearts;&amp;amp;&amp;amp;hearts;&quot;&amp;gt; <a href="http://t.co/dNlPhACDcS">google.co.jp</a> &amp;gt;&quot;&amp;lt; <a href="https://twitter.com/debug_ito">@debug_ito</a> &amp;amp; &amp;amp; &amp;amp; <a href="https://twitter.com/search?q=%23test&src=hash">#test</a>}},

        {label => "2 urls entities",
         args => [{
             text => q{http://t.co/0u6Ki0bOYQ - plain,  http://t.co/0u6Ki0bOYQ - with scheme},
             entities => {
                 "hashtags" => [],
                 "user_mentions" => [],
                 "symbols" => [],
                 "urls" => [
                     {
                         "display_url" => "office.com",
                         "expanded_url" => "http://office.com",
                         "url" => "http://t.co/0u6Ki0bOYQ",
                         "indices" => [ 0, 22 ]
                     },
                     {
                         "display_url" => "office.com",
                         "expanded_url" => "http://office.com",
                         "url" => "http://t.co/0u6Ki0bOYQ",
                         "indices" => [ 33, 55 ]
                     }
                 ]
             }
         }],
         exp => q{<a href="http://t.co/0u6Ki0bOYQ">office.com</a> - plain,  <a href="http://t.co/0u6Ki0bOYQ">office.com</a> - with scheme}},
    ) {
        is($funcs->{bb_text}->(@{$case->{args}}), $case->{exp}, "$case->{label}: OK");
    }
    
    fail("TODO: more tests for bb_text");
}


done_testing();

