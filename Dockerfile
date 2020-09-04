FROM ruby:2.6

RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
  nodejs netcat

WORKDIR /usr/src/app
ENV BUNDLE_PATH /gems
RUN gem install bundler
