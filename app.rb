require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require './models.rb'
require 'securerandom'
require 'mail'
require 'dotenv/load'

enable :sessions

configure do
  smtp_options = {
    address: ENV.fetch('SMTP_ADDRESS', 'localhost'),
    port: (ENV['SMTP_PORT'] || '587').to_i,
    domain: ENV.fetch('SMTP_DOMAIN', 'localhost')
  }

  if ENV['SMTP_USERNAME'] && ENV['SMTP_PASSWORD']
    smtp_options[:user_name] = ENV['SMTP_USERNAME']
    smtp_options[:password] = ENV['SMTP_PASSWORD']
    smtp_options[:authentication] = (ENV['SMTP_AUTH'] || 'plain').to_sym
    smtp_options[:enable_starttls_auto] = (ENV['SMTP_ENABLE_STARTTLS'] || 'true') == 'true'
  end

  Mail.defaults do
    delivery_method :smtp, smtp_options
  end
end

helpers do
  def logged_in?
    !!current_user
  end
  
  def current_user
    return nil unless session[:user_id]
    User.find_by(id: session[:user_id])
  end

  def base_url
    ENV['APP_BASE_URL'] || request.base_url
  end

  def send_mail(to, subject, body)
    Mail.deliver do
      from ENV.fetch('MAIL_FROM', 'no-reply@example.com')
      to to
      subject subject
      body body
    end
  end

  def issue_verification(user)
    token = SecureRandom.hex(20)
    user.update(
      email_verified: false,
      verification_token: token,
      verification_token_expires_at: Time.now + 60 * 60,
      verification_sent_at: Time.now
    )
    verify_url = "#{base_url}/verify?token=#{token}"
    send_mail(
      user.mail,
      'メールアドレス確認',
      "以下のリンクをクリックしてメールアドレスを確認してください。\n\n#{verify_url}\n\n有効期限は1時間です。"
    )
  end

  def issue_login_otp(user)
    code = rand(100000..999999).to_s
    user.update(
      login_otp_code: code,
      login_otp_expires_at: Time.now + 10 * 60,
      login_otp_sent_at: Time.now
    )
    send_mail(
      user.mail,
      'ログイン確認コード',
      "ログイン確認コードは以下です。\n\n#{code}\n\n有効期限は10分です。"
    )
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
    if user.email_verified
      issue_login_otp(user)
      session[:otp_user_id] = user.id
      redirect '/signin/otp'
    else
      issue_verification(user)
      erb :signin_unverified
    end
  else
    erb :signin
  end
end

get '/signup' do
  erb :signup
end

post '/signup' do
  user = User.new(name: params[:name], mail: params[:mail], password: params[:password])
  if user.save
    issue_verification(user)
    erb :signup_pending
  else
    erb :signup
  end
end

get '/verify' do
  token = params[:token]
  user = User.find_by(verification_token: token)
  if user && user.verification_token_expires_at && user.verification_token_expires_at > Time.now
    user.update(
      email_verified: true,
      verification_token: nil,
      verification_token_expires_at: nil,
      verification_sent_at: nil
    )
    erb :verify_success
  else
    erb :verify_failed
  end
end

get '/signin/otp' do
  redirect '/signin' unless session[:otp_user_id]
  erb :otp
end

post '/signin/otp' do
  user = User.find_by(id: session[:otp_user_id])
  if user &&
     user.login_otp_code == params[:otp] &&
     user.login_otp_expires_at &&
     user.login_otp_expires_at > Time.now
    session[:user_id] = user.id
    session.delete(:otp_user_id)
    user.update(login_otp_code: nil, login_otp_expires_at: nil, login_otp_sent_at: nil)
    redirect '/'
  else
    @error = 'コードが違うか期限切れです'
    erb :otp
  end
end

get '/signout' do
  session.clear
  redirect '/'
end
