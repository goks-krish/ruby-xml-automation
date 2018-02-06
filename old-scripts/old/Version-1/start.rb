#BOOK FUL NAME EG: com.medhand.books.nwl_revision2 
book_name="com.medhand.books.vfass_revision2"

#Path to download the book
book_path="C:/test/vfass/"

#Encryption Key
encrypt_key="ps17"

#starting automation
system("ruby automation.rb "+book_name+" "+book_path+" "+encrypt_key);
