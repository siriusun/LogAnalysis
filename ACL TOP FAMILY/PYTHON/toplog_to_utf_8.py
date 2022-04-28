import os
import datetime as dt
import re

start_time = dt.datetime.now()

print("start to convert log to utf-8")
os.system("pause")

path = os.path.split(os.path.abspath(__file__))[0]
data_pth = os.path.join(path,"GeneralLogs")
log_list = os.scandir(data_pth)

for file in log_list:
    if re.match("T.*\.txt",file.name):
        with open(file,"r",encoding="utf_16_le") as f1:
            content = f1.read()
        with open(file,"w",encoding="utf_8") as f2:
            f2.write(content)
        print(f"{file.name} converted...")

print(dt.datetime.now()-start_time)

os.system("pause")
