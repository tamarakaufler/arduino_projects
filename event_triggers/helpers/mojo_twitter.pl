use Mojolicious::Lite;
use Net::Twitter;
use Config::Tiny;
use File::HomeDir;
use DateTime;
use Device::SerialPort;

use Data::Dumper qw(Dumper);
use Data::Printer;


## CONFIGURATION AND INITIALIZATION
##---------------------------------
binmode STDOUT, ":encoding(UTF-8)";

my $config_file = 'twitter_config';
my $interval    = 5;

my $port = Device::SerialPort->new("/dev/tty.usbserial");

if (defined $port) {
	$port->baudrate(19200); # can be changed
	$port->databits(8); 	# do not change
	$port->parity("none");  # do not change
	$port->stopbits(1);     # do not change

	#-----------------------------------------------------------
	## IS THIS NECESSARY?
	
	# now catch gremlins at start
	my $tEnd = time()+2; # 2 seconds in future
	while (time()< $tEnd) { # end latest after 2 seconds
	  my $c = $port->lookfor(); # char or nothing
	  next if $c eq ""; # restart if noting
	  # print $c; # uncomment if you want to see the gremlin
	  last;
	}
	while (1) { # and all the rest of the gremlins as they come in one piece
	  my $c = $port->lookfor(); # get the next one
	  last if $c eq ""; # or we're done
	  # print $c; # uncomment if you want to see the gremlin
	}
	#-----------------------------------------------------------

}

## read in mongodb or file configuration
##	file:
my $config = Config::Tiny->read( $config_file, 'utf8' );

## 	mongodb:
##	.......	

my $event_type = '';

get '/' => sub {
  my $c = shift;
  $c->render('text' => 'This is the brain of the hackathon application');
};

get '/twitter' => sub {
  my $c = shift;

  return if $event_type eq 'twitter';

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

  ## talk to arduino's analogue port and send over the 
  $port->write("$no_of_tweets of tweets") if defined $port;

  $c->render(text => "There were " . scalar @{$r->{statuses}} . " tweets about $search in the last $interval minutes");
};

app->log->debug('Starting application');
app->start;
