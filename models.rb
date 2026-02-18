require 'bundler/setup'
Bundler.require

ActiveRecord::Base.establish_connection

class User < ActiveRecord::Base
  has_secure_password
  validates :mail, presence: true, uniqueness: true
  validates :name, presence: true
end
