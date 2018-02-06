require 'ftools'
require 'zip/zip'
require 'time'
require 'xmlsimple'
require 'sqlite3'

##### START SUB ROUTINE DEFINATION

# Init and Validate automation run subroutine
def initAutomation()
  puts("\nInitializing Automation")
  #validate inputs
  unless ARGV.length == 1
    puts("Invalid Arguments")
    puts("ERROR: Usage: ruby automation.rb <book_path>"+"\nAutomation terminated.")
    exit
  end
  @path = ARGV[0]   
  @path=@path.gsub("\\","/")
  last_char = @path[@path.length-1, @path.length-1]
  if last_char != "/"
    @path=@path+"/"
  end 
  @automation_config_file=@path+"automation_config.xml"
  if File::directory?( @path )
    puts("Book Source Path:"+@path)
  else
    puts("ERROR: Invalid Directory: "+@path+"\nAutomation terminated.")
    exit
  end
  #Check if required folders are present
  cssFolder=@path+"css/"
  if !File::directory?(cssFolder)
    puts("ERROR: css folder not present in "+@path+"\nAutomation terminated.")
    exit
  end  
  defineFolder=@path+"define/"
  if !File::directory?(defineFolder)
    puts("ERROR: define folder not present in "+@path+"\nAutomation terminated.")
    exit
  end  
  xmlFolder=@path+"xml/"
  if !File::directory?(xmlFolder)
    puts("ERROR: xml folder not present in "+@path+"\nAutomation terminated.")
    exit
  end    
  xsltFolder=@path+"xslt/"
  if !File::directory?(xsltFolder)
    puts("ERROR: xslt folder not present in "+@path+"\nAutomation terminated.")
    exit
  end     
end

# Extract values from automation_config.xml subroutine
def extractConfigDetails(automation_config_file)
  puts("Extract information from "+automation_config_file)
  if !File::exists?(automation_config_file)
    puts("ERROR: automation_config.xml missing in "+@path+"\nAutomation terminated.")
    exit
  end 
  xmldoc = XmlSimple.xml_in(automation_config_file)
  #Constants
  @BUNDLE_BY_NONE = 0
  @BUNDLE_BY_SIZE = 1
  @BUNDLE_BY_FILE_COUNT =3
  @EXCLUDE_PARENT_FOLDER=0
  @INCLUDE_PARENT_FOLDER=1
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
  if xmldoc['max_update_limit']==nil
    all_fields_ok=false
  else
    @max_update_limit=xmldoc['max_update_limit'].first
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
    puts("ERROR: Invalid automation_config.xml in "+@path+"\nAutomation terminated.")
    exit    
  end
  
  initial_ts_present=false
  #Check if initial_timestamp is present
  if xmldoc['initial_timestamp']==nil
    @new_book_timestamp=Time.new(Time.now.year, Time.now.month, Time.now.day, 0, 0, 0)
  else
    @new_book_timestamp=Time.parse(xmldoc['initial_timestamp'].first)
    initial_ts_present=true
  end
  
  #Determine new book or update operation
  if xmldoc['update_timestamp']==nil
    book_name = File.basename(@path)
    base_path = File.expand_path("../../",@path)
    last_char =base_path[base_path.length-1, base_path.length-1]
    if last_char != "/"
      base_path=base_path+"/"
    end 
    prod_base_folder=base_path+"bookzipfiles/"+book_name+"/book_prod_folder/"
    if Dir[prod_base_folder+"*"].empty? ||  initial_ts_present==true
      @new_book_operation=true
      @update_timestamp=@new_book_timestamp
    else
      @update_timestamp=Time.new(Time.now.year, Time.now.month, Time.now.day, 0, 0, 0)
    end
  else
    @update_timestamp=Time.parse(xmldoc['update_timestamp'].last)
  end
  
  #Force New book operation
   if xmldoc['new_book_only']!=nil
     new_book_only=xmldoc['new_book_only'].first
     if new_book_only=='true'
       @new_book_operation=true
     end
   end
  
  #Check if conversion is disabled
  @disable_conversion=false
  if xmldoc['disable_conversion']!=nil
    dis_con=xmldoc['disable_conversion'].first
    if dis_con=='true'
      @disable_conversion=true
    end
  end
   
  #Check if searchdb generation is disabled 
  @disable_searchdb=false
  if xmldoc['disable_searchdb']!=nil
    dis_sdb=xmldoc['disable_searchdb'].first
    if dis_sdb=='true'
      @disable_searchdb=true
    end
  end
   
  book_name = File.basename(@path)
  temp_path=File.expand_path("../",@path)
  base_path = File.expand_path("../../",@path)
  last_char =base_path[base_path.length-1, base_path.length-1]
  if last_char != "/"
    base_path=base_path+"/"
  end
  
  if(temp_path==base_path)
    puts("ERROR: Book folder should be inside a folder atleast.")
    puts("Current: "+@path)
    puts("Required: "+base_path+"<folder>/"+book_name+"/")
    exit
  end

  @bookzipfiles_path= base_path+"bookzipfiles/"+book_name+"/"  
  @book_folder = @bookzipfiles_path+"workspace/"+@book_full_name+"/"
  @output_renamed = @bookzipfiles_path+"workspace/output-old"
  @book_diff_folder=""
  @update_folder=""
  @update_bundle_folder=""
  @book_zip_generated_folder=""
  @latest_ts=Time.now
  @log_file=@bookzipfiles_path+"workspace/"+Time.now.year.to_s()+"-"+Time.now.month.to_s()+"-"+Time.now.day.to_s()+".log"
    
  #create workspace folder for log file
  if !File.exists?(@bookzipfiles_path+"workspace/")
    createFolder(@bookzipfiles_path+"workspace/")
  end
  puts("Initialization Success\n")
end

# Download Fass xml from server
def runFassDownloader()
  xmldoc = XmlSimple.xml_in(@automation_config_file)
  run_fass="true"
  id=""
  check_interval=0
  if xmldoc['run_downloader']==nil
    run_fass=false
    log("\nFass Downloader Tool enable flag not present in config file")
   else
    run_fass=xmldoc['run_downloader'].first
   end  
  if xmldoc['user_id']==nil
    run_fass=false
    log("User id data not present in config file")
   else
    id=xmldoc['user_id'].first
   end
  if xmldoc['check_interval']==nil
    run_fass=false
    log("check_interval data not present in config file")
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
        log("start_date data not present in config file")
       else
        fromDate=xmldoc['start_date'].first
     end
   end
   if(run_fass=="true")
     path=@path+"xml/xml/"
     log("INFO: Running Downloader. Please wait.")
     if system("FassDownloader.exe #{path} #{id} #{fromDate}")
       log("Download tool successfully run")
     else
       log("INFO: No new files downloaded."+"\nAutomation stopped.")
       exit
     end
     file_temp=""
     if xmldoc['manifest_file']==nil
       run_fass=false
       log("ERROR: manifest_file data not present in config file"+"\nAutomation terminated.")
       exit
     else
       file_temp=xmldoc['manifest_file'].first
      end
     manifest_file=@path+"xml/"+file_temp
     if system("java -jar manifest_generator.jar #{path} #{manifest_file}")
        log("Manifest Generation success\n")
      else
        log("ERROR: Manifest Generation Failed\n"+"\nAutomation terminated.")
        exit
      end
   else 
     log("INFO: Downloader Tool did not run")
   end
   
end

# Copy Zip file to Destination
def copyZipContents(file,zipdestination)
  if File.exist?(file)
    Zip::ZipFile.open(file) { |zip_file|
     zip_file.each { |f|
       f_path=File.join(zipdestination, f.name)
       FileUtils.mkdir_p(File.dirname(f_path))
       if File.exist?(f_path) && (!File.directory?(f_path))
         #FileUtils.rm(f_path)         
       else
         zip_file.extract(f, f_path)
       end      
     }
  }
  end
end

# Run Drcompation subroutine
def runDrcompanion(path)
  log("\nPreparing to run Drcompanion tool")
  #Copy Common Dir required to run DR Compantion tool
  file="common.zip"
  zipdestination=File.expand_path("..",path)+"/"
  copyZipContents(file,zipdestination)
  #Rename existing output folder if exists
  output_path=@bookzipfiles_path+"workspace/output"
  if File.exists?(output_path) && File.directory?(output_path)
    timestamp = File.mtime(output_path).to_s()
    timestamp = timestamp.gsub(":","-")
    timestamp = timestamp.gsub(" ","_")
    @output_renamed=output_path+"_"+ timestamp
    File.rename(output_path, @output_renamed)
  elsif @new_book_operation==false
    log("ERROR: Output folder from previous build is not found in "+@bookzipfiles_path+"workspace/"+"\nAutomation terminated.")
    exit  
  end
  
  #Run Drcompanion-tool
  if system("MXmlResource/MXmlResource.exe #{path}")
    log("Drcompanion conversion success\n")
  else
    log("ERROR: Drcompanion conversion incomplete."+"\nAutomation terminated.")
    exit
  end
end

# FileCopy subroutine
def copyFile(file_src, file_des)
  if File.exists?(file_src)
    if File.directory?(file_src)
      log("Source is a Dir")
    else
      File.copy("#{file_src}", "#{file_des}")
    end
  else
    log("File Not found in "+file_src)
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
  puts "book_prod_folder:"+@book_folder  
end

# Run Encryptor & gzip subroutine
def runEncryptor(encrypt_src,encrypt_des)
  log("\nRunning Encrytion & GZip of html files\n")
  if system("java -jar encryptor.jar #{encrypt_src} #{encrypt_des} #{@encrypt_key}")
    log("Encrytion & Gzip success\n")
  else
    log("ERROR: Encryption Failed\n"+"\nAutomation terminated.")
    exit
  end
end

# Generate searchDB.sql
def searchDBGeneration(search_path,target_path)
  log("\nGenerating searchDB.sql")
  if system("ruby xml-to-sqlite-transfer.rb #{search_path} #{target_path}")
    log("Search DB successfully generated\n")
  else
    log("ERROR: Search DB generation failed."+"\nAutomation terminated.")
    exit
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
#  archive = File.join(zip_path,File.basename(zip_path))+'.zip'
#  FileUtils.rm archive, :force=>true
#  Zip::ZipFile.open(archive, 'w') do |zipfile|
#    Dir["#{zip_path}/**/**"].reject{|f|f==archive}.each do |file|
#      zipfile.add(file.sub(zip_path+'/',''),file)
#    end
#  end
#  print "Zip done successfully"  
  if system("java -jar zipUtil.jar #{zip_src_path} #{zip_des} #{zip_pref}")
    log("Zip success\n")
  else
    log("ERROR: Zip Failed\n"+"\nAutomation terminated.")
    exit
  end
  File.utime(@update_timestamp,@update_timestamp,zip_des)
end

def createEmptyZip()
  if !(File.directory?(@book_zip_generated_folder+@book_full_name+"_update"))
    Dir.mkdir(@book_zip_generated_folder+@book_full_name+"_update")
  end
  ts=@new_book_timestamp.to_s()
  ts = ts.split(" +").first
  ts = ts.gsub(":","-")
  ts = ts.gsub(" ","_")
  if !(File.directory?(@book_zip_generated_folder+@book_full_name+"_update/"+ts))
    Dir.mkdir(@book_zip_generated_folder+@book_full_name+"_update/"+ts)
  end
  createZip(@book_zip_generated_folder+@book_full_name+"_update/",@book_zip_generated_folder+@book_full_name+"_update"+".zip",@EXCLUDE_PARENT_FOLDER)
  if (File.directory?(@book_zip_generated_folder+@book_full_name+"_update"))
    FileUtils.rm_rf(@book_zip_generated_folder+@book_full_name+"_update/")
  end  
end

# Create book production folder
def createProdFolder(path) 
  # Create book production folder
  update_ts=@update_timestamp.to_s()
  update_ts=update_ts.split(" +").first
  update_ts = update_ts.gsub(":","-")
  update_ts = update_ts.gsub(" ","_")
  prod_base_folder=@bookzipfiles_path+"book_prod_folder/"
  if(!File.directory?(prod_base_folder))
    createFolder(prod_base_folder)
  end
  if(@new_book_operation)
    @book_zip_generated_folder=prod_base_folder+update_ts+"_new_book/"
  else
    @book_zip_generated_folder=prod_base_folder+update_ts+"_update/"
  end
  if (!File.directory?(@book_zip_generated_folder))
    Dir.mkdir(@book_zip_generated_folder)
  end
end

# Create folders for update operation
def createUpdateFolders(path)
  #timeutc = @update_timestamp.utc
  update_ts=@update_timestamp.to_s()
  update_ts=update_ts.split(" +").first
  update_ts = update_ts.gsub(":","-")
  update_ts = update_ts.gsub(" ","_")

  # Check if book folder exists
  if !(File.directory?(@bookzipfiles_path+"workspace/"+@book_full_name))
    log("ERROR: "+@bookzipfiles_path+"workspace/"+@book_full_name+"/ not found"+"\nAutomation terminated.")
    exit
  end
  
  # Create root diff folder
  difFolder=@bookzipfiles_path+"workspace/diff_folder/"
  if !(File.directory?(difFolder))
    createFolder(difFolder)
  end

  # Create book diff folder
  @book_diff_folder=difFolder+update_ts+"/"
  if File.directory?(@book_diff_folder)
    FileUtils.rm_rf(@book_diff_folder)
    #File.rename(@book_diff_folder, @book_diff_folder+"-OLD_"+current_ts)
  end
  Dir.mkdir(@book_diff_folder)
  
  # Create update root folder
  @update_folder=@bookzipfiles_path+"workspace/"+@book_full_name+"_update/"
  if !(File.directory?(@update_folder))
    Dir.mkdir(@update_folder)
  end
  
  # Create update book folder
  @update_bundle_folder=@update_folder+update_ts+"/"
  if File.directory?(@update_bundle_folder)
    #File.rename(@update_bundle_folder, @update_bundle_folder+"-OLD_"+current_ts)
    File.rename(@update_bundle_folder, @update_folder+update_ts+"-OLD")    
    FileUtils.rm_rf(@update_folder+update_ts+"-OLD")
  end    
  Dir.mkdir(@update_bundle_folder)
end

# Run Diff operations for update book
def runDiffOperation(new_output, old_output, diff_folder)
  log("\nStarting File Difference Operation")
  #Searching for New & updated files
  new_count=0
  updated_count=0
  @files = Dir.glob(new_output+"**/**")
  for file in @files
       partName=file.split(new_output).last     
       if (File.directory?(file))
          if !File.exist?(old_output+partName)
            if !File.exist?(diff_folder+partName)
              createFolder(diff_folder+partName)
              log("Dir Created -" + partName)
            else
              log("Target Dir Exists -" + partName)
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
             log("Dir Created -" + diff_folder+folder)
           end
           File.copy(file,diff_folder+folder)
           #puts "New File Copied -"+file +" to "+diff_folder+folder
           new_count=new_count+1
         #Updated file copy operation
         elsif !(File.compare(file,old_output+partName))
           folder= partName.split(partName.split("/").last).first
           if folder==nil 
             folder=""
           end
           if !File.exist?(diff_folder+folder)
             createFolder(diff_folder+folder)
             log("Dir Created -" + diff_folder+folder)
           end
           File.copy(file,diff_folder+folder)
           #puts "Updated File Copied -"+file +" to "+diff_folder+folder
           updated_count=updated_count+1
         end
       end
  end
  #Searching for Deleted files & creating the list
  deletedFileList=diff_folder+"deletedFiles.list"
  timestamp = Time.now.to_s()
  deletedFileName=""
  deleted_count=0
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
      deleted_count=deleted_count+1    
    end
  end
  if Dir.glob(diff_folder+"**/**") .length==0
    if (File.directory?(diff_folder))
      Dir.rmdir(diff_folder)
    end
    if (File.directory?(@update_bundle_folder))
      Dir.rmdir(@update_bundle_folder)
    end 
    log("INFO: No Changes made. Halting Automation")
    exit
  end
  log("New Files:"+new_count.to_s())
  log("Udated Files:"+updated_count.to_s())
  log("Deleted Files:"+deleted_count.to_s())
  log("File Difference Operation Complete")
end

def zipBundle(file,time_stamp)
  ts=time_stamp.to_s()
  ts = ts.split(" +").first
  ts = ts.gsub(":","-")
  ts = ts.gsub(" ","_")
  sub_folder=file.split(@update_bundle_folder).last
  inner_folder=""  
  if sub_folder.include?("/")
    file_name=sub_folder.split("/").last
    inner_folder=sub_folder.split(file_name).first
  end
  bundle_folder=@update_bundle_folder+ts+"/"+@book_full_name+"/"+inner_folder
  if !(File::directory?(bundle_folder))
    createFolderWithTimestamp(bundle_folder,time_stamp)
  end
  copyFile(file,bundle_folder)
  if File.exists?(file) 
    FileUtils.rm(file)
  end
  
  File.utime(time_stamp, time_stamp, @update_bundle_folder+ts+"/"+@book_full_name+"/"+sub_folder) 
#  archive=@update_bundle_folder+ts+".zip"
#  zip_inner_path=@book_full_name+"/"+file.split(@update_bundle_folder).last  
#  Zip::ZipFile.open(archive, 'w') do |zipfile|
#    zipfile.add(zip_inner_path,file)
#  end  
#  File.utime(time_stamp, time_stamp, archive)  
  return @update_bundle_folder+ts
  log("File Difference Operation Complete")
end

def generateZipBundle() 
  update_date=@update_timestamp.to_s().split(" ").first
  @files = Dir.glob(@update_bundle_folder+"**")
  for file in @files
    if File::directory?(file)
      srcFolder=file
      zipFile=file+".zip"
      tempsrc=srcFolder.split("/").last
      if tempsrc.include?update_date
        if system("java -jar zipUtil.jar #{srcFolder} #{zipFile} 0")
            log("Zip Bundle success\n")
        else
            log("ERROR: Zip Bundle Failed."+"\nAutomation terminated.")
            exit
         end  
      end
      FileUtils.rm_rf(file)
    end
  end
end

# Change timestamp of bundle subroutine file count
def bundleTimestampFileCount(dest_folder,new_timestamp,max_count)
  log("\nModifying timestamp based on file count")
#  ts= Time.parse(new_timestamp.utc.to_s().split("UTC").first)  
  ts= Time.parse(new_timestamp.to_s())
  intial_ts=ts
  fileCount=0  
  old_output_ihtml=@output_renamed+"/ihtml/"
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
  log("\nModifying timestamp based on size")
  max_size=max_size*1024
  target_folder=""
#  ts= Time.parse(new_timestamp.utc.to_s().split("UTC").first)
  ts= Time.parse(new_timestamp.to_s())
  initial_ts=ts
  fileSize=0  
  total_file_count=0 
  old_output_ihtml=@output_renamed+"/ihtml/"  
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
  log("\nValidating all links inside HTML")
  @files = Dir.glob(folder_path+"**/**")
   for each_file in @files 
     if each_file.include?(".htm")
       file = File.new(each_file, "r")
         while (line = file.gets)
           text=line.split("href") 
           text.each do |part|
             if (part.include?(".htm") || part.include?(".css")) &&  !part.include?("http://") &&  !part.include?("https://") &&  !part.include?("javascript")
               link= part.split("\"")                            
               url_link= link[1].split("../").last                
               url_link=url_link.split("#").first
               if  url_link==nil
                 url_link=""
               end
               if !(File.exists?(folder_path+url_link))
                  log("Checking "+each_file);          
                  puts part
                  log("ERROR: Page not found -"+folder_path+url_link+"\nAutomation terminated.")
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
                if !File.exists?(folder_path+url_link)
                  log("Checking "+each_file);
                  log("ERROR: Page not found -"+folder_path+url_link+"\nAutomation terminated.")
                  exit
                end
             end
           end
         end
        end
       file.close
     end
  end
  log("All links inside HTML files are valid")
end

# Search for all url in searchdb.sql
def searchdb_link_verify(searchdb_file,book_final_path)
  log("\nValidating searchDB.sql")
  if !File.exists?(searchdb_file)
    log("searchDB.sql missing in "+book_final_path)
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
          if !File.exists?(book_final_path+url[0]) 
            log("Checking searchDB.sql");
            log("ERROR: Page not found -"+book_final_path+url[0]+"\nAutomation terminated.")
            exit
          end
        end
      end
    end
   end
   log("searchDB.sql is valid")
end

# validate info.plist values subroutine
def validateInfoPlist(file_path)
  log("\nValidating info.plist")
	xmldoc = XmlSimple.xml_in(file_path)
	xmlkeys= xmldoc['dict']
	key=[]
	value=[]
	key=xmlkeys[0]["key"]
	value=xmlkeys[0]["string"]
	i=0;
	key.each do |key_data|
    log(key_data+" #{i} "+((value[i].nil?) ? "nil" : value[i]).to_s())
		if key_data=="bookDirectory" || key_data=="bookID"
			if value[i].nil?
			  log("ERROR: info.plist: Null value for "+key_data + "\nAll string key must come before everything else"+"\nAutomation terminated.")
				exit
			end				
			temp=value[i].split("com.medhand.books.").last
			if temp.include?"."
        log("ERROR: info.plist: Invalid value for "+key_data + "\n"+value[i]+"\nAutomation terminated.")
				exit
			end
			if !(value[i]==@book_full_name)
			  log(key_data+" value mismatch- "+value[i])
			  log("ERROR: Expected in info.plist: "+@book_full_name+"\nAutomation terminated.")
			  exit
			end
		end
		i=i+1
	end
	log("Valid info.plist")
end

def verifyFolders(folderPath)
  if !File.directory?(folderPath+"css")
    log("ERROR: css folder missing in "+folderPath+"\nAutomation terminated.")
    exit
  end
  if !File.directory?(folderPath+"html")
    log("ERROR: html folder missing in "+folderPath+"\nAutomation terminated.")
    exit
  end
  if !File.directory?(folderPath+"icons")
    log("ERROR: icons folder missing in "+folderPath+"\nAutomation terminated.")
    exit
  end
  if !File.directory?(folderPath+"images")
    log("ERROR: images folder missing in "+folderPath+"\nAutomation terminated.")
    exit
  end
  if !File.directory?(folderPath+"script")
    log("ERROR: script folder missing in "+folderPath+"\nAutomation terminated.")
    exit
  end
  if !File.directory?(folderPath+"symbols")
    log("ERROR: symbols folder missing in "+folderPath+"\nAutomation terminated.")
    exit
  end
  if !File.directory?(folderPath+"images/balloons")
    log("ERROR: images/balloons folder missing in "+folderPath+"\nAutomation terminated.")
    exit
  end
  if !File.directory?(folderPath+"script/balloons")
    log("ERROR: script/balloons folder missing in "+folderPath+"\nAutomation terminated.")
    exit
  end
  if !File.exist?(folderPath+"info.plist")
    log("ERROR: info.plist not found in "+folderPath+"\nAutomation terminated.")
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
  @files = Dir.glob(@update_folder+"*")
  for folder in @files 
    folder_name= folder
    if deleted_size<diff_size
      deleted_size=deleted_size+getFolderSize(folder_name)
      time_stamp=File.mtime(folder_name)  
      #FileUtils.rm_rf(folder_name)
      @files = Dir.glob(folder_name+"/**")
      for file in @files
        if File.directory?(file)
          FileUtils.rm_rf(file)
        elsif File.exist?(file)
          FileUtils.rm(file)
        end
      end
    end
  end
end

# Copy icons & cstm folders
def copySpecificFolders()
  # Copy icons folder
  if !File::directory?(@book_folder+"icons/")
      Dir.mkdir(@book_folder+"icons/")
    if File::directory?(@path+"/icons/")
      copyFolderContents(@path+"icons/",@book_folder+"icons/")
    else
      copyFolderContents(@path+"define/icon/",@book_folder+"icons/")
    end
  end
  #Copy cstm folder
  if File::directory?(@path+"cstm/")
    if !File::directory?(@book_folder+"cstm/")
      Dir.mkdir(@book_folder+"cstm/")
    end
      copyFolderContents(@path+"cstm/",@book_folder+"cstm/")
  end
end

# Check for update limit and delete updates if it exceeds
def update_limit_check() 
  book_size=File.size(@book_zip_generated_folder+@book_full_name+".zip")
  updates_size=getFolderSize(@update_folder)
  accepted_size=(book_size*@max_update_limit.to_i())/100
  if(updates_size>accepted_size)
    diff_size=updates_size-accepted_size
    deleteUpdateFolderContents(diff_size)
  end
end

#Log response
def log(text)
  puts text
  open(@log_file, 'a') { |f|
    f.puts text
  }
end

# New Book creation subroutine
def createNewBook(path)
  log("\nCreate New Book")

  #1 Call encryptor
  runEncryptor(@bookzipfiles_path+"workspace/output/ihtml/",@book_folder)
  
  #2 Copy searchDB.sql to root path
  copyFile(@bookzipfiles_path+"workspace/output/searchDB.sql", @book_folder)
  
  #3 Validate info.plist
  validateInfoPlist(path+"info.plist")
  
  #4 Copy info.plist to root path
  copyFile(path+"info.plist", @book_folder)
  
  #5 Copy icons & cstm folders
  copySpecificFolders()
  
  #6 Verify Folders
  verifyFolders(@book_folder)
  
  #7 Update time stamp
  changeTimestamp(@book_folder,@new_book_timestamp)
  
  #8 Create Zip
  log("\nBook zip")
  createZip(@book_folder,@book_zip_generated_folder+@book_full_name+".zip",@INCLUDE_PARENT_FOLDER)
  log("\nEmpty Update zip")
  createEmptyZip()
 
  log("\n\nBook: "+@book_full_name+"\nBook Timestamp:"+ @update_timestamp.to_s())
  log("Path: "+@bookzipfiles_path+"book_prod_folder/"+"\n\n")
end

# Book update process subroutine
def updateBook(path)
  log("\nBook update operation")
  
  #1 Create diff & update folders
  createUpdateFolders(path)
  
  #2 Run Book Difference operation
  runDiffOperation(@bookzipfiles_path+"workspace/output/ihtml/", @output_renamed+"/ihtml/", @book_diff_folder)
  
  #3 Copy searchDB.sql to diff path
  copyFile( @bookzipfiles_path+"workspace/output/searchDB.sql", @book_diff_folder)
  
  #4 Run Encryptor
  runEncryptor(@book_diff_folder,@update_bundle_folder)
    
  #5 Copy new/changed contents to original book
  copyFolderContents(@update_bundle_folder,@book_folder)
        
  #6 Verify Folders
  verifyFolders(@book_folder)

  #7 Generate book zip
  log("\nBook zip")
  File.utime(@update_timestamp, @update_timestamp, @book_folder+"info.plist")
  createZip(@book_folder,@book_zip_generated_folder+@book_full_name+".zip",@INCLUDE_PARENT_FOLDER)
  
  #8 Generate update bundle zips
  if @bundle_type==@BUNDLE_BY_SIZE
    bundleTimestampBundleSize(@update_bundle_folder,@update_timestamp,@max_file_size.to_i())    
  elsif @bundle_type==@BUNDLE_BY_FILE_COUNT 
    bundleTimestampFileCount(@update_bundle_folder,@update_timestamp,@max_file_count.to_i())
  elsif @bundle_type==@BUNDLE_BY_NONE     
    bundleTimestampNone(@update_bundle_folder,@update_timestamp)
  end
  if File.directory?(@update_bundle_folder)
    File.utime(@update_timestamp, @update_timestamp, @update_bundle_folder)
  end
  
  #9 Check for update size and delete updates if it exceeds max_update_limit
  update_limit_check()
  
  #10 Generate update zip
  log("\nUpdate zip")
  createZip(@update_folder,@book_zip_generated_folder+@book_full_name+"_update"+".zip",@EXCLUDE_PARENT_FOLDER)
  
  log("\n\nBook: "+@book_full_name+"\nUpdate Timestamp:"+ @update_timestamp.to_s())
  log("Path: "+@bookzipfiles_path+"book_prod_folder/"+"\n\n")
end

def upload_to_server()
  xmldoc = XmlSimple.xml_in(@automation_config_file)
  run_uploader="true"
  url=""
  key=""
  book_zip=@book_zip_generated_folder+@book_full_name+".zip"
  update_zip=@book_zip_generated_folder+@book_full_name+"_update"+".zip"
  check_interval=0
  if xmldoc['run_uploader']==nil
    run_uploader="false"
   else
    run_uploader=xmldoc['run_uploader'].first
  end  
  if xmldoc['url']==nil
    run_uploader="false"
    log("URL missing in config file.")
   else
    url=xmldoc['url'].first
   end  
  if xmldoc['key']==nil
    run_uploader="false"
    log("Key missing in config file")
   else
    key=xmldoc['key'].first
    if key.length==0  
      run_uploader="false"
      log("Key empty in config file")
    end
   end  
   
   if run_uploader=="true"
     log("Uploading book zip to server")
     if system("ruby upload_book.rb "+url+" "+key+" "+book_zip)
        log("Book upload success")
     else
        log("Book upload failed. Upload Book zip manually")
     end     
     log("Uploading update zip to server")
     if system("ruby upload_update.rb "+url+" "+key+" "+update_zip)
        log("Book upload success")
     else
        log("Book upload failed. Upload Book zip manually")
     end
   else
     log("INFO: Uploader tool is disabled. Please upload the book manually to the server.")
   end  
end
##### END OF SUB ROUTINE DEFINATION

#START AUTOMATION PROCESS

#1 Initialize Automation
initAutomation()

#2 Extract config details from automation_config.xml
extractConfigDetails(@automation_config_file)
log("\n\nAUTOMATION STARTED AT "+Time.now.to_s())
#printAll()

#3 Run Fass Downloader (only for Vfass)
runFassDownloader()

#4 Run Drcompantion Tool
if  @disable_conversion
  log("\nMxmlResources.exe conversion disabled")
else
  runDrcompanion(@path)  
end

#5 Verify all links inside each html file
#*all_links_verify(@bookzipfiles_path+"workspace/output/ihtml/")

#6 Generate searchDB.sql
if @disable_searchdb
  log("\nSearchDB.sql generation disabled")
else
  searchDBGeneration(@bookzipfiles_path+"workspace/output/ihtml/search/",@bookzipfiles_path+"workspace/output/")
end


#7 Check if all URL in searchDB.sql are valid
#*searchdb_link_verify(@bookzipfiles_path+"workspace/output/searchDB.sql",@bookzipfiles_path+"workspace/output/ihtml/")

#8 Create Book production folders
createProdFolder(@path)

#9 Create/Update book
if @new_book_operation==true
  createNewBook(@path)
else
  updateBook(@path)
end

#10 Upload to server
upload_to_server()
log("\nCompleted")