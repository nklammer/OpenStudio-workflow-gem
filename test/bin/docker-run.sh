#!/bin/bash

# Start MongoDB
/sbin/start-mongodb.sh

export CI=true
export CIRCLECI=true
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# install dependencies and run default rake task
cd /var/simdata/openstudio
bundle update 
bundle exec rake
