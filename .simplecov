SimpleCov.configure do
  add_filter '/.binstubs'
  add_filter '/.bundle/'
  add_filter '/.git/'
  add_filter '/spec/'
  add_filter '/test/'
end

# It's recommended that you delete the if statement based on the type
# of project you have.
if ENV["RAILS_ENV"]
  SimpleCov.start "rails"
else
  SimpleCov.start
end
