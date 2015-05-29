use Mojolicious::Lite;
use Mojo::UserAgent;
use Net::Twitter;
use Config::Tiny;
use File::HomeDir;
use DateTime;

use Mail::IMAPTalk;
use IO::Socket::SSL;
use Parallel::ForkManager;
use LWP::UserAgent;
use HTTP::Request;
use JSON::XS qw(decode_json encode_json);

use Data::Dumper qw(Dumper);
use Data::Printer;

## CONFIGURATION AND INITIALIZATION
##---------------------------------
binmode STDOUT, ":encoding(UTF-8)";

my $config_file = 'twitter_config';
my $interval    =  5;
my $arduino_IP  = "192.168.162.88";

## read in mongodb or file configuration
##	file:
my $config = Config::Tiny->read( $config_file, 'utf8' );

## 	mongodb:
##	.......	

my $pm = Parallel::ForkManager->new(10);

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

  # kill any forked processes
  my @pids = $pm->running_procs;
  kill 9,@pids;
  $pm->wait_all_children;

  my $search = $c->param('q')     || 'photobox';

  my ($consumer_key, $consumer_secret)     = ($config->{TKaufler}{consumer_key}, $config->{TKaufler}{consumer_secret});
  my ($access_token, $access_token_secret) = ($config->{TKaufler}{access_token}, $config->{TKaufler}{access_token_secret});

  warn ">>> $event_type";

  my $nt = Net::Twitter->new( 
                              ssl                 =>  1,  
                              traits              => [ qw(API::RESTv1_1) ],
                              consumer_key        => $consumer_key,
                              consumer_secret     => $consumer_secret,
                              access_token        => $access_token,
                              access_token_secret => $access_token_secret,
                            );

  my $since = DateTime->now->subtract(minutes => $interval);
  my $r = $nt->search($search, { '-since' =>  $since, count => 100 }); 

##  my $i = 0;
##  for my $status ( @{$r->{statuses}} ) { 
##    say STDERR "---------------------------------------------";
##    say ">>> $i <<<";
##    say STDERR "$status->{user}{screen_name}:$status->{text}";
##    say STDERR "---------------------------------------------";
##    $i++;
##  }

  my $no_of_tweets = scalar @{$r->{statuses}};
 
  ## send a request to arduino's web server 
  $ua->get("http://$arduino_IP/twitter?$no_of_tweets");
##  $ua->get("http://$arduino_IP/twitter?$no_of_tweets" => sub {
##  							  	my ($ua, $tx) = @_;
##								warn "Received response from arduino";
##  								$event_type = '';
##							  	$c->render(text => "$no_of_tweets no of tweets found for $search");
##							 });

  $c->render(text => "$no_of_tweets no of tweets found for $search");

};

get '/email' => sub {
	my $c = shift;

	return if $event_type eq 'email';
	$event_type = 'email';

	# kill any forked processes
 	my @pids = $pm->running_procs;
 	kill 9,@pids;
 	$pm->wait_all_children;

	if ($pm->start) {
		$c->render(text => 'Email listener launched');
		return;
	}

	my $subject = $c->param('q') || 'CODE RED';

	my $server = 'imap.gmail.com:993';
	my $user = 'pbxhackathon2015';
	my $pwd = 'hollysophie';
	my $delay = 60;

	while (1) {

		warn 'Checking for messages';

		my $sock = IO::Socket::SSL->new("$server") or
        		die "Problem connecting via SSL to $server: ", IO::Socket::SSL::errstr();
		my $ofh = select($sock); $| = 1; select ($ofh);

		my $imap = Mail::IMAPTalk->new(
        		Socket => $sock,
        		State  => Mail::IMAPTalk::Authenticated,
        		Username => $user,
        		Password => $pwd,
        		Uid      => 1 )
        		|| die "Failed to connect/login to IMAP server";

		$imap->select('INBOX') || die $@;

		my @messageIds = $imap->search('not','seen','subject',$subject);
        
		warn Dumper \@messageIds;

		if (@messageIds) {
			foreach my $msgId (@messageIds) {
                        
				#my $message = $imap->fetch($msgId,'envelope');
				#warn Dumper $message;

				$imap->store($msgId,'+flags','(\\seen)');
			}

			warn 'calling device';

			$ua->get("http://$arduino_IP/email"  => {'Content-Type' => '*/*'});

			$event_type = '';
			last;
		}
        
		sleep($delay);
	}

	$pm->finish;
};

get '/hipchat' => sub {
	my $c = shift(@_);

	return if $event_type eq 'hipchat';
	$event_type = 'hipchat';

	# kill any forked processes
 	my @pids = $pm->running_procs;
 	kill 9,@pids;
 	$pm->wait_all_children;
	
	my $subject = $c->param('q') || 'code red';

	if ($pm->start) {
		$c->render(text => 'hipchat listener launched');
		return;
	}

	my $ua = LWP::UserAgent->new();
	my $checkUrl = 'https://api.hipchat.com/v2/room/Tornado/history?max-results=1&auth_token=wRbKn8zQzez7f1QjNv6Y5MefPADxmXhiIdabeyGA';

	while (1) { 
		warn 'checking hipchat for messages';

		my $request = HTTP::Request->new();
		$request->uri($checkUrl);
		$request->method('GET');

		my $response = $ua->request($request);

		my $found = 0;

		if ($response->is_success) {
			my $json = $response->content();
			my $data;
			eval {
				$data = decode_json($json);
			};

			if (exists($data->{'items'}) && (ref($data->{'items'}) eq 'ARRAY')) {
				foreach my $item (@{$data->{'items'}}) {
					if (exists($item->{'message'})) {
						if ($item->{'message'} =~ /$subject/) {
							warn "Message found with '" . $subject . "' in it!";
							$found = 1;

							my $request = HTTP::Request->new();

							$request->header('Authorization' => 'Bearer wRbKn8zQzez7f1QjNv6Y5MefPADxmXhiIdabeyGA');
							$request->header('content-type' => 'application/json');

							my $data = {
								"color" => "green",
								"message_format" => "text",
								"message" => "Message sent to device"
							};

							$data = encode_json($data);

							$request->content($data);
							$request->uri('https://api.hipchat.com/v2/room/Tornado/notification');
							$request->method('POST');

							my $response = $ua->request($request);

							last;
						}
					}
				}
			}
		}

		last if $found;

		sleep(5);
	}

	$event_type = '';
	$pm->finish();
};

app->log->debug('Starting application');
app->start;
