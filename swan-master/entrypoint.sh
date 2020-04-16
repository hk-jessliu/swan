#!/bin/sh
# Generate secret
SECRET=$(bundle exec rake secret)
cat << EOF > config/secrets.yml
production:
  secret_key_base: ${SECRET}
EOF

# Migrate database
bundle exec rake db:migrate RAILS_ENV=production

# Seed database
bundle exec rake db:seed RAILS_ENV=production

chmod 700 config db
chmod 600 config/database.yml config/secrets.yml

# remove pid file from previously running rails server (sometimes this is not
# cleaned up when rails server was not stopped properly)
rm -f /swan/tmp/pids/server.pid

# Start the server
bundle exec rails server
