#FROM arm64v8/ruby:2.5.5-alpine
FROM ruby:2.5.5-alpine
LABEL maintainer="jan.klare@bisdn.de"

ENV RAILS_ENV production
ENV RAILS_LOG_TO_STDOUT true
ENV RAILS_SERVE_STATIC_FILES true
ENV SALT_MINION_KEY_PATH /salt/minion.pub
ENV REDIS_CHAN swan.events
ENV REDIS_HOST redis
ENV REDIS_PORT 6379


COPY ./ /swan
WORKDIR /swan

RUN apk add --no-cache build-base yarn imagemagick nodejs-current tzdata git sqlite sqlite-dev sqlite-libs
RUN gem install bundler -v 2.0.2
RUN bundle install -j 4 --retry 3 --deployment --without development test
RUN env SECRET_KEY_BASE=precompilekey bundle exec rake --trace assets:precompile
RUN rm -rf node_modules tmp/cache app/assets vendor/assets lib/assets spec
RUN apk del build-base git sqlite-dev
RUN rm -rf /usr/local/bundle/cache/*.gem \
 && find /usr/local/bundle/gems/ -name "*.c" -delete \
 && find /usr/local/bundle/gems/ -name "*.o" -delete

ENTRYPOINT ["./entrypoint.sh"]
CMD ["./entrypoint.sh"]
