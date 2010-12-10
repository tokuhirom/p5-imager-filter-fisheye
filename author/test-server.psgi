use strict;
use Imager;
use Imager::AutoDie;
use Plack::Request;
use LWP::UserAgent;
use Plack::Builder;
use Imager::Filter::FishEye;
use List::Util qw/min/;

sub dispatch_image {
    my $req = shift;

    my $src = $req->param('src');
    my $jpeg_src = do {
        my $ua = LWP::UserAgent->new();
        my $res = $ua->get($src);
        $res->is_success or die $res->status_line;
        $res->content;
    };
    my $filtered = Imager->new(data => $jpeg_src);
    my $size = min( $filtered->getheight(), $filtered->getwidth() );
    my $crop_y = ( ( $filtered->getheight() - $size ) / 2 );
    my $crop_x = ( ( $filtered->getwidth() - $size ) / 2 );
    $filtered->filter(type => 'fisheye');
    my $cropped = $filtered->crop(
        left   => $crop_x,
        right  => $filtered->getwidth() - $crop_x,
        top    => $crop_y,
        bottom => $filtered->getheight() - $crop_y,
    );
    my $mask = Imager->new(xsize => $cropped->getwidth(), ysize => $cropped->getheight(), channels => 1);
    $mask->box(filled => 1, color => 'black');
    $mask->circle(color => 'white', r => min($cropped->getwidth(), $cropped->getheight())/2, filled =>1, aa => 1);
    my $img = Imager->new(xsize => $cropped->getwidth(), ysize => $cropped->getwidth());
    $img->compose(
        src      => $cropped,
        mask     => $mask,
        opacity  => 1,
        tx       => 0,
        ty       => 0,
    );
    $img->write(type => 'jpeg', data => \my $out);
    return [200, [], [$out]];
}


my $app = sub {
    my $req = Plack::Request->new(shift);
    if (my $src = $req->param('src')) {
        return dispatch_image($req);
    } else {
        return [200, [], ["Usage: @{[ $req->env->{HTTP_HOST} ]}/?src=...&d=...&r=..."]];
    }
};

builder {
    enable 'ContentLength';
    $app;
};
