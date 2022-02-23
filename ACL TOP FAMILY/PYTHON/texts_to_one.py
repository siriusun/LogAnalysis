import os
import datetime
import tkinter.filedialog as tk
import tkinter

root = tkinter.Tk()
root.withdraw()
text_folder_path = tk.askdirectory()

os.system("pause")

start = datetime.datetime.now()

logfs = os.scandir(text_folder_path)
if os.path.exists(text_folder_path + "\one.txt"):
    os.remove(text_folder_path + "\one.txt")
with open(text_folder_path + "\one.txt","a",encoding="utf_8") as one:
    i = 1
    for logf in logfs:
        if ".log" in logf.name:
            print(f"{i}: {logf.name}")
            with open(logf,"r",encoding="utf_16_le") as f:
                one.write(f.read())
            i += 1

print("\n",datetime.datetime.now() -start,"\n")

os.system("pause")