require 'ftools'
require 'zip/zip'
require 'time'
require 'xmlsimple'
require 'sqlite3'

##### START SUB ROUTINE DEFINATION

# Init and Validate automation run subroutine
def initAutomation()
  puts "Initializing Automation"
  #validate inputs
  unless ARGV.length == 1
    puts "Invalid Arguments"
    puts "Usage: ruby automation.rb <book_path>"
    exit
  end
  @path = ARGV[0] 
  @automation_config_file=@path+"automation_config.xml"  
  last_char = @path[@path.length-1, @path.length-1]
  if last_char != "/"
    @path=@path+"/"
  end 
  if File::directory?( @path )
    puts "Valid Directory-"+@path
  else
    puts "Invalid Directory"
    exit
  end
  #Check if required folders are present
  cssFolder=@path+"css/"
  if !File::directory?(cssFolder)
    puts "css folder not present in "+@path
    exit
  end  
  defineFolder=@path+"define/"
  if !File::directory?(defineFolder)
    puts "define folder not present in "+@path
    exit
  end  
  xmlFolder=@path+"xml/"
  if !File::directory?(xmlFolder)
    puts "xml folder not present in "+@path
    exit
  end    
  xsltFolder=@path+"xslt/"
  if !File::directory?(xsltFolder)
    puts "xslt folder not present in "+@path
    exit
  end     
end

# Extract values from automation_config.xml subroutine
def extractConfigDetails(automation_config_file)
  puts "Extract information from "+automation_config_file
  if File::exists?(automation_config_file)
    puts "automation_config.xml present"
  else
    puts "automation_config.xml missing in "+@path
    exit
  end 
  xmldoc = XmlSimple.xml_in(automation_config_file)
  #Constants
  @BUNDLE_BY_NONE = 0
  @BUNDLE_BY_SIZE = 1
  @BUNDLE_BY_FILE_COUNT =3
  #Variables
  @new_book_operation=false
  all_fields_ok=true
  if xmldoc['book_full_name']==nil
    all_fields_ok=false
  else
    @book_full_name=xmldoc['book_full_name'].first
  end
  if xmldoc['encrytion_key']==nil
    all_fields_ok=false
  else
    @encrypt_key=xmldoc['encrytion_key'].first
  end
  if xmldoc['initial_timestamp']==nil
    all_fields_ok=false
  else
    @new_book_timestamp=Time.parse(xmldoc['initial_timestamp'].first)
  end
  if xmldoc['max_update_limit']==nil
    all_fields_ok=false
  else
    @max_update_limit=xmldoc['max_update_limit'].first
  end    
  if xmldoc['update_timestamp']==nil
    @new_book_operation=true
  else
    @update_timestamp=Time.parse(xmldoc['update_timestamp'].last)
  end
  if xmldoc['max_file_size']==nil
    if xmldoc['max_file_count']==nil
      @bundle_type= @BUNDLE_BY_NONE
    else      
      @max_file_count=xmldoc['max_file_count'].first
      @bundle_type= @BUNDLE_BY_FILE_COUNT
    end
  else
    @max_file_size=xmldoc['max_file_size'].first
    @bundle_type=@BUNDLE_BY_SIZE
  end  
  if all_fields_ok==false
    puts "Invalid automation_config.xml in "+@path
    exit    
  end
  @book_prod_folder = @path+@book_full_name+"/"
  @outputRenamed = @path+"output-old" ##* (TESTING-@path+"output-old" & comment drcomp) OR change to ""
  @book_diff_folder=""
  @updateFolder=""
  @book_update_folder=""
  @book_zip_generated_folder=""
  @latest_ts=Time.now
end

# Download Fass xml from server
def runFassDownloader()
  xmldoc = XmlSimple.xml_in(@automation_config_file)
  run_fass="true";
  id="";
  check_interval=0;
  if xmldoc['run_downloader']==nil
    run_fass=false
    puts "Tool enable flag not present in config file"
   else
    run_fass=xmldoc['run_downloader'].first
   end  
  if xmldoc['user_id']==nil
    run_fass=false
    puts "User id data not present in config file"
   else
    id=xmldoc['user_id'].first
   end
  if xmldoc['check_interval']==nil
    run_fass=false
    puts "check_interval data not present in config file"
   else
    check_interval=xmldoc['check_interval'].first
   end
   time_now = Time.now-(3600*24*check_interval.to_i)
   day_num=time_now.day
   month_num=time_now.month
   day=""
   month=""
   if(day_num<10)
     day="0"+day_num.to_s()
   else
     day=day_num.to_s()
   end
   if(month_num<10)
      month="0"+month_num.to_s()
   else
      month=month_num.to_s()
   end
   fromDate=time_now.year.to_s()+"-"+month+"-"+day   
   if(@new_book_operation==true)
     if xmldoc['start_date']==nil
        run_fass=false
        puts "start_date data not present in config file"
       else
        fromDate=xmldoc['start_date'].first
     end
   end
   if(run_fass=="true")
     path=@path+"xml/xml/"
     if system("FassDownloader.exe #{path} #{id} #{fromDate}")
       print "success"
     else
       exit;
     end
     file_temp=""
     if xmldoc['manifest_file']==nil
       run_fass=false
       puts "manifest_file data not present in config file"
       exit;
     else
       file_temp=xmldoc['manifest_file'].first
      end
     manifest_file=@path+"xml/"+file_temp;
     if system("java -jar manifest_generator.jar #{path} #{manifest_file}")
        print "Manifest Generation success\n"
      else
        print "Manifest Generation Failed\n"
        exit;
      end
   else 
     puts "Downloader Tool will not run"
   end
   
end

# Copy Zip file to Destination
def copyZipContents(file,zipdestination)
    Zip::ZipFile.open(file) { |zip_file|
     zip_file.each { |f|
       f_path=File.join(zipdestination, f.name)
       FileUtils.mkdir_p(File.dirname(f_path))
       zip_file.extract(f, f_path) unless File.exist?(f_path)
     }
  }
end

# Run Drcompation subroutine
def runDrcompanion(path)
  puts "Preparing to run Drcompanion tool"
  #Copy Common Dir required to run DR Compantion tool
  file="common.zip"
  zipdestination=File.expand_path("..",path)+"/"
  copyZipContents(file,zipdestination)
  #Rename existing output folder if exists
  output_path=path+"output"
  if File.exists?(output_path) && File.directory?(output_path)
    timestamp = File.mtime(output_path).to_s()
    timestamp = timestamp.gsub(":","-");
    timestamp = timestamp.gsub(" ","_");
    @outputRenamed=output_path+"_"+ timestamp
    File.rename(output_path, @outputRenamed)
  elsif @new_book_operation==false
    puts "Previously run output folder not found in "+path
    exit  
  end
  
  #Run Drcompanion-tool
  if system("MXmlResource/MXmlResource.exe #{path}")
    print "Drcompanion conversion success"
  else
    print "Drcompanion conversion incomplete"
    exit;
  end
end

# FileCopy subroutine
def copyFile(file_src, file_des)
  if File.exists?(file_src)
    if File.directory?(file_src)
      puts "Source is a Dir"
    else
      File.copy("#{file_src}", "#{file_des}")
    end
  else
    puts "File Not found in "+file_src
  end
end

# Make Directory and sub-dir subroutine
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

def createFolderWithTimestamp(folderPath,ts)
  @folderParts=folderPath.split("/")
  newFdr=""
  for partName in @folderParts
    newFdr=newFdr+partName+"/"
    if !File.exist?(newFdr)
      Dir.mkdir(newFdr)
      File.utime(ts, ts, newFdr)
    end
  end
end

#Print variables subroutine
def printAll()
  puts "path:"+@path
  puts "automation-config-file:"+@automation_config_file
  puts "book_full_name:"+@book_full_name
  puts "encrypt_key:"+@encrypt_key
  puts "new_book_timestamp:"+@new_book_timestamp.to_s()
  puts "max_file_size:"+@max_file_size
  puts "max_file_count:"+@max_file_count    
  puts "update_timestamp:"+@update_timestamp.to_s()
  puts "book_prod_folder:"+@book_prod_folder  
end

# Run Encryptor & gzip subroutine
def runEncryptor(encrypt_src,encrypt_des)
  print "Running Encrytion & GZip of html files\n"
  if system("java -jar encryptor.jar #{encrypt_src} #{encrypt_des} #{@encrypt_key}")
    print "Encrytion & Gzip success\n"
  else
    print "Encryption Failed\n"
    exit;
  end
end

# Generate searchDB.sql
def searchDBGeneration(search_path,target_path)
  puts "Generating searchDB.sql"
  if system("ruby xml-to-sqlite-transfer.rb #{search_path} #{target_path}")
    print "Search DB successfully generated\n"
  else
    print "Search DB generation failed"
    exit;
  end
end

# Change timestamp subroutine
def changeTimestamp(dest_folder,new_timestamp)
  @files = Dir.glob(dest_folder+"**/**")
  for file in @files
    File.utime(new_timestamp, new_timestamp, file)
  end  
end

# Zip creation subroutine
def createZip(zip_src_path,zip_des,zip_pref)
  print "Zipping in process\n"
#  archive = File.join(zip_path,File.basename(zip_path))+'.zip'
#  FileUtils.rm archive, :force=>true
#  Zip::ZipFile.open(archive, 'w') do |zipfile|
#    Dir["#{zip_path}/**/**"].reject{|f|f==archive}.each do |file|
#      zipfile.add(file.sub(zip_path+'/',''),file)
#    end
#  end
#  print "Zip done successfully"  
  if system("java -jar zipUtil.jar #{zip_src_path} #{zip_des} #{zip_pref}")
    print "Zip success\n"
  else
    print "Zip Failed\n"
    exit;
  end    
end

# Create book production folder
def createProdFolder(path) 
  # Create book production folder
  @book_zip_generated_folder=path+"book_prod_folder/"
  if (File.exists?(@book_zip_generated_folder) && File.directory?(@book_zip_generated_folder))
    puts "Book Production folder exists"
  else
    Dir.mkdir(@book_zip_generated_folder)
  end
end

# Create folders for update operation
def createFolders(path)
  #timeutc = @update_timestamp.utc
  update_ts=@update_timestamp.to_s()
  update_ts=update_ts.split(" +").first
  update_ts = update_ts.gsub(":","-")
  update_ts = update_ts.gsub(" ","_")

  # Create root diff folder
  difFolder=path+"diff_folder/"
  if !(File.directory?(difFolder))
    Dir.mkdir(difFolder)
  end

  # Create book diff folder
  @book_diff_folder=difFolder+update_ts+"/"
  if File.directory?(@book_diff_folder)
    FileUtils.rm_rf(@book_diff_folder)
    #File.rename(@book_diff_folder, @book_diff_folder+"-OLD_"+current_ts)
  end
  Dir.mkdir(@book_diff_folder)
  
  # Create update root folder
  @updateFolder=path+@book_full_name+"_update/"
  if !(File.directory?(@updateFolder))
    Dir.mkdir(@updateFolder)
  end
  
  # Create update book folder
  @book_update_folder=@updateFolder+update_ts+"/"
  if File.directory?(@book_update_folder)
    #File.rename(@book_update_folder, @book_update_folder+"-OLD_"+current_ts)
    File.rename(@book_update_folder, @updateFolder+update_ts+"-OLD")    
    FileUtils.rm_rf(@updateFolder+update_ts+"-OLD")
  end    
  Dir.mkdir(@book_update_folder)
end

# Run Diff operations for update book
def runDiffOperation(new_output, old_output, diff_folder)
  #Searching for New & updated files
  @files = Dir.glob(new_output+"**/**")
  for file in @files
       partName=file.split(new_output).last     
       if (File.directory?(file))
          if !File.exist?(old_output+partName)
            if !File.exist?(diff_folder+partName)
              createFolder(diff_folder+partName)
              puts "Dir Created -" + partName
            else
              puts "Target Dir Exists -" + partName
            end
          end
       else
         #New file copy operation
         if !File.exist?(old_output+partName)           
           folder= partName.split(partName.split("/").last).first
           if folder==nil
             folder=""
           end
           if !File.exist?(diff_folder+folder)
             createFolder(diff_folder+folder)
             puts "Dir Created -" + diff_folder+folder
           end
           File.copy(file,diff_folder+folder)
           puts "New File Copied -"+file +" to "+diff_folder+folder
         #Updated file copy operation
         elsif !(File.compare(file,old_output+partName))
           folder= partName.split(partName.split("/").last).first
           if folder==nil 
             folder=""
           end
           if !File.exist?(diff_folder+folder)
             createFolder(diff_folder+folder)
             puts "Dir Created -" + diff_folder+folder
           end
           File.copy(file,diff_folder+folder)
           puts "Updated File Copied -"+file +" to "+diff_folder+folder
         end
       end
  end
  #Searching for Deleted files & creating the list
  deletedFileList=diff_folder+"deletedFiles.list"
  timestamp = Time.now.to_s()
  deletedFileName=""
  deletedFilesCount=0;
  @files = Dir.glob(old_output+"**/**")
  for file in @files
    partName=file.split(old_output).last
    check=partName.include?'search/'
    if !File.exist?(new_output+partName) && !check
      if !(File.directory?(file))
        deletedFileName=partName.split("/").last
        open(deletedFileList, 'a') { |f|
          f.puts deletedFileName
        }
      end
#      deletedFileName=  timestamp +"\t"+deletedFileName
      deletedFilesCount=deletedFilesCount+1    
    end
  end
  if Dir.glob(diff_folder+"**/**") .length==0
    if (File.directory?(diff_folder))
      Dir.rmdir(diff_folder)
    end
    if (File.directory?(@book_update_folder))
      Dir.rmdir(@book_update_folder)
    end 
    puts "No Changes made"
    exit
  end
end

def zipBundle(file,time_stamp)
  ts=time_stamp.to_s()
  ts = ts.split(" +").first
  ts = ts.gsub(":","-")
  ts = ts.gsub(" ","_")
  sub_folder=file.split(@book_update_folder).last
  inner_folder=""  
  if sub_folder.include?("/")
    file_name=sub_folder.split("/").last
    inner_folder=sub_folder.split(file_name).first
  end
  bundle_folder=@book_update_folder+ts+"/"+@book_full_name+"/"+inner_folder
  if !(File::directory?(bundle_folder))
    createFolderWithTimestamp(bundle_folder,time_stamp)
  end
  copyFile(file,bundle_folder)
  if File.exists?(file) 
    FileUtils.rm(file)
  end
  
  File.utime(time_stamp, time_stamp, @book_update_folder+ts+"/"+@book_full_name+"/"+sub_folder) 
#  archive=@book_update_folder+ts+".zip"
#  zip_inner_path=@book_full_name+"/"+file.split(@book_update_folder).last  
#  Zip::ZipFile.open(archive, 'w') do |zipfile|
#    zipfile.add(zip_inner_path,file)
#  end  
#  File.utime(time_stamp, time_stamp, archive)  
  return @book_update_folder+ts
end

def generateZipBundle() 
  update_date=@update_timestamp.to_s().split(" ").first
  @files = Dir.glob(@book_update_folder+"**")
  for file in @files
    if File::directory?(file)
      srcFolder=file
      zipFile=file+".zip"
      tempsrc=srcFolder.split("/").last
      if tempsrc.include?update_date
        if system("java -jar zipUtil.jar #{srcFolder} #{zipFile} 0")
            print "Zip Bundle success\n"
          else
            print "Zip Bundle Failed\n"
            exit;
         end  
      end
      FileUtils.rm_rf(file)
    end
  end
end

# Change timestamp of bundle subroutine file count
def bundleTimestampFileCount(dest_folder,new_timestamp,max_count)
  puts "Modifying timestamp based on file count"
#  ts= Time.parse(new_timestamp.utc.to_s().split("UTC").first)  
  ts= Time.parse(new_timestamp.to_s())
  intial_ts=ts
  fileCount=0  
  old_output_ihtml=@outputRenamed+"/ihtml/"
  # Timestamp new files  
  @files = Dir.glob(dest_folder+"**/**")
  for file in @files
    partName=file.split(dest_folder).last
    if !(File.exists?old_output_ihtml+partName) && !(File.directory?(file))
      if !file.to_s().end_with?("searchDB.sql") && !file.to_s().end_with?("deletedFiles.list")
        if(fileCount>=max_count)
          ts=ts+60
          fileCount=0
        end
        File.utime(ts, ts, file)  
        # Add to zip bundle        
        archive=zipBundle(file,ts)
        fileCount=fileCount+1
      end
    end
    if !(File.exists?old_output_ihtml+partName) && File.directory?(file)
      File.utime(ts, ts, file)
    end
  end  
  # searchDB.sql timestamp as the last bundle of new files but before edited files
  if File.exists?(dest_folder+"searchDB.sql")
    if(fileCount>=max_count)
      ts=ts+60
      fileCount=0
    end
    File.utime(ts, ts, dest_folder+"searchDB.sql")
    # Add to zip bundle        
    archive=zipBundle(dest_folder+"searchDB.sql",ts)
    fileCount=fileCount+1
  end
  # Timestamp edited files after new files and searchDB.sql
  @files = Dir.glob(dest_folder+"**/**")
  for file in @files
    partName=file.split(dest_folder).last
    if File.exists?(old_output_ihtml+partName) && !(File.directory?(file))
      if !file.to_s().end_with?("searchDB.sql") && !file.to_s().end_with?("deletedFiles.list")
        if(fileCount>=max_count)
          ts=ts+60
          fileCount=0
        end
        File.utime(ts, ts, file)
        # Add to zip bundle        
        archive=zipBundle(file,ts)  
        fileCount=fileCount+1
      end
    end
    if File.directory?(file)
      File.utime(intial_ts, intial_ts, file)
    end    
  end  
  # Timestamp deleted file as last bundle
  if (File.exists?(dest_folder+"deletedFiles.list"))
    if(fileCount>=max_count)
      ts=ts+60
      fileCount=0
    end
    File.utime(ts, ts, dest_folder+"deletedFiles.list")
    # Add to zip bundle        
    archive=zipBundle(dest_folder+"deletedFiles.list",ts)
    fileCount=fileCount+1
  end
  generateZipBundle()   
  @latest_ts=ts+60
end

# Change timestamp of bundle subroutine by size
def bundleTimestampBundleSize(dest_folder,new_timestamp,max_size)  
  puts "Modifying timestamp based on size"
  max_size=max_size*1024
  target_folder=""
#  ts= Time.parse(new_timestamp.utc.to_s().split("UTC").first)
  ts= Time.parse(new_timestamp.to_s())
  initial_ts=ts
  fileSize=0  
  total_file_count=0 
  old_output_ihtml=@outputRenamed+"/ihtml/"  
  # Timestamp new files  
  @files = Dir.glob(dest_folder+"**/**")
  for file in @files
    partName=file.split(dest_folder).last
    if !(File.exists?old_output_ihtml+partName) && !(File.directory?(file))
      if !file.to_s().end_with?("searchDB.sql") && !file.to_s().end_with?("deletedFiles.list")
        fileSize=fileSize+File.size(file)       
        if(fileSize>=max_size)
          ts=ts+60
          fileSize=File.size(file)
        end 
        File.utime(ts, ts, file)
        total_file_count=total_file_count+1
        # Add to zip bundle        
        target_folder=zipBundle(file,ts)
      end
    end
    if !(File.exists?old_output_ihtml+partName) && File.directory?(file)     
      File.utime(ts, ts, file)
    end
  end  
  # searchDB.sql timestamp as the last bundle of new files but before edited files
  if File.exists?(dest_folder+"searchDB.sql")    
    fileSize=fileSize+File.size(dest_folder+"searchDB.sql")   
    if(fileSize>=max_size && total_file_count!=0)
      ts=ts+60      
      fileSize=File.size(dest_folder+"searchDB.sql")    
    end 
    File.utime(ts, ts, dest_folder+"searchDB.sql")
    total_file_count=total_file_count+1
    # Add to zip bundle        
    archive=zipBundle(dest_folder+"searchDB.sql",ts)
  end
  # Timestamp edited files after new files and searchDB.sql
  @files = Dir.glob(dest_folder+"**/**")
  for file in @files
    partName=file.split(dest_folder).last
    if File.exists?(old_output_ihtml+partName) && !(File.directory?(file))
      if !file.to_s().end_with?("searchDB.sql") && !file.to_s().end_with?("deletedFiles.list")
        fileSize=fileSize+File.size(file)    
        if(fileSize>=max_size)
          ts=ts+60
          fileSize=File.size(file)
        end 
        File.utime(ts, ts, file) 
        total_file_count=total_file_count+1
        # Add to zip bundle        
        archive=zipBundle(file,ts) 
      end
    end
    if File.directory?(file)
      File.utime(initial_ts, initial_ts, file)
    end    
  end  
  # Timestamp deleted file as last bundle
  if (File.exists?(dest_folder+"deletedFiles.list"))
    fileSize=fileSize+File.size(dest_folder+"deletedFiles.list") 
    if(fileSize>=max_size)
      ts=ts+60
      fileSize=File.size(dest_folder+"deletedFiles.list") 
    end 
    File.utime(ts, ts, dest_folder+"deletedFiles.list")
    total_file_count=total_file_count+1
    # Add to zip bundle        
    archive=zipBundle(dest_folder+"deletedFiles.list",ts) 
  end
  generateZipBundle() 
  @latest_ts=ts+60
end

# Change timestamp of bundle subroutine by size
def bundleTimestampNone(dest_folder,new_timestamp)
  @files = Dir.glob(dest_folder+"**/**")
  for file in @files
    File.utime(new_timestamp, new_timestamp, file)
    if !(File::directory?(file))
      # Add to zip bundle        
      archive=zipBundle(file,new_timestamp)
    end 
  end
  generateZipBundle() 
  @latest_ts=new_timestamp+60
end  

# Copy folder Contents
def copyFolderContents(src,dest)
  @files = Dir.glob(src+"**/**")
  folder=""
  for file in @files
    partName=file.split(src).last    
    folder= partName.split(partName.split("/").last).first
    if (folder!=nil)
      if !File.exist?(dest+folder)
        createFolder(dest+folder)
      end
    end
    # Copy file
    if !file.include?'deletedFiles.list'
      if !File.directory?(file)
        copyFile(file,dest+partName)
      else
        createFolder(dest+partName)
      end
      # Update Timestamp
      time_stamp=File.mtime(file)      
      File.utime(@update_timestamp, @update_timestamp, dest+partName)
    end    
  end
end

#Search for links inside html files
def all_links_verify(folder_path)
  puts "Validating all links inside HTML"
  @files = Dir.glob(folder_path+"**/**")
   for each_file in @files 
     if each_file.include?(".htm")
       file = File.new(each_file, "r")
         while (line = file.gets)
           text=line.split("href") 
           text.each do |part|
             if (part.include?(".htm") || part.include?(".css")) &&  !part.include?("http://") &&  !part.include?("https://")
               link= part.split("\"")                            
               url_link= link[1].split("../").last                
               url_link=url_link.split("#").first
               if  url_link==nil
                 url_link=""
               end
               if (File.exists?(folder_path+url_link))
                  puts folder_path+url_link+"  -- ok"
               else 
                  puts "Page not found -"+folder_path+url_link
                  exit
               end
             end
           end
       file = File.new(each_file, "r") 
         while (line = file.gets)
           text=line.split("src") 
           text.each do |part|
             if (part.include?(".js") || part.include?(".jpg")) &&  !part.include?("http://") &&  !part.include?("https://")
               link= part.split("\"")
               url_link= link[1].split("../").last 
               url_link=url_link.split("#").first
                if File.exists?(folder_path+url_link)
                  puts folder_path+url_link+"  -- ok"
                else 
                  puts "Page not found -"+folder_path+url_link
                  exit
                end
             end
           end
         end
         end
       file.close
     end
  end
end

# Search for all url in searchdb.sql
def searchdb_link_verify(searchdb_file,book_final_path)
  puts "Validating searchDB.sql"
  if !File.exists?(searchdb_file)
    puts "searchDB.sql missing in "+book_final_path
  end
  db = SQLite3::Database.new(searchdb_file)
  query= "select name from sqlite_master where type='table'"
  tables_list = db.execute( query ) do |table|
    query="PRAGMA table_info(#{table[0]})"
    columns_list = db.execute( query ) do |column|
      if(column[1]=='url')
        query= "select url from #{table[0]}"
        db.execute( query ) do |url|
          url[0]=url[0].split("#").first
          if File.exists?(book_final_path+url[0])
            puts book_final_path+url[0]+"  -- ok"
          else 
            puts "Page not found -"+book_final_path+url[0]
            exit
          end
        end
      end
    end
   end
end

# validate info.plist values subroutine
def validateInfoPlist(file_path)
  puts "Validating info.plist"
	xmldoc = XmlSimple.xml_in(file_path)
	xmlkeys= xmldoc['dict']
	key=["a"]
	value=["a"]
	i=0;	
	xmlkeys[0].each do |data|
	  if i==0
		key=data
	  elsif i==1
		value=data
	  end
	 i=i+1
	end
	key=key[1]
	value=value[1]
	i=0;
	key.each do |key_data|
		if key_data=="bookDirectory" || key_data=="bookID"
			temp=value[i].split("com.medhand.books.").last
			if temp.include?"."
				puts "info.plist: Invalid value for "+key_data + "\n"+value[i]
				exit
			end
			if !(value[i]==@book_full_name)
			  puts key_data+" value mismatch- "+value[i]
			  puts "Expected: "+@book_full_name
			  exit
			end
		end
		i=i+1
	end
end

def verifyFolders(folderPath)
  if !File.directory?(folderPath+"css")
    puts "css folder missing in "+folderPath
    exit
  end
  if !File.directory?(folderPath+"html")
    puts "html folder missing in "+folderPath
    exit
  end
  if !File.directory?(folderPath+"icons")
    puts "icons folder missing in "+folderPath
    exit
  end
  if !File.directory?(folderPath+"images")
    puts "images folder missing in "+folderPath
    exit
  end
  if !File.directory?(folderPath+"script")
    puts "script folder missing in "+folderPath
    exit
  end
  if !File.directory?(folderPath+"symbols")
    puts "symbols folder missing in "+folderPath
    exit
  end
  if !File.directory?(folderPath+"images/balloons")
    puts "images/balloons folder missing in "+folderPath
    exit
  end
  if !File.directory?(folderPath+"script/balloons")
    puts "script/balloons folder missing in "+folderPath
    exit
  end
  if !File.exist?(folderPath+"info.plist")
    puts "info.plist in "+folderPath
    exit
  end
end

# Get the folder size subroutine
def getFolderSize(folder)
  total_size=0
  @files = Dir.glob(folder+"**/**")
  for file in @files
    total_size=total_size+File.size(file)
  end  
  return total_size
end

# Delete update folder
def deleteUpdateFolderContents(diff_size)
  deleted_size=0
  xmldoc = XmlSimple.xml_in(@automation_config_file)
  update_ts_array=xmldoc['update_timestamp']
  update_ts_array.each do |time_value|
    timeutc=Time.parse(time_value)
#    timeutc = timeutc.utc
    ts=timeutc.to_s()
    ts = ts.split(" +").first
    ts = ts.gsub(":","-")
    ts = ts.gsub(" ","_")
    folder_name= @updateFolder+ts+"/"
    if deleted_size<diff_size
      deleted_size=deleted_size+getFolderSize(folder_name)
      time_stamp=File.mtime(folder_name)  
      #FileUtils.rm_rf(folder_name)
      @files = Dir.glob(folder_name+"**")
      for file in @files
        if File.directory?(file)
          FileUtils.rm_rf(file)
        elsif File.exist?(file)
          FileUtils.rm(file)
        end
      end
      File.utime(time_stamp,time_stamp,folder_name)
      puts "Deleted Contents in -"+folder_name
    end
  end
end

# Check for update limit and delete updates if it exceeds
def update_limit_check() 
  book_size=getFolderSize(@book_prod_folder)
  updates_size=getFolderSize(@updateFolder)
  accepted_size=(book_size*@max_update_limit.to_i())/100
  if(updates_size>accepted_size)
    diff_size=updates_size-accepted_size
    deleteUpdateFolderContents(diff_size)
  end
end

# New Book creation subroutine
def createNewBook(path)
  puts "Create New Book"

  #1 Call encryptor
  runEncryptor(path+"output/ihtml/",@book_prod_folder)
  
  #2 Copy searchDB.sql to root path
  copyFile(path+"output/searchDB.sql", @book_prod_folder)
  
  #3 Validate info.plist
  validateInfoPlist(path+"info.plist")
  
  #4 Copy info.plist to root path
  copyFile(path+"info.plist", @book_prod_folder)
  
  #5 Copy balloons folder
  copyZipContents("balloons_images.zip", @book_prod_folder+"images/")
  copyZipContents("balloons_script.zip", @book_prod_folder+"script/")  
  if !File::directory?(@book_prod_folder+"icons/")
    if File::directory?(path+"/icons/")
      Dir.mkdir(@book_prod_folder+"icons/")
    end
  end
  copyFolderContents(path+"icons/",@book_prod_folder+"icons/");
  
  #6 Verify Folders
  verifyFolders(@book_prod_folder)
  
  #7 Update time stamp
  changeTimestamp(@book_prod_folder,@new_book_timestamp)
  
  #8 Create Zip
  createZip(@book_prod_folder,@book_zip_generated_folder+@book_full_name+".zip",1)
  
  puts "New Book Generated -"+@book_full_name
end

# Book update process subroutine
def updateBook(path)
  puts "Book update operation"
  
  #1 Create diff & update folders
  createFolders(path)
  
  #2 Run Book Difference operation
  runDiffOperation(path+"output/ihtml/", @outputRenamed+"/ihtml/", @book_diff_folder)
  
  #3 Copy searchDB.sql to diff path
  copyFile( path+"output/searchDB.sql", @book_diff_folder)
  
  #4 Run Encryptor
  runEncryptor(@book_diff_folder,@book_update_folder)
  
  #5 Check for update size and delete updates if it exceeds max_update_limit
  update_limit_check()
  
  #6 Copy to original book
  copyFolderContents(@book_update_folder,@book_prod_folder)
  
  #7 Update timestamp for bundle
  if @bundle_type==@BUNDLE_BY_SIZE
    bundleTimestampBundleSize(@book_update_folder,@update_timestamp,@max_file_size.to_i())    
  elsif @bundle_type==@BUNDLE_BY_FILE_COUNT 
    bundleTimestampFileCount(@book_update_folder,@update_timestamp,@max_file_count.to_i())
  elsif @bundle_type==@BUNDLE_BY_NONE     
    bundleTimestampNone(@book_update_folder,@update_timestamp)
  end
  if File.directory?(@book_update_folder)
    File.utime(@update_timestamp, @update_timestamp, @book_update_folder)
    File.utime(@latest_ts, @latest_ts, @book_prod_folder+"/info.plist")
  end
  
  #8 Verify Folders
  verifyFolders(@book_prod_folder)
  
  #9 create zip for update & existing book
  createZip(@updateFolder,@book_zip_generated_folder+@book_full_name+"_update"+".zip",0)
  createZip(@book_prod_folder,@book_zip_generated_folder+@book_full_name+".zip",1)
  
  puts @book_full_name+" - Update generated :"+ @update_timestamp.to_s()
end

##### END OF SUB ROUTINE DEFINATION


#START AUTOMATION PROCESS

#1 Initialize Automation
initAutomation()

#2 Extract config details from automation_config.xml
extractConfigDetails(@automation_config_file)

#printAll()

#3 Run Fass Downloader (only for Vfass)
runFassDownloader()

#4 Run Drcompantion Tool
runDrcompanion(@path)

#5 Verify all links inside each html file
all_links_verify(@path+"output/ihtml/")

#6 Generate searchDB.sql
searchDBGeneration(@path+"output/ihtml/search/",@path+"output/")

#7 Check if all URL in searchDB.sql are valid
searchdb_link_verify(@path+"output/searchDB.sql",@path+"output/ihtml/")

#8 Create Book production folders
createProdFolder(@path)

#9 Create/Update book
if @new_book_operation==true
  createNewBook(@path)
else
  updateBook(@path)
end

print "\nCompleted"