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
          pp "Receiving Tokens for a contact from the job"
          contact.receive_tokens
        end
        request_hash[:params][:oauth_token] = contact.access_token.token

        pp "About to fetch posts for a contact from the job"
        get_data(api_route, request_hash, user, person) do
          contact.fetched_at = Time.now
          contact.save!
        end

      else
        pp "About to fetch posts for a person from the job"
        get_data(api_route, request_hash, user, person) do
          person.fetched_at = Time.now
          person.save!
        end
      end
    end

    def self.get_data(api_route, request_hash, user, person)
      RestClient.get(api_route, request_hash) do |body, req, res|
        return unless res.code.to_i >= 200 && res.code.to_i < 400
        [*Diaspora::Parser.from_xml(body)].map do |obj|
          obj.receive(user, person)
          obj.socket_to_user(user)
        end
        yield
      end
    end
  end
end

