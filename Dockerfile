FROM ruby:3.4 AS base

RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
  nodejs rclone uchardet sqlite3

WORKDIR /usr/src/app
ENV APP_HOME /usr/src/app
ENV BUNDLE_PATH /gems
ENV RUBYLIB /usr/src/app/lib
RUN gem install bundler

FROM base AS dev
RUN apt-get install -yqq --no-install-recommends less entr mariadb-client

FROM base AS prod
LABEL org.opencontainers.image.source https://github.com/hathitrust/holdings-backend

ARG UNAME=holdings
ARG UID=1000
ARG GID=1000

RUN groupadd -g $GID -o $UNAME
RUN useradd -m -d /usr/src/app -u $UID -g $GID -o -s /bin/bash $UNAME
RUN mkdir -p /gems && chown $UID:$GID /gems
USER $UNAME

COPY --chown=$UID:$GID Gemfile* /usr/src/app/
RUN bundle config set without "development test"
RUN bundle install
COPY --chown=$UID:$GID . /usr/src/app
