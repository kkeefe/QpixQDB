
# These are all the compilation targets, starting with "all"
all : compile

compile : 
	cmd /c "vivado -mode batch -source ../scripts/ZyboQDB_daq_git.tcl"

# delete everything except this Makefile
clean :	
	find . -not -name "Makefile*" -not -name "." | xargs rm -rf