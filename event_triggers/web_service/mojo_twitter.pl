use Mojolicious::Lite;
use Mojo::UserAgent;
use Net::Twitter;
use Config::Tiny;
use File::HomeDir;
use DateTime;

use Data::Dumper qw(Dumper);
use Data::Printer;


## CONFIGURATION AND INITIALIZATION
##---------------------------------
binmode STDOUT, ":encoding(UTF-8)";

my $config_file = 'twitter_config';
my $interval    = 5;

## read in mongodb or file configuration
##	file:
my $config = Config::Tiny->read( $config_file, 'utf8' );

## 	mongodb:
##	.......	

my $event_type = '';

my $ua = Mojo::UserAgent->new;

get '/' => sub {
  my $c = shift;
  $c->render('text' => 'This is the brain of the hackathon application');
};

get '/twitter' => sub {
  my $c = shift;

  return if $event_type eq 'twitter';

  $event_type = 'twitter';

  my $search = $c->param('q')     || 'photobox';

  my ($consumer_key, $consumer_secret)     = ($config->{TKaufler}{consumer_key}, $config->{TKaufler}{consumer_secret});
  my ($access_token, $access_token_secret) = ($config->{TKaufler}{access_token}, $config->{TKaufler}{access_token_secret});

  warn ">>> $search";
 
  my $nt = Net::Twitter->new( 
                              ssl                 =>  1,  
			                  traits          	  => [ qw(API::RESTv1_1) ],
                              consumer_key        => $consumer_key,
                              consumer_secret 	  => $consumer_secret,
                              access_token        => $access_token,
                              access_token_secret => $access_token_secret,
                            );

  my $since = DateTime->now->subtract(minutes => $interval);
  my $r = $nt->search($search, { '-since' =>  $since, count => 100 });

  my $i = 0;
  for my $status ( @{$r->{statuses}} ) {
	say STDERR "---------------------------------------------";
	say ">>> $i <<<";
	say STDERR "$status->{user}{screen_name}:$status->{text}";
	say STDERR "---------------------------------------------";
	$i++;
  }

  my $no_of_tweets = scalar @{$r->{statuses}};

  ## end a request to arduino's web server 

  $ua->get("http://192.168.1.77/twitter?$no_of_tweets");

  $c->render(text => "There were " . scalar @{$r->{statuses}} . " tweets about $search in the last $interval minutes");
};

get '/email' => sub {
  my $c = shift;

  return if $event_type eq 'email';

  $event_type = 'email';

  my $subject = $c->param('q')     || 'CODE RED';

  $ua->get("http://192.168.1.77/email?$subject");

  $c->render(text => "Will bubble up if an email with subject [$subject] was received");

};


app->log->debug('Starting application');
app->start;
