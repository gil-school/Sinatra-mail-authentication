# Mail Authentication Setup

このREADMEは「メール認証機能（サインアップ確認＋ログイン時OTP）」のコミットで追加した内容だけを対象に、導入ステップとコードの意味をまとめています。

## 追加手順

1. 依存関係を追加

```
bundle install
```

2. 環境変数を設定

`.env` を使う場合は `app.rb` の先頭で `require 'dotenv/load'` を追加していることを確認してください。([app.rb:L1-L7](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/app.rb#L1-L7))

```
APP_BASE_URL=http://localhost:4567
MAIL_FROM=your_address@gmail.com

SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=gmail.com
SMTP_USERNAME=your_address@gmail.com
SMTP_PASSWORD=YOUR_APP_PASSWORD
SMTP_AUTH=plain
SMTP_ENABLE_STARTTLS=true
```

3. マイグレーション実行

```
bundle exec rake db:migrate
```

4. サーバ起動

```
bundle exec ruby app.rb
```

## 追加されたメール認証機能の概要

- サインアップ後に確認メールを送信し、リンク確認が終わるまではログインできません。
- ログイン時はメールで送られる6桁コード（OTP）を入力する必要があります。

## 変更点とコードの意味

### Gemfile

- `mail` を追加: SMTPでメール送信するためのライブラリ。([Gemfile:L1-L15](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/Gemfile#L1-L15))

### db/migrate/20260218100000_add_email_auth_to_users.rb

- `email_verified`: メール確認が完了しているかを判定するフラグ。([db/migrate/20260218100000_add_email_auth_to_users.rb:L1-L14](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/db/migrate/20260218100000_add_email_auth_to_users.rb#L1-L14))
- `verification_token` / `verification_token_expires_at` / `verification_sent_at`: 確認メール用リンクのトークンと期限、送信時刻。([db/migrate/20260218100000_add_email_auth_to_users.rb:L1-L14](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/db/migrate/20260218100000_add_email_auth_to_users.rb#L1-L14))
- `login_otp_code` / `login_otp_expires_at` / `login_otp_sent_at`: ログイン時に使う6桁OTPと期限、送信時刻。([db/migrate/20260218100000_add_email_auth_to_users.rb:L1-L14](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/db/migrate/20260218100000_add_email_auth_to_users.rb#L1-L14))
- インデックス: `verification_token` は一意。リンク検証で高速に検索するため。([db/migrate/20260218100000_add_email_auth_to_users.rb:L12-L13](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/db/migrate/20260218100000_add_email_auth_to_users.rb#L12-L13))

### models.rb

- `validates :mail, presence: true, uniqueness: true`: 同じメールの重複登録を禁止。([models.rb:L6-L9](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/models.rb#L6-L9))
- `validates :name, presence: true`: 名前未入力を禁止。([models.rb:L6-L9](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/models.rb#L6-L9))

### app.rb

#### SMTP設定

- `Mail.defaults`: `ENV` からSMTP設定を読み取り、メール送信の設定を行う。([app.rb:L11-L28](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/app.rb#L11-L28))
- `send_mail`: 実際にメールを送信する共通関数。([app.rb:L44-L51](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/app.rb#L44-L51))

#### サインアップ時の確認メール

- `issue_verification(user)`: ランダムなトークンを発行し、1時間の有効期限を設定。確認リンクをメール送信。([app.rb:L53-L67](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/app.rb#L53-L67))
- `post '/signup'`: ユーザー作成後に `issue_verification` を実行し、確認メール送信画面へ。([app.rb:L112-L120](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/app.rb#L112-L120))

#### 確認リンクの検証

- `get '/verify'`: トークンの有効性と期限をチェック。成功時は `email_verified=true` に更新。([app.rb:L122-L136](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/app.rb#L122-L136))

#### ログイン時OTP

- `issue_login_otp(user)`: 6桁のランダムコードを発行し、10分の有効期限を設定。OTPをメール送信。([app.rb:L69-L81](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/app.rb#L69-L81))
- `post '/signin'`: メール未確認なら再送して未確認画面へ。メール確認済みならOTPを送って `/signin/otp` へ遷移。([app.rb:L92-L106](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/app.rb#L92-L106))
- `get '/signin/otp'` / `post '/signin/otp'`: OTP入力画面表示と検証。正常ならログイン完了、OTP情報を消去。([app.rb:L138-L156](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/app.rb#L138-L156))

### views

- `views/signup_pending.erb`: 確認メールを送ったことを案内する画面。([views/signup_pending.erb:L1-L11](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/views/signup_pending.erb#L1-L11))
- `views/signin_unverified.erb`: メール未確認時に再送したことを伝える画面。([views/signin_unverified.erb:L1-L11](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/views/signin_unverified.erb#L1-L11))
- `views/verify_success.erb`: 確認リンクの成功画面。([views/verify_success.erb:L1-L11](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/views/verify_success.erb#L1-L11))
- `views/verify_failed.erb`: 確認リンクの失敗画面。([views/verify_failed.erb:L1-L11](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/views/verify_failed.erb#L1-L11))
- `views/otp.erb`: 6桁コード入力画面。([views/otp.erb:L1-L16](https://github.com/gil-school/Sinatra-mail-authentication/blob/main/views/otp.erb#L1-L16))
