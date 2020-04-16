json.extract! registration, :id, :name, :otp, :access_token, :swan_backend, :salt_master, :ike_daemon, :created_at, :updated_at
json.url registration_url(registration, format: :json)
