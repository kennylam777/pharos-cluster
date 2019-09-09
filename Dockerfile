FROM ruby:2.5

WORKDIR /app

COPY Gemfile *.gemspec ./
COPY lib/pharos/version.rb ./lib/pharos/
RUN bundle install

COPY . .

CMD ["./bin/pharos-cluster"]
