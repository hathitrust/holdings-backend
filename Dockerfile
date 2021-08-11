FROM ruby:2.6
ARG UNAME=holdings
ARG UID=1000
ARG GID=1000

RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
  nodejs

WORKDIR /usr/src/app
ENV BUNDLE_PATH /gems
RUN gem install bundler
