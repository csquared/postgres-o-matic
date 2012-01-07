require 'bundler'
Bundler.require

ENV.use(SmartEnv::UriProxy)
STDOUT.sync = true
DB   = Sequel.connect ENV['DATABASE_URL'].to_s
@@uuid = UUID.new

class App < Sinatra::Base
  use Rack::Session::Cookie, secret: ENV['SSO_SALT']

  helpers do
    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && 
      @auth.credentials == [ENV['HEROKU_USERNAME'], ENV['HEROKU_PASSWORD']]
    end

    def show_request
      body = request.body.read
      unless body.empty?
        STDOUT.puts "request body:"
        STDOUT.puts(@json_body = JSON.parse(body))
      end
      unless params.empty?
        STDOUT.puts "params: #{params.inspect}"
      end
    end

    def json_body
      @json_body || (body = request.body.read && JSON.parse(body))
    end
  end
  
  # sso landing page
  get "/" do
    halt 403, 'not logged in' unless session[:heroku_sso]
    #response.set_cookie('heroku-nav-data', value: session[:heroku_sso])
    @resource = DB[:resources].filter(:id => session[:resource]).first
    halt 404 if @resource[:status] == 'inactive'
    @tables = []
    Sequel.postgres(@resource[:id], 
                    :host => ENV['DATABASE_URL'].host, 
                    :user => @resource[:username], 
                    :password => @resource[:password]) do |db|
      @tables = db.tables
    end
    @email    = session[:email]
    haml :index
  end

  def sso
    pre_token = params[:id] + ':' + ENV['SSO_SALT'] + ':' + params[:timestamp]
    token = Digest::SHA1.hexdigest(pre_token).to_s
    halt 403 if token != params[:token]
    halt 403 if params[:timestamp].to_i < (Time.now - 2*60).to_i

   # halt 404 unless 
    session[:resource]   = params[:id]

    response.set_cookie('heroku-nav-data', value: params['nav-data'])
    session[:heroku_sso] = params['nav-data']
    session[:email]      = params[:email]

    redirect '/'
  end
  
  # sso sign in
  get "/heroku/resources/:id" do
    show_request
    sso
  end

  post '/sso/login' do
    puts params.inspect
    sso
  end

  # provision
  post '/heroku/resources' do
    show_request
    protected!
    status 201
    username = "user_" + SecureRandom.hex(10)
    password = SecureRandom.hex(10)
    dbname   = "db_"   + @@uuid.generate.gsub(/-/,'_') 

    DB << "CREATE DATABASE #{dbname}"
    DB << "CREATE USER #{username} WITH PASSWORD '#{password}'"
    DB << "GRANT ALL ON DATABASE #{dbname} TO #{username}"

    DB[:resources].insert(:id => dbname, :username => username, 
                          :password => password, :plan => json_body['plan'], :status => "active")

    db_url = "postgres://#{username}:#{password}@#{ENV['DATABASE_URL'].host}/#{dbname}"

    STDOUT.puts "database url: #{db_url}"

    {id: dbname, config: {"MYADDON_URL" => db_url}}.to_json
  end

  # deprovision
  delete '/heroku/resources/:id' do
    show_request
    protected!
    begin
      DB << "DROP DATABASE #{params[:id]}"
      DB[:resources].filter(:id => params[:id]).update(:status => "inactive")
      "ok"
    rescue Sequel::DatabaseError
      halt 404
    end
  end

  # plan change
  put '/heroku/resources/:id' do
    show_request
    protected!
    DB[:resources].filter(:id => params[:id]).update(:plan => json_body['plan'])
    "ok"
  end
end
