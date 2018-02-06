# shell script (or ruby script) to transfer the rows from XML search index to sqlite

require 'rubygems'
require 'xmlsimple'
require 'ftools'

# Constants
#SQL_FILE_NAME = "searchDB.sql"
BOOK_DIRECTORY_NAME = "book"

if ARGV.length == 0
  path = "."
  target = "."
elsif ARGV.length == 1
  path = ARGV[0]
  target = ARGV[0]
else 
  path = ARGV[0]
  target = ARGV[1]
end

last_char = path[path.length-1, path.length-1]
if last_char != "/"
  path=path+"/"
end

last_char = target[target.length-1, target.length-1]
if last_char!= "/"
  target=target+"/"
end

searches=Array.new
i=0;
Dir.foreach(path) do |file|
  name=file
  if name.gsub!(".xml","");  
    searches[i]=name
    i=i+1
  end
end

SQL_FILE_NAME = "#{target.downcase}searchDB.sql" 
File.copy('empty.sql', SQL_FILE_NAME)

# SEARCH CATEGORYS

create_table_query = "CREATE TABLE search_db_column_names (pk INTEGER PRIMARY KEY, display_name TEXT, column_name TEXT)"
  create_table_command = "sqlite3 #{SQL_FILE_NAME} \"#{create_table_query}\""
  system create_table_command  
searches.each do |search_category|
  column_name = "book#{search_category}"
  sql_query = "INSERT INTO search_db_column_names (display_name, column_name) values ('#{search_category}', '#{column_name}')"
  sql_command = "sqlite3 #{SQL_FILE_NAME} \"#{sql_query}\""
  system sql_command
end

# SEARCH ENTRYS

searches.each do|search|
  filename = "#{path.downcase}#{search.downcase}.xml"
  table = "book#{search}"

  create_table_query = "CREATE TABLE #{table} (pk INTEGER PRIMARY KEY, searchTerms TEXT, title TEXT, url TEXT, description TEXT)"
  create_table_command = "sqlite3 #{SQL_FILE_NAME} \"#{create_table_query}\""
  system create_table_command

  create_index_query = "CREATE INDEX #{table}Index ON #{table}(searchTerms ASC)"
  create_index_command = "sqlite3 #{SQL_FILE_NAME} \"#{create_index_query}\""
  system create_index_command

  # open the xml file with the ruby parser
  xmldoc = XmlSimple.xml_in(filename)

  # scan the xml file with grep and regex to find the 'ref="#{content1}"' and '>#{content2}</item>'
  # store each in ivars
  xmldoc['item'].each do |ab|
#	search_terms = "#{ab['description']}"
#	## Since the "index.xml" doesn't have a "descriptions" tag, we should just add the innerHTML content
#	if (search_terms.length < 2)
#  	  search_terms = "#{ab['content']}"
#        end
	
	title = ab['content'] # don't truncate search string
  description = ab['description']	
	url = ab['ref']
	if description==nil
	  search_terms=title
	elsif title==nil
	  search_terms=title
	else
    search_terms=title+" "+description
	end
	  
	url = url.gsub(/\.\.\//, "")  # reparse link to say "books/BOOK_DIRECTORY_NAME/html/etc" from "../html/etc"
	
	# Remove ' chars, since interferes with SQL query; use bindings?
	if (description)
	  description.gsub!("'", "")
  	end
  if (title)
    title.gsub!("'", "")
    end 	
	if (search_terms)    
	  search_terms.gsub!("'", "")
    search_terms.gsub!(" the ", " ")
    search_terms.gsub!(" and ", " ")
    search_terms.gsub!(" a ", " ")
    search_terms.gsub!(" an ", " ")
    search_terms.gsub!(" or ", " ")
    search_terms.gsub!(" like ", " ")
    search_terms.gsub!(" of ", " ")
    search_terms.gsub!(" in ", " ")
    search_terms.gsub!(" is ", " ")
    #search_terms.gsub!(/[^a-zA-Z ]+/, '')    
    if (search_terms.length > 256)
      search_terms= search_terms[0..256]
    end    
  	end
	if (url)
	  url.gsub!("'", "")
  	end
        sql_query = "INSERT INTO #{table} (description, searchTerms, title, url) values ('#{description}', '#{search_terms}', '#{title}', '#{url}')"
        sql_command = "sqlite3 #{SQL_FILE_NAME} \"#{sql_query}\""
        #puts sql_query
  	system sql_command
  end
end




