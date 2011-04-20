#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.


module Job
  class RetrieveHistory < Base

    @queue = :socket_webfinger

    def self.perform_delegate(requesting_user_id, person_id)
      user = User.find(requesting_user_id)
      person = Person.find(person_id)
      url = "#{person.url}api/v0/statuses/user_timeline?screen_name=#{person.diaspora_handle}"

      RestClient.get(url) do |body, req, res|
        [*Diaspora::Parser.from_xml(body)].map do |obj|
          obj.receive(user, person)
          obj.socket_to_user(user)
        end
      end
    end
  end
end

