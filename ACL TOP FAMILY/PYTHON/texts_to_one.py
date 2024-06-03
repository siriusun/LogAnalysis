'''
Author: siriusun sirius.st@outlook.com
Date: 2023-03-17 07:05:29
LastEditors: siriusun sirius.st@outlook.com
LastEditTime: 2024-05-23 07:03:37
FilePath: \undefinedc:\Users\siriu\Documents\GitHub\LogAnalysis\ACL TOP FAMILY\PYTHON\texts_to_one.py
Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
'''
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
if os.path.exists(text_folder_path + r"\one.txt"):
    os.remove(text_folder_path + r"\one.txt")
with open(text_folder_path + r"\one.txt", "a", encoding="utf_8") as one:
    i = 1
    for logf in logfs:
        if ".log" in logf.name:
            print(f"{i}: {logf.name}")
            with open(logf, "r", encoding="utf_16_le") as f:
                one.write(f.read())
            i += 1

print("\n", datetime.datetime.now() - start, "\n")

os.system("pause")
