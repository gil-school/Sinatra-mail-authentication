require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require './models.rb'

enable :sessions

helpers do
  def logged_in?
    !!session[:user_id]
  end
  
  def current_user
    User.find(session[:user_id])
  end
end

get '/' do
  erb :index
end

get '/signin' do
  erb :signin
end

post '/signin' do
  user = User.find_by(mail: params[:mail])
  if user && user.authenticate(params[:password])
    session[:user_id] = user.id
    redirect '/'
  else
    erb :signin
  end
end

get '/signup' do
  erb :signup
end

post '/signup' do
  user = User.create(name: params[:name], mail: params[:mail], password: params[:password])
  if user.save
    session[:user_id] = user.id
    redirect '/'
  else
    erb :signup
  end
end

get '/signout' do
  session.clear
  redirect '/'
end
