require 'zip/zip'
require 'ftools'
require 'fileutils'

print "Start\n\n"

path="C:\\test\\nwl\\com.medhand.books.nwl_revision2\\search\\"
system("ruby xml-to-sqlite-transfer.rb #{path}")

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