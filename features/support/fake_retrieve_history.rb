module Job
  class RetrieveHistory < Base
    @queue = :socket_webfinger
    def self.perform_delegate(requesting_user_id, person_id)
      true
    end
  end
end
