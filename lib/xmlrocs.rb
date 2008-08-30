#
# Copyright (c) 2008, Andreas Meingast, <ameingast@gmail.com>, http://yomi.at
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice, 
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright 
#       notice, this list of conditions and the following disclaimer in the 
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the person nor the names of its 
#       contributors may be used to endorse or promote products derived 
#       from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

require 'rubygems'
require 'ruby-debug'
require 'java'

include_class 'com.ximpleware.VTDGen'
include_class 'com.ximpleware.VTDNav'
include_class 'com.ximpleware.BookMark'

#
# For more information, have a look at the README or the XMLNode class 
# documentation.
#
module XMLROCS
  
  include_package 'com.ximpleware'
  
  #
  # Represents an XML Element. You can access and modify it's children
  # and attributes.
  #
  # Each XMLNode has exactly one parent (that happens to be nil if the node
  # is the root of the tree) and a (possibly empty) list of children.
  #
  # It also has a name (the name of the XML tag) that can be modified.
  #
  # You can compare two XMLNodes or an XMLNode and a String. When you provide
  # a String, only the text value of the XMLNode is compared.
  #
  # You can enumerate the XMLNode Tree in the traversal-order defined
  # in the @traversal accessor.
  #
  # For more information have a look at the README or instance method 
  # documentation.
  #
  class XMLNode < String
    include Comparable
    include Enumerable

    #
    # Hash containing the children of the current Node. The Hash has the
    # following
    # structure:
    #
    #   { :childname => [ XMLNode, ... ] }
    #
    # You can either use the >> or << operators to modify children or use 
    # this accessor directly. 
    attr_reader :children
    
    #
    # Hash containing the attributes of the current Node:
    #
    #   { :attribute_name => "Attribute" }
    #
    # Attributes can also be modified using this accessor.
    attr_reader :attributes
    
    # 
    # The parent of the current Node. The parent of the Root-Node is nil.
    #
    attr_reader :parent
    
    #
    # The name of the current Node. 
    #
    # Example:
    #   x = XMLNode.new :text => '<a></a>'
    #   x.xmlname # => :a
    #
    attr_reader :xmlname
    
    #
    # Defines the order in which the tree is traversed.
    #
    # The following traversals are suppported:
    #   :preorder
    #   :postorder
    #   :inorder
    #
    attr_accessor :traversal
    
    #
    # Create an XMLNode from binary marshalled data
    #
    def self.load(data)
      Marshal.load(data)
    end
    
    #
    # Create a new XMLNode
    # You have to either provide an REXML::Element as options[:root] or
    # plaintext xml data as options[:text]. Otherwise an ArgumentError will
    # be thrown.
    #
    # Supported options:
    #   :traversal  # => The traversal order. See traversal.
    #
    def initialize(options = {})
      @children, @attributes = {}, {}
      @parent, @traversal = options[:parent], options[:traversal] || :preorder
      
      vg = VTDGen.new
      
      if options[:nil]
        @xmlname = :NIL
        return
      elsif options[:text]
        vg.set_doc(java.lang.String.new(options[:text]).get_bytes)
        begin
          vg.parse(true)
        rescue NativeException => e
          raise(ArgumentError, e.to_s)
        end
        vn = vg.get_nav
        vn.to_element(VTDNav::R)
      elsif options[:file]
        vg.parse_file(options[:file], true)
        vn = vg.get_nav
        vn.to_element(VTDNav::R)
      elsif options[:root]
        vn = options[:root]
      end
      
      @xmlname = vn.to_string(vn.get_current_index).to_sym
          
      t = vn.get_text
      set_text(vn.to_normalized_string(t)) unless -1 == t
          
      i = vn.get_current_index
      j = 0
      
      while j < vn.get_attr_count
        key = vn.to_string(i + 2*j + 1).to_sym
        val = vn.to_string(i + 2*j + 2)
        @attributes.merge!({ key => val })
        j += 1
      end

      vn.push
      self << XMLNode.new({ :root => vn, :parent => self }) if vn.to_element(VTDNav::FC)
      vn.pop
      
      while vn.to_element(VTDNav::NS)
        @parent << XMLNode.new({ :root => vn, :parent => @parent }) if @parent
      end  
    end
    
    # 
    # Access attributes by name. Attributenames are stored as symbols.
    #
    def [](attribute)
      @attributes[attribute]
    end

    #
    # Modify attributes. Behaves like a Hash. Keys are symbols by convention, 
    # values are XMLNode-objects.
    #
    def []=(attribute, value)
      @attributes[attribute] = value
    end
    
    #
    # Delete attributes. attribute has to be a symbol with the name of the
    # attribute you want to delete.
    #
    def delete_attribute!(attribute)
      @attributes.delete(attribute)
    end

    #
    # Append a child. child has to be an XMLNode or a String that contains
    # the XML data in plaintext.
    #
    def <<(child)
      return self << XMLROCS::XMLNode.new(:text => child) if is_real_string(child)
      (@children[child.xmlname] = (@children[child.xmlname] || []) << child).last
    end

    # 
    # Remove a child from the current XMLNode.
    # Providing only a childname, it will delete all children with the given
    # name.
    # If you also provide a block, the block will be evaluated with each child
    # as an argument and according to the return value of the call the child
    # will be deleted or not (when the block returns true, the child will be
    # deleted).
    # If you provide a block you can optionally filter the children by
    # providing a childname so only children with the given name will be
    # evaluated.
    #
    def >>(childname = nil)
      if block_given?
        @children.select { |k,v| childname ? k == childname : true }.each do |k,v| 
          v.reject! { |child| yield(child) }
        end
      else
        @children.delete(childname)
      end
    end
    
    # 
    # Returns an array of all XMLNodes in the order that is specified in the
    # traversal accessor.
    #
    def all(name = nil)
      name ? select { |x| x.xmlname == name } : traverse
    end
    
    # 
    # Maps a function over the XMLNode-tree and returns a new XMLNode-tree
    # with the mapped values.
    #
    def map(&block)
      dup.map!(&block)
    end
    
    # 
    # Maps a function over the current XMLNode-tree.
    #
    def map!(&block)  
      traverse.map!(&block)
      self
    end
     
    #
    # Iterates over the XMLNode-tree in the order that is specified in the
    # traversal accessor.
    #   
    def each(&block)
      traverse.each(&block)
    end
    
    def flatten
      traverse.flatten
    end
    
    def last
      traverse.last
    end
    
    def first
      traverse.first
    end
    
    # 
    # Deep-copies the Tree.
    #
    def dup
      XMLROCS::XMLNode.new(:text => to_xml)
    end

    #
    # If a tag is provided it checks if the child with the given name has 
    # siblings.
    # Otherwise it does the same for the current node.
    #
    def single?(tag = nil)
      if tag && @children[tag]
        @children[tag].length == 1 
      elsif @parent.children[@xmlname]
        @parent.children[@xmlname].length == 1
      else
        false
      end
    end

    # 
    # If a tag is provided it checks if the child with the given name is a leaf.
    # Otherwise it does the same for the current node.
    #
    def leaf?(tag = nil)
      tag ? children[tag].all? { |x| x.leaf? } : children.empty?
    end

    # 
    # Generates an array of all leafs in the order specified in the traversal 
    # accessor.
    #
    def leafs
      traverse.select { |x| x.leaf? }
    end

    # 
    # Sets the text of the current node to text.
    #
    def set_text(text)
      # special match for whitespace-only
      return gsub!(self.to_s, "") if text =~ /^\s+$/
      gsub!(self.to_s, text)
    end

    #
    # Deep-compares to XMLNodes.
    # 
    def ==(other)
      # pure string comparison
      return super(other) if is_real_string(other)
      return false unless other == self.to_s
      [ [ self, other ], [ other, self ] ].each do |a,b|
        a.children.each do |k,v| 
          if !b.children.has_key?(k) or v != b.children[k]
            p "#{v} != #{b.children[k]}, #{k}"
            return false
          end
        end
      end
      true
    end

    # 
    # Deep-transforms the current node into plaintext XML. If flat is true,
    # all children will be omitted.
    #
    def to_xml(flat = false)
      "<#{@xmlname} " + @attributes.map { |k,v| "#{k}=\"#{v}\" "}.join(" ") + ">" + 
        (flat ? "" : (self.to_s + @children.values.flatten.map { |e| e.to_xml }.join)) + 
      "</#{@xmlname}>"
    end
    
    #
    # Dumps the Node and all its subnodes into a marshalled binary
    #
    def dump
      Marshal.dump(self)
    end
    
    def method_missing(method, *args)
      if method.to_s[-1] == 33 and @children.has_key?(real_method = method.to_s.chomp("!").to_sym)
        return @children[real_method] 
      end
      return @children[method].last if @children.has_key?(method)
      super(method, *args)
    end

    private
    
    def preorder
      children.values.flatten.inject([self]) { |cur,child| cur + child.send(:preorder) }
    end
    
    def inorder
      preorder # FIXME
    end
    
    def postorder
      preorder # FIXME
    end
    
    def traverse
      self.send(@traversal)
    end
    
    #
    # helper method
    #
    def is_real_string(what)
      what.is_a?(String) and !what.is_a?(XMLNode)
    end
  end
end

