require "benchmark"
require "rexml/document"
require "rexml/xpath"
require "test/test_helper"

Benchmark.bm do |bm|
  puts("Initial XML String creation:") 
  bm.report { @xmltext = TestHelper.build_xml(3) }

  puts("REXML new document:") 
  bm.report { @rexml = REXML::Document.new(@xmltext) }
  puts("XMLROC new document:")
  bm.report{ @xmlroc = XMLROCS::XMLNode.new(:text => @xmltext) }
  
  puts
  
  puts("REXML/XPath collect all nodes:")
  bm.report { REXML::XPath.match(@rexml, "//") }
  puts("XMLROC collect all nodes:") 
  bm.report { @xmlroc.all }
  
  puts
  
  puts("REXML/XPath collect leafs:") 
  bm.report { REXML::XPath.match(@rexml, "//*[not(*)]") {} }
  puts("XMLROC collect leafs:") 
  bm.report { @xmlroc.leafs }
  
  puts
  
  puts("REXML dup tree:") 
  bm.report { @rexml.dup }
  puts("XMLROC dup tree:")
  bm.report{ @xmlroc.dup }
  
  puts
  
  puts("REXML/XPath map over all nodes") 
  puts("see iterate")
  # bm.report { REXML::XPath.each(@rexml.dup, "//") { |el| el.text = "foo" } }
  puts("XMLROC map over all nodes:") 
  bm.report { @xmlroc.map { |x| x.set_text("foo"); x } }
  
  puts
  
  puts("REXML/XPath map! over all nodes:") 
  puts("see iterate")
  # bm.report { REXML::XPath.each(@rexml, "//") { |el| el.text = "foo" } }
  puts("XMLROC map! over all nodes:") 
  bm.report { @xmlroc.map! { |x| x.set_text("foo"); x } }
  
  puts
  
  puts("REXML/XPath iterate over all nodes:") 
  bm.report { REXML::XPath.each(@rexml, "//") { |el| el } }
  puts("XMLROC iterate over all nodes:") 
  bm.report { @xmlroc.each { |x| x } }
  
  puts
  
  puts("REXML/XPath select nodes with id < 3") 
  bm.report { REXML::XPath.match(@rexml, "//[@id < 3]") }
  puts("XMLROCS select nodes with id < 3") 
  bm.report { @xmlroc.select { |x| x[:id] && x[:id].to_i < 3 } }
  
  puts
  
  puts("REXML/XPath select with text 'foo'")
  bm.report { REXML::XPath.match(@rexml, "//[a='foo']")}
  puts("XMLROCS select with text = 'foo'")
  bm.report { @xmlroc.select { |x| x == "foo" } }
end
