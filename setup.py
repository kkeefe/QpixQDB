# setup file to look for changes between qpix-digital directory
# qpix-digital directory uses a different file structure for storing file
# this file should look for all of the files of interest for the QDB and QDBDaq 
# compare to find which one is newest, and copy over the oldest file
# this should allow an easy script to run to pull or push changes between
# the two running directories
import os
import sys

qpix_digital_path = "../qpix-digital"
qpixqdb_path = "./hdl"

def testDirs():
    found_digital = os.path.isdir(qpix_digital_path)
    found_qdb = os.path.isdir(qpixqdb_path)
    
    if(not found_digital or not found_qdb):
        print("unable to locate one of the source directorys")
        return

    QDBFilesD = {}
    for root, dirs, files in os.walk(qpixqdb_path):
        for f in files:
            if "vhd" in f:
                QDBFilesD[f] = os.path.join(root, f)

    # found the directory and the files that we need
    QPixFilesD = {}
    if(found_qdb and found_digital):
        for root, dirs, files in os.walk(qpix_digital_path):        
            for f in files:
                if "vhd" in f:
                    QPixFilesD[f] = os.path.join(root, f)
    
    found_files = []
    not_found = []
    for f, path in QDBFilesD.items():
        if f not in QPixFilesD.keys():
            print("file not found:", f, path)
            not_found.append(f)
        else:
            found_files.append(f)
        
    for f in found_files:
        qdbTime = os.path.getmtime(QDBFilesD[f])
        qpixTime = os.path.getmtime(QPixFilesD[f])

        # if qdbTime > qpixTime:
        #     print(f"{f} is newer in qpix directory")
        # elif qdbTime == qpixTime:
        #     print(f"{f} does not need to be updated")
        # else:
        #     print(f"{f} is newer in qdb directory")
    
    # place the not found files into the generic firmware directory
    # which is in qpix-digital/firmware/src
    for f in not_found:
        found_src = os.path.isdir(qpix_digital_path+"/firmware/src/")

    
def main():
    """
    run script to update repos
    """
    testDirs()


if __name__ == "__main__":
    print('updating repos..')
    main()