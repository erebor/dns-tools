require 'sinatra'
require 'escape'
require 'erb'
require 'whois'

DNS_TYPES = %w[a mx ns any txt srv aaaa]
IP_REGEXP = /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/

class BadInputError < StandardError; end

helpers do
  def clean_hostname(hn)
    hn = hn.strip.sub(/[><|&;\s].*/, '')
    raise BadInputError if hn.length == 0
    hn
  end

  def execute(*args)
    options = Hash === args.last ? args.pop : {}
    "<strong>% " + (options[:display] || args).join(' ') + "</strong>\n" +
    `#{Escape.shell_command(args)}`.strip
  end
end

before do
  headers 'Cache-Control' => 'public, max-age=60'
  @hostname = nil
  @output = nil
  @type = nil
end

get '/' do
  headers 'Cache-Control' => 'public, max-age=900'
  erb :index
end

get '/dig/:type/:hostname' do
  @type = DNS_TYPES.include?(params[:type]) ? params[:type] : 'a'
  @hostname = clean_hostname(params[:hostname])
  @output = execute('dig', @type, @hostname)
  erb :index
end

get '/reverse/:hostname' do
  raise BadInputError unless params[:hostname] =~ IP_REGEXP
  @hostname = params[:hostname]
  @output = execute('dig', '-x', @hostname)
  erb :index
end

get '/lookup/:hostname' do
  @hostname = clean_hostname(params[:hostname])
  @output = execute('nslookup', @hostname)
  erb :index
end

get '/whois/:hostname' do
  @hostname = clean_hostname(params[:hostname])
  @output = Whois.lookup(@hostname).to_s
  erb :index
end

get '/headers/*' do
  @hostname = clean_hostname(params[:splat].join)
  @output = execute('curl', '-ISs', 'http://' + @hostname, :display => ['curl', '-I', 'http://' + @hostname])
  erb :index
end

['/dig/:hostname', '/:hostname'].each do |path|
  get path do
    @hostname = clean_hostname(params[:hostname])
    @output = execute('dig', 'a', @hostname)
    erb :index
  end
end

not_found do
  redirect '/'
end

error BadInputError do
  redirect '/'
end
