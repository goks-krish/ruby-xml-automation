require 'ftools'
require 'zip/zip'
require 'time'
require 'xmlsimple'

# Make Directory subroutine
def createFolder(folderPath)
  @folderParts=folderPath.split("/")
  newFdr=""
  for partName in @folderParts
    newFdr=newFdr+partName+"/"
    if !File.exist?(newFdr)
       Dir.mkdir(newFdr)
    end
  end
end

#validate inputs
unless ARGV.length == 1
  puts "Invalid Arguments"
  puts "Usage: ruby automation.rb <book_path>"
  exit
end

path = ARGV[0]

last_char = path[path.length-1, path.length-1]
if last_char != "/"
  path=path+"/"
end

if File::directory?( path )
  puts "Valid Directory"
else
  puts "Invalid Directory"
  exit
end 

automation_config_file=path+"automation_config.xml"

if File::exists?( automation_config_file )
  puts "automation_config.xml present"
else
  puts "automation_config.xml missing in "+path
  exit
end 

#Extract values from automation_config.xml
xmldoc = XmlSimple.xml_in(automation_config_file)

book_full_name=xmldoc['book_full_name'].first
encrypt_key=xmldoc['encrytion_key'].first
new_book_timestamp=temp_value=Time.parse(xmldoc['initial_timestamp'].first)
latest_timestamp=new_book_timestamp;
    
#variables
zip_des = path+book_full_name+"/"

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

output_path=path+"output"
difFolder=path+"diff_folder"
outputRenamed=""
#Check if older Output exists
if File.exists?(output_path) && File.directory?(output_path)
  puts "Output Dir Exists. Executing File difference operations"
  #Rename output folder
  timestamp = File.mtime(output_path).to_s()
  timestamp = timestamp.gsub(":","-");
  timestamp = timestamp.gsub(" ","_");
  outputRenamed=output_path+"_"+ timestamp
  File.rename(output_path, outputRenamed)  
  #Rename diff folder
  if File.exists?(difFolder) && File.directory?(difFolder)
    timestamp = File.mtime(difFolder).to_s()
    timestamp = timestamp.gsub(":","-");
    timestamp = timestamp.gsub(" ","_");
    diff_rename=difFolder+"_"+timestamp
    File.rename(difFolder, diff_rename)
  end
  Dir.mkdir(difFolder)
else
  puts "Output Dir does not exist. Creating new book zip "
end

#Run Drcompanion-tool
if system("MXmlResource/MXmlResource.exe #{path}")
  print "Drcompanion conversion success"
else
  print "Drcompanion conversion Failed"
  exit;
end

oldFolder= outputRenamed+"/ihtml/"
newFolder=path+"output/ihtml/"
difFolder=difFolder+"/"
if(outputRenamed!="")
  #Run Diff Operations
  latest_timestamp=File.mtime(zip_des+"searchDB.sql")+60
  @files = Dir.glob(newFolder+"**/**")
  for file in @files
       partName=file.split(newFolder).last     
       if (File.directory?(file))
          if !File.exist?(oldFolder+partName)
            if !File.exist?(difFolder+partName)
              #Dir.mkdir(difFolder+partName)
              createFolder(difFolder+partName)
              puts "Dir Created -" + partName
            else
              puts "Target Dir Exists -" + partName
            end
          end
       else
         if !File.exist?(oldFolder+partName)
           folder= partName.split(partName.split("/").last).first
           if !File.exist?(difFolder+folder)
             #Dir.mkdir(difFolder+folder)
             createFolder(difFolder+folder)
             puts "Dir Created -" + partName
           end
           File.copy(file,difFolder+folder)
           puts "File Copied -"+file
         elsif !(File.compare(file,oldFolder+partName))
           folder= partName.split(partName.split("/").last).first
           if !File.exist?(difFolder+folder)
             #Dir.mkdir(difFolder+folder)
             createFolder(difFolder+folder)
             puts "Dir Created -" + partName
           end
           File.copy(file,difFolder+folder)
           puts "File Copied -"+file
         end
       end
  end

  #Created Deleted Files list
  deletedFileList=zip_des+"Deleted_List.txt"
  timestamp = latest_timestamp.to_s()
  deletedFileName=""
  deletedFilesCount=0;
  @files = Dir.glob(oldFolder+"**/**")
  for file in @files
    partName=file.split(oldFolder).last
    if !File.exist?(newFolder+partName)
      if (File.directory?(file))
        deletedFileName=partName + "/"
      else
        deletedFileName=partName
      end
       deletedFileName=  timestamp +"\t"+deletedFileName
      open(deletedFileList, 'a') { |f|
        f.puts deletedFileName
      }
      deletedFilesCount=deletedFilesCount+1    
    end
  end
  
  # Deleted file list copied to diff-folder
  if deletedFilesCount!=0
    File.copy(deletedFileList,difFolder)    
  end  
  
  # Copy info.plist to root path
  if File.exists?(path+"info.plist")
    if File.exists?(zip_des+"info.plist") && !File.compare(zip_des+"info.plist",path+"info.plist")
      File.copy("#{path}info.plist", "#{difFolder}")
    elsif !File.exists?(zip_des+"info.plist")
      File.copy("#{path}info.plist", "#{difFolder}")
    end
  end
  
  encrypt_src=difFolder
  print "Running Encrytion & GZip of DIFF html files\n"
  if system("java -jar encryptor.jar #{encrypt_src} #{zip_des} #{encrypt_key}")
    print "Encrytion & Gzip success\n"
  else
    print "Encryption Failed\n"
    exit;
  end    
  
  # Change timestamp
  @files = Dir.glob(difFolder+"**/**")
  for file in @files
    partName=file.split(difFolder).last
    if File.exist?(zip_des+partName)
      File.utime(latest_timestamp, latest_timestamp, zip_des+partName)
    end
  end
  
else
  # Run Encrypt & GZip for NEW BOOK
  encrypt_src=path+"output/ihtml/"
  print "Running Encrytion & GZip of html files\n"
  if system("java -jar encryptor.jar #{encrypt_src} #{zip_des} #{encrypt_key}")
    print "Encrytion & Gzip success\n"
  else
    print "Encryption Failed\n"
    exit;
  end
 
  # Copy info.plist to root path
  if File.exists?(path+"info.plist")
      File.copy("#{path}info.plist", "#{zip_des}")
  end
  
  # Change timestamp
  @files = Dir.glob(zip_des+"**/**")
  for file in @files
    File.utime(new_book_timestamp, new_book_timestamp, file)
  end
  
end

if(outputRenamed=="" || !File.exists?(difFolder) || Dir.glob(difFolder+"**/**") .length!=0 )
  # Run Search Db script
  print "Run Search Script\n"
  search_path=path+"output/"
  print "Generating search DB file\n"
  if system("ruby xml-to-sqlite-transfer.rb #{search_path}")
    print "Search DB successfully generated\n"
  else
    print "Search DB generation failed"
    exit;
  end

  # Copy SearchDb.sql to root path
  File.copy("#{search_path}searchDB.sql", "#{zip_des}")
  print "searchDB.sql copied successfully\n"
  
  # Change timestamp of searchDb.sql
  File.utime(latest_timestamp, latest_timestamp, search_path+"searchDB.sql")
  File.utime(latest_timestamp, latest_timestamp, zip_des+"searchDB.sql")
  
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
end

print "\nCompleted"