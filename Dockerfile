FROM ruby:3.2

RUN apt-get update -y && apt-get install -y build-essential nodejs postgresql-client && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install || true

COPY . .
