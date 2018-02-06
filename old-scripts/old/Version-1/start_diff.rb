#BOOK NAME EG: nwl_revision2 
book_name="nwl_revision2"

#Path where the old book exists
old_src= "C:/test/nwl/"

#Path where new book exists
new_src="c:/test/new_nwl/"

#starting automation
system("ruby diff_automation.rb "+book_name+" "+old_src+" "+new_src);
