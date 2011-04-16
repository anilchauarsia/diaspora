#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'rack/oauth2'
Rails.application.config.middleware.use Rack::OAuth2::Server::Resource::Bearer do |req|
  AccessToken.valid.find_by_token(req.access_token) || req.invalid_token!
end

Dir[File.join(Rails.root, 'lib', 'oauth', '*.rb')].each { |file| require file }
Dir[File.join(Rails.root, 'app', 'models', 'oauth', '*.rb')].each { |file| require file }

