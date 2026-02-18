class AddEmailAuthToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :email_verified, :boolean, default: false, null: false
    add_column :users, :verification_token, :string
    add_column :users, :verification_token_expires_at, :datetime
    add_column :users, :verification_sent_at, :datetime

    add_column :users, :login_otp_code, :string
    add_column :users, :login_otp_expires_at, :datetime
    add_column :users, :login_otp_sent_at, :datetime

    add_index :users, :verification_token, unique: true
    add_index :users, :login_otp_code
  end
end
