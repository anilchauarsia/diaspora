#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

module Diaspora
  module Parser
    def self.from_xml(xml)
      doc = Nokogiri::XML(xml) { |cfg| cfg.noblanks }
      #debugger
      doc.xpath('/XML/post').children.inject([]) do |result, object|
        begin
          result << object.name.camelize.constantize.from_xml(object.to_s)
        rescue NameError => e
          if e.message.include? 'wrong constant name'
            Rails.logger.info "Not a real type: #{object.to_s}"
          end
          raise e
        end
      end
    end
  end
end
