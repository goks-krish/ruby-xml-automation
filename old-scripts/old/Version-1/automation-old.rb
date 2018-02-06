require 'ftools'
require 'zip/zip'

#CONSTANTS
encrypt_key="ps17"

#validate inputs
unless ARGV.length == 3
  puts "Invalid Arguments"
  puts "Usage: ruby automation.rb <book_name> <book_path> <git_url>"
  exit
end

book_name=ARGV[0]
path = ARGV[1]
git_url = ARGV[2]

last_char = path[path.length-1, path.length-1]
if last_char != "/"
  path=path+"/"
end

#if File::directory?( path )
#  puts "Valid Directory"
#else
#  puts "Invalid Directory"
#  exit
#end 


#variables
book_full_name = "com.medhand.books."+book_name
zip_des = path+book_full_name+"/"

puts "Downloading from Git-hub\n"
#Run git-hub
if system("git clone "+git_url+" "+path)
  print "Download successful\n"
else
  print "Download Failed\n"
  exit;
end

#Copy Common Dir required to run DR Compantion tool
file="common.zip"
zipdestination=File.expand_path("..",path)+"/"

  Zip::ZipFile.open(file) { |zip_file|
   zip_file.each { |f|
     f_path=File.join(zipdestination, f.name)
     FileUtils.mkdir_p(File.dirname(f_path))
     zip_file.extract(f, f_path) unless File.exist?(f_path)
   }
}


#Run Drcompanion-tool

if system("MXmlResource/MXmlResource.exe #{path}")
  print "Drcompanion conversion success"
else
  print "Drcompanion conversion Failed"
  exit;
end


# Run Encrypt & GZip
encrypt_src=path+"output/ihtml/"
print "Running Encrytion & GZip of html files\n"
if system("java -jar encryptor.jar #{encrypt_src} #{zip_des} #{encrypt_key}")
  print "Encrytion & Gzip success\n"
else
  print "Encryption Failed\n"
  exit;
end

# Run Search Db script
print "Run Search Script\n"
search_path=zip_des+"search/"
print "Generating search DB file\n"
if system("ruby xml-to-sqlite-transfer.rb #{search_path}")
  print "Search DB successfully generated"
else
  print "Search DB generation failed"
  exit;
end

# Move SearchDb.sql to root path
File.move("#{search_path}searchDB.sql", "#{zip_des}")
print "searcDB.sql moved successfully\n"

# Zip the files
print "Zipping in process\n"
zip_path=zip_des
archive = File.join(zip_path,File.basename(zip_path))+'.zip'
FileUtils.rm archive, :force=>true
Zip::ZipFile.open(archive, 'w') do |zipfile|
  Dir["#{zip_path}/**/**"].reject{|f|f==archive}.each do |file|
    zipfile.add(file.sub(zip_path+'/',''),file)
  end
end
print "Zip done successfully"

print "\nCompleted"