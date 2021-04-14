import pandas as pd
import os
import datetime
import tkinter.filedialog as tk
import tkinter

root = tkinter.Tk()
root.withdraw()
text_folder_path = tk.askdirectory()
start = datetime.datetime.now()


def append_text(text_path, key_word, col_name):
    path_list = os.listdir(text_path)
    text_list = []
    for text in path_list:
        if key_word in text:
            text_list.append(text)
    conut = len(text_list)
    for i in range(conut):
        print("Start to read:{}".format(text_list[i]))
        text_file_temp = pd.read_csv((text_path + "\\" + text_list[i]),
                                     header=None,
                                     names=[col_name],
                                     encoding="utf_16_le")
        if i == 0:
            text_file = text_file_temp
            continue
        text_file = text_file.append(text_file_temp)
        text_file.reset_index(drop=True, inplace=True)
    text_file.to_csv(text_path + "\\append.csv", index_label="index")


append_text(text_folder_path, ".log", "trace")
print(datetime.datetime.now() - start)
print("done")
