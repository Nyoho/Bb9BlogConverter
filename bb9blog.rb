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

    doc.elements.each('COURSE/TITLE') do |u|
      @cource_title = u.attribute('value').value
    end
    
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
  'Copyright &copy; 2016 Someone. All rights reserved. Powered by <a href="https://github.com/Nyoho/Bb9BlogConverter">Bb9BlogConverter</a>.'
end

def sidemenu_html
  '<h2>Sidemenu</h2><ul>' + blog_list_html + '</ul>'
end
                                           
def blog_list_html
  @blogs.map.with_index do |blog,i|
    %Q|<li><a href="blog#{i}.html">#{blog.title}</a></li>|
  end.join "\n"
end

def index_title
  @cource_title
end

def page_title
  @page_title + ' - ' + @cource_title
end

def body_html
  @html_body
end

require 'pandoc-ruby'
@blogs.each_with_index do |blog,i|
  File.open("#{output_dir}/blog#{i}.md", 'w') do |f|
    f.puts "# #{blog.title}"
    blog.entries.each do |entry|
      f.puts "## #{entry.title}"
      f.puts "\n- #{entry.creator.name} (#{entry.creator.batchuid})"
      f.puts "- #{entry.create_date.localtime}\n"
      f.puts "\n#{entry.text}\n\n"
    end
    system("pandoc \"#{output_dir}/blog#{i}.md\" -o \"#{output_dir}/#{blog.title.gsub(/\//,'_')}.docx\"")
    # File.open("#{output_dir}/#{blog.title.gsub(/\//,'_')}.docx", 'w') do |doc|
    #   converter = PandocRuby.new(markdown.render(File.read(f.path)), :from => :markdown, :to => :docx)
    #   doc.puts converter.convert
    # end
  end
  File.open("#{output_dir}/blog#{i}.md", 'r') do |f|
    File.open("#{output_dir}/blog#{i}.html", 'w') do |html|
      @html_body = markdown.render(f.read)
      @page_title = blog.title
      html_string = page_erb.result(binding())
      html.puts html_string
    end
  end
end

# Dir.glob("#{output_dir}/*.md") do |filename|
# end

File.open("#{output_dir}/index.html", 'w') do |f|
  f.puts index_erb.result(binding())
end

FileUtils.copy 'templates/style.css', "#{output_dir}/"
