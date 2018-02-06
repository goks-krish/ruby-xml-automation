require 'ftools'
require 'zip/zip'
require 'time'
require 'xmlsimple'
require 'sqlite3'
require 'net/http'
require 'aws/s3'

print "Start\n\n"

path="c:/"


def log(text)
  puts text
  open('c:/test1/myfile.out', 'a') { |f|
    f.puts text
  }
end

puts Time.now.year.to_s()+"-"+Time.now.month.to_s()+"-"+Time.now.day.to_s()
log "mj"
puts ("goks")

#path="c:\\test\\test\\"

def getFolderSize(folder)
  total_size=0
  @files = Dir.glob(folder+"**/**")
  for file in @files
#    if File::directory?(file)
#      total_size=total_size+getFolderSize(file);
#    else
#      total_size=total_size+File.size(file)
#    end
    puts file
    total_size=total_size+File.size(file)
  end  
  return total_size
end


#

def copyZipContents(file,zipdestination)
  if File.exist?(file)
    Zip::ZipFile.open(file) { |zip_file|
     zip_file.each { |f|
       f_path=File.join(zipdestination, f.name)
       FileUtils.mkdir_p(File.dirname(f_path))
       if File.exist?(f_path) && (!File.directory?(f_path))
         FileUtils.rm(f_path)
       end
       zip_file.extract(f, f_path)
     }
  }
  end
end

#copyZipContents("common.zip","c:/testing/");

#if system("ruby upload_update.rb books-iphone.medhand.com RIKwfNaicPGkDgo/bfva1/ozS3UESE1jkbwTSq1W D:/Workspace/vfass/AA-Delivered-Latest/OCT-9_Update-4+UpdatedBook/com.medhand.books.vfass_revision_2012_1_update.zip")
#
#if system("ruby upload_book.rb books-iphone.medhand.com RIKwfNaicPGkDgo/bfva1/ozS3UESE1jkbwTSq1W D:/Workspace/vfass/AA-Delivered-Latest/OCT-9_Update-4+UpdatedBook/com.medhand.books.vfass_revision_2012_1.zip")
#  puts "upload success"
#else
#  puts "Upload failed"
#end
  
#doc = XmlSimple.xml_out(file_node, {"AttrPrefix" => true,"RootName"   => "manifest", "ContentKey" => "content" })


#timeutc = timelocal.utc
#puts timeutc
#timeutc = thefile.mtime.utc

#print system("D:/Medhand/FassDownloader/bin/Release/FassDownloader.exe")
#fromDate="2012-11-30"

#time_now = Time.now-(3600*24*2)
#path="d:/Medhand/test/xml/"
#id="1074"
#fromDate=time_now.year.to_s()+"-"+time_now.month.to_s()+"-"+time_now.day.to_s()
#if system("FassDownloader.exe #{path} #{id} #{fromDate}")
#  print "success"
#else
#  exit;
#end


#def searchdb_link_verify(searchdb_file,book_final_path)
#  db = SQLite3::Database.new(searchdb_file)
#  query= "select name from sqlite_master where type='table'"
#  tables_list = db.execute( query ) do |table|
#    query="PRAGMA table_info(#{table[0]})"
#    columns_list = db.execute( query ) do |column|
#      if(column[1]=='url')
#        query= "select url from #{table[0]}"
#        db.execute( query ) do |url|
#          url[0]=url[0].split("#").first
#          if File.exists?(book_final_path+url[0])
#            puts url[0]+"  -- true"
#          else 
#            puts "false"
#          end
#        end
#      end
#    end
#   end
#end
#sql_path="E:/test/search/searchDB.sql"
#
#path_vfass="E:/test/vfass/com.medhand.books.vfass_revision_2.1/"
#
#searchdb_link_verify(sql_path,path_vfass)




#partName=path.split(path1).last
#puts partName


#xmldoc = XmlSimple.xml_in(path)
#puts xmldoc['book_full_name']

#if( !File.exists?(path)||Dir.glob(path+"**/**") .length==1)
#  puts"goks"
#end

#puts Dir.glob(path+"**/**") .length==0

#t3=Time.parse('2012-09-01 00:00:00') 
#puts t3
#File.utime(t3+60, t3+60, path1)
#File.utime(new_book_timestamp, new_book_timestamp, file_name)
  
#timestamp = timestamp.gsub(":","-");
#timestamp = timestamp.gsub(" ","_");
#outputRename="C:/test/nwl/output_"+ timestamp
#File.rename( "C:/test/nwl/output/", outputRename)

#test="c:/test/nwl/"
#file= File.expand_path("..",test)

#file="common.zip"
#zipdestination="c:/test/"
#
#  Zip::ZipFile.open(file) { |zip_file|
#   zip_file.each { |f|
#     f_path=File.join(zipdestination, f.name)
#     FileUtils.mkdir_p(File.dirname(f_path))
#     zip_file.extract(f, f_path) unless File.exist?(f_path)
#   }
#}

#search_terms.gsub!(/[^a-zA-Z ]+/, '')

#print File.compare("C:/test/a.html","C:/test/a.html")
#@files = Dir.glob('C:/test/nwl/**/**')
#for file in @files
#    puts file
#end



#Dir.foreach(newFolder) do |fname| 
#  if !(File.directory?(newFolder+fname))
#    if !(File.exist?(oldFolder+fname))
#      puts "new file-"+fname
#      #File.copy("#{newFolder+fname}", "#{difFolder}")
#      File.copy(newFolder+fname,difFolder);
#      #FileUtils.cp(newFolder+fname, difFolder+fname)
#      #Fileutils.cp  , 
#    elsif !(File.compare(newFolder+fname,oldFolder+fname))
#      puts "diff file-"+fname
#      File.copy(newFolder+fname,difFolder);
#    end
#  end
#end


# Run Encrypt & GZip
#encrypt_src=path+"output/ihtml/"
#encrypt_key="ps17"
#print "Running Encrytion & GZip of html files\n"
#if system("java -jar encryptor.jar #{encrypt_src} #{zip_des} #{encrypt_key}")
#  print "Encrytion & Gzip success"
#else
#  print "Encryption Failed"
#  exit;
#end

#system("MXmlResource/MXmlResource.exe C:\\Goks_Working\\Workspace_j2ee\\nwl");
#system("git clone https://maithra-jadhav:gokul2011@github.com/maithra-jadhav/nwltest.git c:/test/nwl");
#git clone https://maithra-jadhav:gokul2011@github.com/MedHand/mh-notifs-pdrfree.git
#https://github.com/maithra-jadhav/nwltest.git

#print Dir.pwd
#system("git clone https://maithra-jadhav:gokul2011@github.com/maithra-jadhav/nwltest.git c:/test/nwl1");
#git clone https://maithra-jadhav:gokul2011@github.com/maithra-jadhav/nwltest.git

#system("ruby automation.rb nwl_revesion2 C:/test/nwl/ https://maithra-jadhav:gokul2011@github.com/maithra-jadhav/nwltest.git");

print "\nEnd"