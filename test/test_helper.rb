require "xmlrocs"
require "test/unit"

class TestHelper
  def self.build_xml(limit)
    return "" if limit <= 0
    xmltext = "<X>"
    ('a'..'z').to_a.each_with_index do |x,i| 
      xmltext += "<#{x} id=\"#{i}\">" + build_xml(limit - 1) + "</#{x}>"
    end
    xmltext += "</X>"
  end
end