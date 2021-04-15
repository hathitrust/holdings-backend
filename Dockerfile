FROM ruby:2.6
ARG UNAME=holdings
ARG UID=1000
ARG GID=1191

RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
  nodejs

RUN gem install bundler
RUN groupadd -g $GID -o $UNAME
RUN useradd -m -d /usr/src/app -u $UID -g $GID -o -s /bin/bash $UNAME
RUN mkdir -p /gems && chown $UID:$GID /gems
USER $UNAME

COPY --chown=$UID:$GID Gemfile* /usr/src/app/
WORKDIR /usr/src/app
ENV BUNDLE_PATH /gems
RUN bundle install
COPY --chown=$UID:$GID . /usr/src/app
