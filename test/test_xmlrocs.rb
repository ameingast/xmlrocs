require "test/test_helper"
require "rexml/document"
require "rexml/xpath"
require "enumerator"

class Symbol
  include Comparable
  
  def to_proc
    Proc.new { |*args| args.shift.__send__(self, *args) }
  end
  
  def <=>(other)
    self.to_s <=> other.to_s
  end
end

class TestXMLROCS < Test::Unit::TestCase
  FIXTURE_PATH = "test/fixtures"
  include XMLROCS
  
  def setup
    @xmlfiles = Dir.open(FIXTURE_PATH).select { |e| e =~ /\.xml/ }.map { |e| e.sub(".xml", "") }
    generate_instance_variables(@xmlfiles)
  end
  
  def generate_instance_variables(xmlfiles)
    xmlfiles.each do |xmlfile|
      instance_variable_set("@#{xmlfile}", XMLNode.new(:text => load_fixture(xmlfile)))
    end
  end

  def load_fixture(name)
    File.new("#{FIXTURE_PATH}/#{name}.xml", "r").read
  end
  
  def with_xmlobjs
    @xmlfiles.map do |name|
      text = load_fixture(name)
      yield(XMLNode.new(:text => text), text)
    end
  end
  
  def with_xmlobjs_traverse
    with_xmlobjs do |xmlobj,text|
      xmlobj.each do |x|
        yield(x,xmlobj,text)
      end
    end
  end
  
  def with_xmlobjs_cons(cons = 1)
    @xmlfiles.map { |filename| XMLNode.new(:text => load_fixture(filename)) }.each_cons(cons) { |objects| yield(objects) }
  end

  def test_invalid_xmls
    assert_raise(ArgumentError) { XMLNode.new(:text => "") }
    assert_raise(ArgumentError) { XMLNode.new(:text => "sdfjgkjhfgskdljfhg") }
  end

  def test_new_with_text
    with_xmlobjs { |xmlobj,text| assert_equal(xmlobj, XMLNode.new(:text => text)) }
  end
  
  def test_comparable
   with_xmlobjs { |xmlobj,text| assert_equal(xmlobj, xmlobj) }
   with_xmlobjs_cons(2) { |(e,g)| assert_not_equal(e, g) }
  end
  
  def test_attributes_and_children_present
    with_xmlobjs do |xmlobj,text| 
      xmlobj.each do |x|
        assert_respond_to(x, :attributes)
        assert_respond_to(x, :children)
      end
    end
  end
  
  def test_parent_relationship
    with_xmlobjs do |xmlobj,text|
      assert_nil(xmlobj.parent)
      assert_test_parent_relationship(xmlobj)
    end
  end
  
  def assert_test_parent_relationship(parent)
    parent.children.each do |name, obj|
      obj.each do |sibling| 
        assert_equal(parent, sibling.parent)
        assert_test_parent_relationship(sibling)
      end
    end
  end
  
  def test_transform_to_xml_text
    with_xmlobjs_traverse do |node,xmlobj,text|
      assert_equal(node, XMLNode.new(:text => node.to_xml), "'#{node.to_s}' != '#{XMLNode.new(:text => node.to_xml).to_s}'")
    end
  end
  
  def test_add_attribute
    with_xmlobjs_traverse do |node,xmlobj,text|
      next if node[:attribute_symbol]
      assert_nil(node[:attribute_symbol])
      node[:attribute_symbol] = "foo"
      assert_equal("foo", node[:attribute_symbol])
    end
  end
  
  def test_delete_attribute
    with_xmlobjs_traverse do |node,xmlobj,text|
      next unless (a = node.attributes.keys.first)
      assert_not_nil(node[a])
      node.delete_attribute!(a)
      assert_nil(node[a])
    end
  end
  
  def test_add_child
    with_xmlobjs_traverse do |node,xmlobj,text|
      node << @friends
      assert_equal(@friends, node.friends)
      assert_not_nil(node.children[:friends])
    end
  end
  
  def test_child_from_plaintext
    xml = '<a>foo</a>'
    with_xmlobjs_traverse do |node,xmlobj,text|
      node << xml
      assert_equal(XMLROCS::XMLNode.new(:text => xml), node.a)
    end
  end
  
  def test_remove_child
    with_xmlobjs_traverse do |node,xmlobj,text|
      node << @friends
      node >> :friends
      assert(!node.respond_to?(:friends))
      assert_nil(node.children[:friends])
    end
  end
  
  def test_remove_child_with_closure
    o = XMLROCS::XMLNode.new :text => '<a><b id="1"></b><b id="2"></b><b id="3"></b></a>'
    o.>>(:b) { |child| child[:id] == "1" }
    assert(o.b.all? { |x| x[:id] != "1" })
    o.>> { |child| child[:id] == "3" }
    assert(o.b.all? { |x| x[:id] != "3" })
  end
  
  def test_xmlnames_present
    with_xmlobjs_traverse { |node,xmlobj,text| assert_not_nil(node.xmlname) }
  end
  
  def test_leafs
    leaf_names = [ :reach, :url, :releasedate, :small, :medium, :large, :mbid ]
    found = {}
    @album.leafs.map { |leaf| leaf.xmlname }.each do |name| 
      assert(leaf_names.include?(name))
      found[name] = 1
    end
    leaf_names.each { |name| assert(found.has_key?(name), name) }
  end
  
  def test_all
    with_xmlobjs do |xmlobj,text|
      all_node_names = xmlobj.all.map(&:xmlname)
      got = assert_children_names_in(xmlobj, all_node_names)
      assert_equal(all_node_names.uniq.sort, got.uniq.sort)
    end
  end
  
  def assert_children_names_in(xmlobj, names)
    xmlobj.children.inject([xmlobj.xmlname]) do |got,(name,value)|
      assert(names.include?(name))
      got += [ name ] + value.map { |child| assert_children_names_in(child, names) }.flatten
    end
  end
  
  def test_dup
    with_xmlobjs { |xmlobj,text| xmlobj.each { |x| assert_equal(x, x.dup) } }
  end

  def test_set_text
    with_xmlobjs_traverse do |node,xmlobj,text|
       node.set_text("foo")
       assert_equal("foo", node)
    end
  end
  
  def test_mappers
    with_xmlobjs do |xmlobj,text|
      xmlobj.map { |x| x.set_text("arbitrary_string_123"); x }.each do |node|
        assert_equal("arbitrary_string_123", node)
      end
      xmlobj.each { |node| assert_not_equal("arbitrary_string_123", node) }
      xmlobj.map! { |x| x.set_text("bar"); x }
      xmlobj.each { |node| assert_equal("bar", node) }
    end
  end
  
  def test_injecters
    with_xmlobjs do |xmlobj,text|
      xmlobj.each { |x| assert_equal(x.all.length, x.inject(0) { |cur,x| cur + 1 }) }
      xmlobj.each { |x| assert_equal(x.all.map(&:xmlname).uniq.sort, 
        x.inject([]) { |cur,x| cur << x.xmlname }.uniq.sort) }
    end  
  end
  
  def test_string_comparison
    with_xmlobjs do |xmlobj,text|
      assert(xmlobj.inject(true) { |cur,x| cur && x == x.to_s && x.to_s == x })
    end
  end
  
  def test_nil_node
    assert_nothing_thrown { node = XMLROCS::XMLNode.new(:nil => true) }
  end
  
  def test_marshal
    with_xmlobjs do |xmlobj,text|
      data = xmlobj.dump
      node = XMLROCS::XMLNode.load(data)
      assert_equal(xmlobj,node)
    end
  end
  
  def test_single_album
    [ :reach, :releasedate, :mbid, :tracks ].each { |e| assert(@album.single?(e)) }
    [ :small, :medium, :large ].each { |e| assert(@album.coverart.single?(e)) }
    assert(!@album.tracks.single?(:track))
    
    assert_equal("Metallica", @album[:artist])
    assert_equal("Metallica", @album[:title])
    assert_equal("195627", @album.reach)
    assert_equal("29 Aug 1991, 00:00", @album.releasedate)
    assert_equal("http://cdn.last.fm/coverart/130x130/1411800.jpg", @album.coverart.small)
    assert_equal("http://cdn.last.fm/coverart/130x130/1411800.jpg", @album.coverart.medium)
    assert_equal("http://cdn.last.fm/coverart/130x130/1411800.jpg", @album.coverart.large)
    assert_equal("3750d9e2-59f5-471d-8916-463433069bd1", @album.mbid)
    assert_equal("Enter Sandman", @album.tracks.track!.first[:title])
    assert_equal("217037", @album.tracks.track!.first.reach)
    assert_equal("http://www.last.fm/music/Metallica/_/Enter+Sandman", @album.tracks.track!.first.url)
    assert_equal("The Unforgiven", @album.tracks.track![3][:title])
    assert_equal("148058", @album.tracks.track![3].reach)
    assert_equal("http://www.last.fm/music/Metallica/_/The+Unforgiven", @album.tracks.track![3].url)
  end
  
  def test_artists
    assert(!@weeklyartists.single?(:artist))
    assert_equal([:user, :from, :to].sort, @weeklyartists.attributes.keys.sort)
    assert_equal([:artist], @weeklyartists.children.keys)
    
    assert_equal("RJ", @weeklyartists[:user])
    assert_equal("1114965332", @weeklyartists[:from])
    assert_equal("1115570132", @weeklyartists[:to])

    @weeklyartists.artist!.each do |e|
      assert_not_nil(e.name)
      assert_not_nil(e.chartposition)
      assert_not_nil(e.playcount)
      assert_not_nil(e.url)
    end
  end

  def test_albums_tracks
    assert_equal("1114965332", @weeklytracks[:from])
    assert_equal("1114965332", @weeklyalbums[:from])
    assert_equal("1115570132", @weeklytracks[:to])
    assert_equal("1115570132", @weeklyalbums[:to])
    assert_equal("RJ", @weeklytracks[:user])
    assert_equal("RJ", @weeklyalbums[:user])
    (@weeklytracks.track! + @weeklyalbums.album!).each do |e|
      [ :artist, :name, :chartposition, :playcount, :url ].each { |s| assert(e.single?(s)) }
      assert_not_nil(e.artist)
      assert_not_nil(e.name)
      assert_not_nil(e.chartposition)
      assert_not_nil(e.playcount)
      assert_not_nil(e.url)
    end    
  end
  
  def test_chart
    assert_equal("RJ", @weeklychartlist[:user])
    @weeklychartlist.chart!.each { |e| [ :from, :to ].each { |s| assert_not_nil(e[s]) } }
  end
  
  def test_name
    assert_equal(:weeklyartistchart, @weeklyartists.xmlname)
    assert_equal(:weeklytrackchart, @weeklytracks.xmlname)
    assert_equal(:weeklyalbumchart, @weeklyalbums.xmlname)
  end
  
  def test_against_rexml
    xmltext = TestHelper.build_xml(2)
    rexml = REXML::Document.new(xmltext)
    xmlroc = XMLROCS::XMLNode.new(:text => xmltext)

    rexml_cnt = REXML::XPath.match(rexml, "//[@id < 3]").length
    xmlrocs_cnt = xmlroc.select { |x| x[:id] && x[:id].to_i < 3 }.length
    assert_equal(rexml_cnt, xmlrocs_cnt)
    
    rexml_cnt = REXML::XPath.match(rexml, "//").length
    xmlrocs_cnt = xmlroc.all.length
    assert_equal(rexml_cnt - 1, xmlrocs_cnt)
  end
end