require 'rubygems'
require 'sinatra'
require 'escape'
require 'erb'

IP_REGEXP = /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/

class BadInputError < StandardError; end

helpers do
  def clean_hostname(hn)
    hn = hn.strip.sub(/[><|&;\s].*/, '')
    raise BadInputError if hn.length == 0
    hn
  end

  def execute(*args)
    "<strong>" + args.join(' ') + "</strong>\n" +
    `#{Escape.shell_command(args)}`.strip
  end
end

before do
  headers 'Cache-Control' => 'public, max-age=60'
  @hostname = nil
  @output = nil
end

get '/' do
  headers 'Cache-Control' => 'public, max-age=900'
  erb :index
end

['/dig/:type/:hostname', '/dig/:hostname'].each do |path|
  get path do
    type = %w[a mx ns any txt srv aaaa].include?(params[:type]) ? params[:type] : 'a'
    @hostname = clean_hostname(params[:hostname])
    @output = execute('dig', type, @hostname)
    erb :index
  end
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
  @output = execute('whois', @hostname)
  erb :index
end

get '/:hostname' do
  redirect "/dig/#{params[:hostname]}"
end

not_found do
  redirect '/'
end

error BadInputError do
  redirect '/'
end