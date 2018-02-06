require 'fileutils'
require 'ftools'
require 'zip/zip'

#CONSTANTS
encrypt_key="ps17"

unless ARGV.length == 3
  puts "Invalid Arguments"
  puts "Usage: ruby automation.rb <book_name> <book_path>"
  exit
end

book_name=ARGV[0]
path = ARGV[1]
new = ARGV[2]

last_char = path[path.length-1, path.length-1]
if last_char != "/"
  path=path+"/"
end

difFolder=new+"diff_folder/";
oldFolder= path+"output/ihtml/"
newFolder=new+"output/ihtml/"

#variables
book_full_name = "com.medhand.books."+book_name
zip_des = new+book_full_name+"/"

if !(File.directory?(difFolder))
  Dir.mkdir(difFolder)
end

@files = Dir.glob(newFolder+"**/**")
for file in @files
     partName=file.split(newFolder).last     
     if (File.directory?(file))
        if !File.exist?(oldFolder+partName)
          if !File.exist?(difFolder+partName)
            Dir.mkdir(difFolder+partName)
            puts "Dir Created -" + partName
          else
            puts "Target Dir Exists -" + partName
          end
        end
     else
       if !File.exist?(oldFolder+partName)
         folder= partName.split(partName.split("/").last).first
         if !File.exist?(difFolder+folder)
           Dir.mkdir(difFolder+folder)
           puts "Dir Created -" + partName
         end
         File.copy(file,difFolder+folder)
         puts "File Copied -"+file
       elsif !(File.compare(file,oldFolder+partName))
         folder= partName.split(partName.split("/").last).first
         if !File.exist?(difFolder+folder)
           Dir.mkdir(difFolder+folder)
           puts "Dir Created -" + partName
         end
         File.copy(file,difFolder+folder)
         puts "File Copied -"+file
       end
     end
end

# Run Encrypt & GZip
encrypt_src=difFolder
print "Running Encrytion & GZip of html files\n"

if system("java -jar encryptor.jar #{encrypt_src} #{zip_des} #{encrypt_key}")
  print "Encrytion & Gzip success\n"
else
  print "Encryption Failed\n"
  exit;
end

# Run Search Db script
print "Run Search Script\n"
search_path=newFolder+"search/"
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




