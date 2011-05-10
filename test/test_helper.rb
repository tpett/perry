require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'factory_girl'
require 'leftright'
require 'fakeweb'

# Add test and lib paths to the $LOAD_PATH
[ File.join(File.dirname(__FILE__), '..'),
  File.join(File.dirname(__FILE__), '..', 'lib')
].each do |path|
  full_path = File.expand_path(path)
  $LOAD_PATH.unshift(full_path) unless $LOAD_PATH.include?(full_path)
end

require 'perry'

# TRP: Test models
require 'test/fixtures/test_adapter'
require 'test/fixtures/middleware_adapter'
require 'test/fixtures/models'

# Pull in factories
require 'test/factories'

def mock_http_response(name_without_ext)
  File.open(File.join('test/fixtures', "#{name_without_ext}.txt")) { |io| io.read }
end
