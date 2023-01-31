FROM ruby:3.1
ARG UNAME=holdings
ARG UID=1000
ARG GID=1000

RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
  nodejs netcat rclone less entr uchardet

WORKDIR /usr/src/app
ENV BUNDLE_PATH /gems
ENV RUBYLIB /usr/src/app/lib
RUN gem install bundler
