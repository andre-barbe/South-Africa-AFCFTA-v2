#This python script runs the STATA script

import subprocess

## Run STATA Do file
#To run STATA within python, see https://stackoverflow.com/questions/21263668/run-stata-do-file-from-python and https://www.stata.com/support/faqs/windows/batch-mode/
#First setup command to run the do file
name_of_dofile = 'Transfer_results_from_output_folder.do'
path_to_STATA_exe = 'C:\Program Files\Stata17\StataMP-64' # Don't put this in double quotes! If you do, you get an error. I think this is what kept tripping me up before when I couldn't run STATA from python https://stackoverflow.com/questions/33618656/python-windowserror-error-123-the-filename-directory-name-or-volume-label-s
cmd = [path_to_STATA_exe, '/b', 'do', name_of_dofile] #Note that I can't add arguments
# Execute command to run do-file
print(cmd)
subprocess.call(cmd)


