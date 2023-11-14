FROM ruby
WORKDIR /usr/src/app
COPY . .
RUN bundle install
CMD ["ruby", "./run_from_ev.rb"]