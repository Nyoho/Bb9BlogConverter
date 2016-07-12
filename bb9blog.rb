#!/usr/bin/env ruby

require 'rexml/document'
require 'time'
require 'set'

if ARGV[0].nil? then
  puts "1st argument is a directory."
  exit
end

data_dir = ARGV[0]

class User
  attr_accessor :name, :id, :user_id, :username, :batchuid, :email
end

class Blog
  attr_accessor :title, :entries, :date
end

class Entry
  attr_accessor :text, :title, :creator, :create_date, :update_date
end

users = Set.new
usershash = {}
@blogs = []

Dir.glob(data_dir + '/*.dat') do |filename|
  puts "Loading #{filename} ..."
  begin
    doc = REXML::Document.new(open(filename))

    doc.elements.each('COURSEMEMBERSHIPS/COURSEMEMBERSHIP') do |u|
      id = u.elements['USERID'].attribute('value').value
      user = users.find { |a| a.id == id } || User.new
      user.id = id
      user.user_id = u.attribute('id').value
      users |= [user]
      usershash[user.user_id] = user
    end

    doc.elements.each('USERS/USER') do |u|
      id = u.attribute('id').value
      user = users.find { |a| a.id == id } || User.new
      user.id = id
      user.name = u.elements['NAMES/FAMILY'].attribute('value').value  + ' ' + u.elements['NAMES/GIVEN'].attribute('value').value
      user.username = u.elements['USERNAME'].attribute('value').value
      user.batchuid = u.elements['BATCHUID'].attribute('value').value
      user.email = u.elements['EMAILADDRESS'].attribute('value').value
      users |= [user]
    end

    doc.elements.each('BLOG') do |b|
      entries = []
      blog = Blog.new
      blog.title = b.elements['TITLE'].attribute('value').value
      blog.date = Time.parse(b.elements['DATES/UPDATEDATE'].attribute('value').value)
      b.elements.each('ENTRIES/ENTRY') do |e|
        entry = Entry.new
        entry.text = e.elements['DESCRIPTION/TEXT']&.text
        entry.title = e.elements['TITLE']&.attribute('value')&.value
        entry.creator = usershash[e.elements['CREATOR_ID']&.attribute('value')&.value]
        entry.create_date = Time.parse(e.elements['CREATION_DATE']&.attribute('value')&.value)
        entry.update_date = Time.parse(e.elements['LAST_EDIT_DATE']&.attribute('value')&.value)
        entries << entry
      end
      blog.entries = entries
      @blogs << blog
    end

  rescue => e
  end
end

exit if ARGV[1].nil?
output_dir = ARGV[1]

require 'fileutils'
require 'redcarpet'
require 'erb'

@blogs.sort! {|a, b| a.date <=> b.date }

markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
FileUtils.mkdir_p(output_dir) unless FileTest.directory?(output_dir)

index_erb = ERB.new(File.read('templates/index.html.erb'))
page_erb = ERB.new(File.read('templates/page.html.erb'))

def copyright_html
  'Copyright &copy; 2016 Someone. All rights reserved.'
end

def sidemenu_html
  <<-EOS
  <h2>Side</h2>
  <p>This is a side.</p>
  <p>This is a side.</p>
  EOS
end
                                           
def blog_list_html
  @blogs.map.with_index do |blog,i|
    %Q|<li><a href="blog#{i}.html">#{blog.title}</a></li>|
  end.join "\n"
end

@blogs.each_with_index do |blog,i|
  File.open("#{output_dir}/blog#{i}.md", 'w') do |f|
    f.puts "# #{blog.title}"
    blog.entries.each do |entry|
      f.puts "## #{entry.title}"
      f.puts "\n- #{entry.creator.name} (#{entry.creator.batchuid})"
      f.puts "- #{entry.create_date}\n"
      f.puts "\n#{entry.text}\n\n"
    end
  end
  File.open("#{output_dir}/blog#{i}.md", 'r') do |f|
    markdown.render(f.read)
  end
end

File.open("#{output_dir}/index.html", 'w') do |f|
  f.puts index_erb.result(binding())
end
