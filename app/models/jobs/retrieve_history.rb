#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.


module Job
  class RetrieveHistory < Base

    @queue = :socket_webfinger

    def self.perform_delegate(requesting_user_id, person_id)
      user = User.find(requesting_user_id)
      person = Person.find(person_id)
      contact = user.contact_for(person)

      api_route = "#{person.url}api/v0/statuses/user_timeline"
      request_hash ={ :params => {:screen_name => person.diaspora_handle,
                                              :format => :xml}}
      if contact 
        
        if contact.access_token.nil? || contact.access_token.expired?
          contact.receive_tokens
        end
        request_hash[:params][:oauth_token] = contact.access_token.token

        RestClient.get(api_route, request_hash) do |body, req, res|
          [*Diaspora::Parser.from_xml(body)].map do |obj|
            obj.receive(user, person)
            obj.socket_to_user(user)
          end
        end

        contact.fetched_at = Time.now
        contact.save
      else

        RestClient.get(api_route, request_hash) do |body, req, res|
          [*Diaspora::Parser.from_xml(body)].map do |obj|
            obj.receive(user, person)
            obj.socket_to_user(user)
          end
        end
      end

    end
  end
end

